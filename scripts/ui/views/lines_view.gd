class_name LinesView
extends VBoxContainer
## Lineup screen: pick a unit, see it on the rink in your colors, click a
## jersey to change the player. The squad table shows everyone's slot,
## condition, morale and form.

const UNITS := ["Line 1", "Line 2", "Line 3", "Line 4", "PP1", "PP2", "PK1", "PK2", "Goalies"]
const LINE_COLORS := [Color("#7c4dff"), Color("#3d9bff"), Color("#22b8a0"), Color("#8a96b2")]
const PK_SIM_SPOTS := ["C", "LW", "LD", "RD"]
const PK_DISPLAY := ["LW", "RW", "LD", "RD"]

var _unit := 0
var _lineup: Lineup
var _roster: Array
var _team: Team
var _rink: Rink
var _tokens: Array = []        ## [Control, display_spot]
var _summary: VBoxContainer
var _table: DataTable
var _unit_buttons: Array = []
var _problems: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_team = League.get_team(Game.user_team_id)
	_lineup = Game.lineups[Game.user_team_id]
	_roster = League.roster(Game.user_team_id)

	# Toolbar.
	var bar := UI.hbox(6)
	add_child(bar)
	var group := ButtonGroup.new()
	for i in UNITS.size():
		var b := Button.new()
		b.text = UNITS[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == _unit
		b.custom_minimum_size = Vector2(74, 34)
		b.pressed.connect(func():
			_unit = i
			_rebuild())
		bar.add_child(b)
		_unit_buttons.append(b)
	bar.add_child(UI.spacer())
	_problems = UI.label("", 13, AppTheme.ORANGE)
	_problems.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_problems)
	bar.add_child(UI.button("Quick Pick", func():
		_lineup.auto_fill(_roster, false)
		_rebuild()))
	bar.add_child(UI.button("Fill Empty", func():
		_lineup.auto_fill(_roster, true)
		_rebuild()))
	bar.add_child(UI.button("Redo Special Teams", func():
		_lineup._auto_special_teams(_roster)
		_rebuild()))

	var body := UI.hbox(14)
	UI.expand(body)
	add_child(body)

	# Rink card.
	var rink_card := UI.card("", 12)
	rink_card.custom_minimum_size = Vector2(500, 0)
	body.add_child(rink_card)
	var rb := UI.body(rink_card)
	_rink = Rink.new()
	_rink.custom_minimum_size = Vector2(476, 520)
	_rink.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rink.resized.connect(_layout_tokens)
	rb.add_child(_rink)
	_summary = UI.vbox(6)
	rb.add_child(_summary)

	# Squad table card.
	var squad := UI.card("Squad  -  double-click a player for his profile", 12)
	squad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(squad)
	_table = DataTable.new()
	_table.setup([["Slot", 64], ["#", 40], ["Player", 0], ["Pos", 46], ["Role", 56], ["OVR", 52],
		["Cond", 60], ["Morale", 92], ["Form", 56], ["PTS", 50]])
	_table.row_activated.connect(func(id): Hub.go("Player", int(id)))
	UI.body(squad).add_child(_table)
	_rebuild()


# ------------------------------------------------------------------ slots

## The slots shown for the current unit: {arr, idx, spot, display, label}.
func _slots() -> Array:
	var out := []
	var u: String = UNITS[_unit]
	if u.begins_with("Line"):
		var n := _unit
		for s in 3:
			out.append({"arr": _lineup.forwards[n], "idx": s, "spot": Lineup.FWD_SLOTS[s], "display": Lineup.FWD_SLOTS[s]})
		if n < 3:
			for s in 2:
				out.append({"arr": _lineup.defense[n], "idx": s, "spot": Lineup.D_SLOTS[s], "display": Lineup.D_SLOTS[s]})
		out.append({"arr": _lineup.goalies, "idx": 0, "spot": "G", "display": "G"})
	elif u.begins_with("PP"):
		var k := 0 if u == "PP1" else 1
		for s in 5:
			out.append({"arr": _lineup.power_play[k], "idx": s, "spot": Lineup.PP_SLOTS[s], "display": Lineup.PP_SLOTS[s]})
		out.append({"arr": _lineup.goalies, "idx": 0, "spot": "G", "display": "G"})
	elif u.begins_with("PK"):
		var k := 0 if u == "PK1" else 1
		for s in 4:
			out.append({"arr": _lineup.penalty_kill[k], "idx": s, "spot": PK_SIM_SPOTS[s], "display": PK_DISPLAY[s]})
		out.append({"arr": _lineup.goalies, "idx": 0, "spot": "G", "display": "G"})
	else:
		out.append({"arr": _lineup.goalies, "idx": 0, "spot": "G", "display": "G", "label": "Starter"})
		out.append({"arr": _lineup.goalies, "idx": 1, "spot": "G", "display": "C", "label": "Backup"})
	return out


