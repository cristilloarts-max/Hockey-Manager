class_name LinesView
extends VBoxContainer
## Line editor. Every slot shows the player's familiarity with that spot and
## whether he's on the side he prefers. Anyone can go anywhere; the sim
## applies the familiarity penalty.

var _lineup: Lineup
var _roster: Array
var _problems: Label


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_lineup = Game.lineups[Game.user_team_id]
	_roster = League.roster(Game.user_team_id)

	var top := UI.hbox(12)
	add_child(top)
	top.add_child(UI.heading("Lines"))
	top.add_child(UI.button("Auto-pick best lineup", func():
		_lineup.auto_fill(_roster, false)
		_rebuild()))
	top.add_child(UI.button("Fill empty spots", func():
		_lineup.auto_fill(_roster, true)
		_rebuild()))
	top.add_child(UI.button("Rebuild special teams", func():
		_lineup._auto_special_teams(_roster)
		_rebuild()))
	_problems = UI.label("", 0, Color(1, 0.6, 0.4))
	top.add_child(_problems)

	var legend := UI.hbox(14)
	add_child(legend)
	for tier in Player.FAMILIARITY_TIERS:
		legend.add_child(UI.label("%s (%d+)" % [tier[1], tier[0]], 13, UI.tier_color(tier[1])))
	legend.add_child(UI.label("|  OFF = off-side shooter (one-timer bonus if he prefers it)", 13, UI.MUTED))

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	UI.expand(scroll)
	add_child(scroll)
	_rebuild()


func _rebuild() -> void:
	var scroll: ScrollContainer = get_node("Scroll")
	for c in scroll.get_children():
		c.queue_free()
	var box := UI.vbox(14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	box.add_child(UI.label("Forwards", 18))
	for l in 4:
		var row := UI.hbox(10)
		row.add_child(_row_label("Line %d" % (l + 1)))
		for s in 3:
			row.add_child(_slot(Lineup.FWD_SLOTS[s], _lineup.forwards[l], s))
		box.add_child(row)

	box.add_child(UI.label("Defense", 18))
	for d in 3:
		var row := UI.hbox(10)
		row.add_child(_row_label("Pair %d" % (d + 1)))
		for s in 2:
			row.add_child(_slot(Lineup.D_SLOTS[s], _lineup.defense[d], s))
		box.add_child(row)

	box.add_child(UI.label("Goalies", 18))
	var grow := UI.hbox(10)
	grow.add_child(_row_label("Starter / Backup"))
	grow.add_child(_slot("G", _lineup.goalies, 0))
	grow.add_child(_slot("G", _lineup.goalies, 1))
	box.add_child(grow)

	box.add_child(UI.label("Power play", 18))
	for u in 2:
		var row := UI.hbox(10)
		row.add_child(_row_label("PP%d" % (u + 1)))
		for s in 5:
			row.add_child(_slot(Lineup.PP_SLOTS[s], _lineup.power_play[u], s))
		box.add_child(row)

	box.add_child(UI.label("Penalty kill", 18))
	for u in 2:
		var row := UI.hbox(10)
		row.add_child(_row_label("PK%d" % (u + 1)))
		var spots := ["C", "LW", "LD", "RD"]
		for s in 4:
			row.add_child(_slot(spots[s], _lineup.penalty_kill[u], s))
		box.add_child(row)

	var problems := _lineup.problems()
	_problems.text = "" if problems.is_empty() else "! " + problems[0] + ("" if problems.size() == 1 else " (+%d more)" % (problems.size() - 1))


func _row_label(text: String) -> Label:
	var l := UI.label(text, 15)
	l.custom_minimum_size = Vector2(130, 0)
	return l


## One slot: a dropdown of players ranked for this spot, plus a familiarity badge.
func _slot(spot: String, arr: Array, idx: int) -> Control:
	var box := UI.vbox(2)
	box.custom_minimum_size = Vector2(250, 0)
	var head := UI.label(spot, 12, UI.MUTED)
	box.add_child(head)

	var pick := OptionButton.new()
	pick.fit_to_longest_item = false
	pick.add_item("-- empty --", 0)
	var candidates := _roster.filter(func(p): return p.is_goalie() == (spot == "G"))
	candidates.sort_custom(func(a, b): return a.lineup_score(spot) > b.lineup_score(spot))
	var current: int = arr[idx]
	var selected_index := 0
	for p in candidates:
		var txt := "%s  %d" % [p.full_name(), p.overall]
		if spot != "G":
			txt += "  (%s)" % p.familiarity_label(spot)
		pick.add_item(txt, p.id)
		if p.id == current:
			selected_index = pick.item_count - 1
	pick.select(selected_index)
	pick.item_selected.connect(func(i):
		arr[idx] = pick.get_item_id(i)
		_rebuild())
	box.add_child(pick)

	var badge := UI.label("", 12)
	var p := League.get_player(current)
	if p != null and spot != "G":
		var tier := p.familiarity_label(spot)
		var bits := [tier]
		if p.is_off_side_at(spot):
			bits.append("OFF" + (" (likes it)" if p.prefers_off_side else ""))
		elif Player.spot_side(spot) != "" and p.prefers_off_side:
			bits.append("wants off side")
		badge.text = "  ".join(bits)
		badge.add_theme_color_override("font_color", UI.tier_color(tier))
		pick.tooltip_text = "%s at %s: familiarity %d/20" % [p.full_name(), spot, p.familiarity_at(spot)]
	box.add_child(badge)
	return box