## pid -> "L1 C", "D2 RD", "G1"... for the squad table.
func _assignments() -> Dictionary:
	var a := {}
	for l in 4:
		for s in 3:
			a[_lineup.forwards[l][s]] = ["L%d %s" % [l + 1, Lineup.FWD_SLOTS[s]], l]
	for d in 3:
		for s in 2:
			a[_lineup.defense[d][s]] = ["D%d %s" % [d + 1, Lineup.D_SLOTS[s]], d]
	a[_lineup.goalies[0]] = ["G1", -1]
	a[_lineup.goalies[1]] = ["G2", -2]
	a.erase(0)
	return a


# ------------------------------------------------------------------ build

func _rebuild() -> void:
	for t in _tokens:
		t[0].queue_free()
	_tokens.clear()
	for slot in _slots():
		var token := _make_token(slot)
		_rink.add_child(token)
		_tokens.append([token, slot["display"]])
	_layout_tokens.call_deferred()
	_build_summary()
	_fill_table()
	var problems := _lineup.problems()
	_problems.text = "" if problems.is_empty() else "! " + problems[0]


func _make_token(slot: Dictionary) -> Control:
	var pid: int = slot["arr"][slot["idx"]]
	var p := League.get_player(pid)
	var spot: String = slot["spot"]
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(130, 112)
	var clear := Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", AppTheme.box(clear, 8))
	btn.add_theme_stylebox_override("hover", AppTheme.box(Color(1, 1, 1, 0.07), 8))
	btn.add_theme_stylebox_override("pressed", AppTheme.box(Color(1, 1, 1, 0.12), 8))
	var col := UI.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(col)

	var jersey := Jersey.make(_team.id, str(p.number) if p else "", 46)
	jersey.dimmed = p == null
	jersey.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(jersey)

	if p == null:
		col.add_child(_center(UI.pill("EMPTY", AppTheme.RED)))
		col.add_child(_center(UI.label("click to pick", 12, AppTheme.MUTED)))
	else:
		var tier := p.familiarity_label(spot)
		var role_key: String = Roles.ranked(p, Roles.for_spot(spot))[0]
		var role: Dictionary = Roles.get_role(role_key)
		var tags := UI.hbox(3)
		tags.alignment = BoxContainer.ALIGNMENT_CENTER
		tags.add_child(UI.pill(slot.get("label", spot), AppTheme.tier_color(tier), UI.DARK_TEXT, 11))
		tags.add_child(UI.pill(role["abbr"], AppTheme.PANEL_3, AppTheme.TEXT, 11))
		col.add_child(tags)
		var stars := StarRating.make(Roles.stars(p, role_key), 11)
		stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(stars)
		var name_pill := UI.pill(p.short_name(), Color(0, 0, 0, 0.55), Color.WHITE, 13)
		col.add_child(_center(name_pill))
		btn.tooltip_text = "%s at %s: %s (%d/20)%s\n%s: %s\nClick to change." % [p.full_name(), Player.SPOT_NAMES.get(spot, spot),
			tier, p.familiarity_at(spot), "  |  OFF side" if p.is_off_side_at(spot) else "",
			"Best role here", role["name"]]
	btn.pressed.connect(_open_picker.bind(slot, btn))
	return btn


func _center(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


func _layout_tokens() -> void:
	for t in _tokens:
		var token: Control = t[0]
		token.size = token.custom_minimum_size
		var p := _rink.spot_point(t[1])
		token.position = p - Vector2(token.size.x / 2, 26)


func _open_picker(slot: Dictionary, _anchor: Control) -> void:
	var spot: String = slot["spot"]
	var menu := PopupMenu.new()
	add_child(menu)
	var candidates := _roster.filter(func(p): return p.is_goalie() == (spot == "G"))
	candidates.sort_custom(func(a, b): return a.lineup_score(spot) > b.lineup_score(spot))
	var assigned := _assignments()
	menu.add_item("-- leave empty --", 0)
	for i in candidates.size():
		var p = candidates[i]
		var where := ""
		if assigned.has(p.id):
			where = "   [%s]" % assigned[p.id][0]
		var txt := "%s   %d   %s%s" % [p.full_name(), p.overall, p.familiarity_label(spot) if spot != "G" else "", where]
		menu.add_item(txt, i + 1)
	menu.id_pressed.connect(func(id):
		slot["arr"][slot["idx"]] = 0 if id == 0 else candidates[id - 1].id
		menu.queue_free()
		_rebuild())
	menu.popup_hide.connect(func(): menu.queue_free.call_deferred())
	menu.position = Vector2i(get_global_mouse_position())
	menu.popup()


# ------------------------------------------------------------------ summary + table

func _build_summary() -> void:
	for c in _summary.get_children():
		c.queue_free()
	var att := 0.0
	var dfn := 0.0
	var fam := 0.0
	var n := 0
	var pref := 0
	for slot in _slots():
		var p := League.get_player(slot["arr"][slot["idx"]])
		if p == null or p.is_goalie():
			continue
		var spot: String = slot["spot"]
		att += MatchSim.skater_attack(p, spot)
		dfn += MatchSim.skater_defense(p, spot)
		fam += p.familiarity_at(spot)
		if p.on_preferred_side(spot):
			pref += 1
		n += 1
	if n == 0:
		_summary.add_child(UI.label("Goalies only on this screen.", 13, AppTheme.MUTED))
		return
	var row := UI.hbox(18)
	_summary.add_child(row)
	for item in [["Offense", att / n / League.norms["attack"]], ["Defense", dfn / n / League.norms["defense"]]]:
		var pct := clampf(50.0 + (float(item[1]) - 1.0) * 220.0, 2.0, 100.0)
		var col := AppTheme.attr_color(int(pct / 5.0))
		var box := UI.vbox(2)
		box.add_child(UI.caption(item[0]))
		var line := UI.hbox(6)
		line.add_child(UI.meter(pct, col, 110, 10))
		line.add_child(UI.label("%d" % int(pct), 14, col))
		box.add_child(line)
		row.add_child(box)
	var fam_avg := fam / n
	var fam_tier := "Natural" if fam_avg >= 18 else ("Accomplished" if fam_avg >= 14 else ("Competent" if fam_avg >= 10 else "Unconvincing"))
	var fbox := UI.vbox(2)
	fbox.add_child(UI.caption("Positions"))
	fbox.add_child(UI.label(fam_tier, 14, AppTheme.tier_color(fam_tier)))
	row.add_child(fbox)
	var sbox := UI.vbox(2)
	sbox.add_child(UI.caption("Preferred side"))
	sbox.add_child(UI.label("%d of %d" % [pref, n], 14, AppTheme.GREEN if pref == n else AppTheme.YELLOW))
	row.add_child(sbox)


func _fill_table() -> void:
	var assigned := _assignments()
	var rows := []
	for p in _roster:
		var slot_txt := "-"
		var slot_bg := Color(0, 0, 0, 0)
		var slot_key := 99
		if assigned.has(p.id):
			slot_txt = assigned[p.id][0]
			var line_idx: int = assigned[p.id][1]
			slot_bg = AppTheme.GOLD if line_idx < 0 else LINE_COLORS[line_idx]
			slot_key = (50 if slot_txt.begins_with("G") else 10) + (line_idx if line_idx >= 0 else 0) * 2 + (1 if slot_txt.begins_with("D") else 0)
		var cond := Game.condition_of(p.id)
		var m := Game.morale_of(p.id)
		var f := Game.form_of(p.id)
		var favg := 0.0
		for r in f:
			favg += float(r)
		if not f.is_empty():
			favg /= f.size()
		var best: Dictionary = Roles.get_role(Roles.best(p))
		var line := Game.player_line(p.id)
		var cell_bg := {5: AppTheme.ovr_color(p.overall)}
		if slot_bg.a > 0:
			cell_bg[0] = slot_bg
		if favg > 0:
			cell_bg[8] = AppTheme.rating_color(favg)
		rows.append({"id": p.id,
			"cells": [slot_txt, p.number, p.full_name(), p.position, best.get("abbr", ""), p.overall,
				"%d%%" % int(cond), AppTheme.morale_label(m), "%.1f" % favg if favg > 0 else "-", line.get("pts", 0)],
			"keys": [slot_key, p.number, p.last_name, p.position, best.get("abbr", ""), p.overall, cond, m, favg, line.get("pts", 0)],
			"cell_bg": cell_bg,
			"cell_colors": {0: Color.WHITE, 6: AppTheme.condition_color(cond), 7: AppTheme.morale_color(m)},
			"color": AppTheme.TEXT if assigned.has(p.id) else AppTheme.MUTED})
	_table.set_rows(rows)
	_table.sort_by(0, false)
