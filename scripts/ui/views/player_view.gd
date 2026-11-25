class_name PlayerView
extends VBoxContainer
## Full-page player profile.

var player_id := 0
var _player: Player
var _role := ""
var _attr_holder: HBoxContainer
var _roles_box: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_player = League.get_player(player_id)
	if _player == null:
		add_child(UI.label("Player not found."))
		return
	_role = Roles.best(_player)
	add_child(_header())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.expand(scroll)
	add_child(scroll)
	var page := UI.vbox(12)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)

	var body := UI.hbox(12)
	page.add_child(body)
	body.add_child(_positions_column())
	var attr_card := UI.card("", 14)
	attr_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attr_holder = UI.hbox(28)
	UI.body(attr_card).add_child(_attr_holder)
	body.add_child(attr_card)
	body.add_child(_info_column())
	_build_attributes()

	page.add_child(_bottom_strip())


# ------------------------------------------------------------------ header

func _header() -> Control:
	var p := _player
	var team := League.get_team(p.team_id)
	var panel := PanelContainer.new()
	var style := AppTheme.box(team.primary.darkened(0.45).lerp(AppTheme.PANEL, 0.35), 10, Color(0, 0, 0, 0), 0, 18, 14)
	style.border_color = team.accent()
	style.border_width_left = 6
	panel.add_theme_stylebox_override("panel", style)
	var row := UI.hbox(20)
	panel.add_child(row)

	var jersey := Jersey.make(p.team_id, p.number, 84)
	jersey.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(jersey)

	var who := UI.vbox(4)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who)
	var name_row := UI.hbox(10)
	who.add_child(name_row)
	name_row.add_child(UI.label(p.full_name(), 30, Color.WHITE))
	name_row.add_child(UI.pill(str(p.number), team.accent(), team.on_primary() if team.accent() == team.primary else UI.DARK_TEXT, 15))
	who.add_child(UI.label(p.positions_text(), 15, AppTheme.TEXT))
	who.add_child(UI.label("%s   |   %d years old (%s)   |   Shoots %s" % [p.nationality, p.age, p.birth_date, p.shoots], 14, AppTheme.MUTED))

	row.add_child(UI.spacer())

	var club := UI.vbox(6)
	club.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(club)
	var chip := UI.team_chip(p.team_id, 30, 17)
	club.add_child(chip)
	var status := Game.squad_status(p)
	club.add_child(UI.pill(status, _status_color(status)))

	row.add_child(VSeparator.new())

	var money := UI.vbox(4)
	money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(money)
	money.add_child(UI.label(Game.money(p.cap_hit()), 22, Color.WHITE))
	var c := p.contract
	money.add_child(UI.label("%d yr%s left, then %s" % [c["years"], "" if c["years"] == 1 else "s", c["expiry_status"]], 13, AppTheme.MUTED))

	row.add_child(VSeparator.new())

	var ability := GridContainer.new()
	ability.columns = 2
	ability.add_theme_constant_override("h_separation", 14)
	ability.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ability)
	ability.add_child(UI.caption("Current ability"))
	ability.add_child(UI.caption("Potential"))
	ability.add_child(StarRating.make(p.ability_stars(), 18))
	ability.add_child(StarRating.make(p.potential_stars(), 18, AppTheme.GOLD.darkened(0.15)))
	ability.add_child(UI.label("Overall %d" % p.overall, 13, AppTheme.ovr_color(p.overall)))
	ability.add_child(UI.label("Range %s" % p.potential_range(), 13, AppTheme.MUTED))

	# Trading.
	if p.team_id != Game.user_team_id:
		var tb := UI.button("Trade for him", func(): Hub.go("Trade Center", {"team": p.team_id, "player": p.id}))
		tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tb.disabled = not Game.trades_open()
		row.add_child(tb)
	else:
		var on_block: bool = Game.trading_block.has(str(p.id))
		var bb := UI.button("Remove from trading block" if on_block else "Add to trading block", func():
			if Game.trading_block.has(str(p.id)):
				Game.trading_block.erase(str(p.id))
			else:
				Game.trading_block[str(p.id)] = true
			if Hub.current != null:
				Hub.current.refresh())
		bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bb)

	# Roster move (your players only).
	if p.team_id == Game.user_team_id:
		var move := UI.button("Send to Reserve" if p.on_nhl_roster() else "Call Up to NHL", func():
			Game.set_roster_status(p.id, "Reserve" if p.on_nhl_roster() else "NHL")
			if Hub.current != null:
				Hub.current.refresh())
		move.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(move)

	# Previous / next player on the same roster.
	var nav := UI.vbox(4)
	nav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var roster := League.roster(p.team_id)
	var idx := roster.find(p)
	var prev_btn := UI.button("^", func(): Hub.go("Player", roster[(idx - 1 + roster.size()) % roster.size()].id))
	var next_btn := UI.button("v", func(): Hub.go("Player", roster[(idx + 1) % roster.size()].id))
	prev_btn.tooltip_text = "Previous player"
	next_btn.tooltip_text = "Next player"
	nav.add_child(prev_btn)
	nav.add_child(next_btn)
	row.add_child(nav)
	return panel


func _status_color(status: String) -> Color:
	match status:
		"Key Player":
			return AppTheme.GOLD
		"Important Player":
			return AppTheme.GREEN
		"Regular Starter":
			return AppTheme.LIME
		"Prospect":
			return AppTheme.BLUE
		"Rotation":
			return AppTheme.YELLOW
	return AppTheme.MUTED


# ------------------------------------------------------------------ positions + roles

func _positions_column() -> Control:
	var p := _player
	var col := UI.vbox(12)
	col.custom_minimum_size = Vector2(340, 0)

	var pos_card := UI.card("Positions")
	col.add_child(pos_card)
	var pb := UI.body(pos_card)
	pb.add_child(UI.label(p.positions_text(), 15))
	var rink := Rink.new()
	rink.vertical = false
	rink.custom_minimum_size = Vector2(310, 150)
	if p.is_goalie():
		rink.dots = {"G": AppTheme.GREEN}
		rink.highlight_spot = "G"
	else:
		for spot in Player.SKATER_SPOTS:
			rink.dots[spot] = AppTheme.tier_color(p.familiarity_label(spot))
		rink.highlight_spot = p.position
	pb.add_child(rink)
	if not p.is_goalie():
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		pb.add_child(grid)
		for spot in Player.SKATER_SPOTS:
			var tier := p.familiarity_label(spot)
			grid.add_child(UI.label(Player.SPOT_NAMES[spot], 14))
			grid.add_child(UI.meter(p.familiarity_at(spot) * 5.0, AppTheme.tier_color(tier), 70))
			grid.add_child(UI.label(tier, 13, AppTheme.tier_color(tier)))
		var side := "Prefers his OFF side: a %s shot on the %s. One-timer threat." % [
			"left" if p.shoots == "L" else "right", "right" if p.shoots == "L" else "left"] if p.prefers_off_side \
			else "Prefers his STRONG side. Better on the wall and on breakouts."
		var side_l := UI.label(side, 13, AppTheme.MUTED)
		side_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pb.add_child(side_l)

	var role_card := UI.card("Roles")
	col.add_child(role_card)
	_roles_box = UI.body(role_card)
	_build_roles()
	return col


func _build_roles() -> void:
	for c in _roles_box.get_children():
		if not (c is Label):
			c.queue_free()
	var group := ButtonGroup.new()
	for key in Roles.ranked(_player):
		var role := Roles.get_role(key)
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = key == _role
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 34)
		var row := UI.hbox(10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		var stars := StarRating.make(Roles.stars(_player, key), 13)
		stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(stars)
		var l := UI.label(role["name"], 14)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		b.add_child(row)
		b.pressed.connect(func():
			_role = key
			_build_attributes())
		_roles_box.add_child(b)
	_roles_box.add_child(UI.label("Pick a role to highlight its key attributes.", 12, AppTheme.FAINT))


# ------------------------------------------------------------------ attributes

func _build_attributes() -> void:
	for c in _attr_holder.get_children():
		c.queue_free()
	var keys: Dictionary = Roles.get_role(_role).get("keys", {})
	var groups := _player.detail_groups()
	for group in groups:
		var col := UI.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(group, 17, Color.WHITE))
		col.add_child(HSeparator.new())
		for k in groups[group]:
			col.add_child(_attr_row(k, keys.has(k)))
		_attr_holder.add_child(col)


func _attr_row(key: String, highlighted: bool) -> Control:
	var v := _player.detail(key)
	var panel := PanelContainer.new()
	var bg := Color(AppTheme.ACCENT_2, 0.22) if highlighted else Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", AppTheme.box(bg, 4, Color(0, 0, 0, 0), 0, 8, 3))
	var row := UI.hbox(8)
	panel.add_child(row)
	var name_l := UI.label(Player.attr_label(key), 15, Color.WHITE if highlighted else AppTheme.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var val := UI.label(str(v), 17, AppTheme.attr_color(v))
	val.custom_minimum_size = Vector2(26, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	return panel


# ------------------------------------------------------------------ info column

func _info_column() -> Control:
	var p := _player
	var col := UI.vbox(12)
	col.custom_minimum_size = Vector2(280, 0)
	var info := UI.card("Info")
	col.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	UI.body(info).add_child(grid)
	var rows := [
		["Height", p.height_text()],
		["Weight", "%d kg (%d lb)" % [p.weight_kg, int(p.weight_kg * 2.2046)]],
		["Shoots", "Left" if p.shoots == "L" else "Right"],
		["Born", p.birth_date],
		["Nationality", p.nationality],
		["NHL games", str(p.nhl_games)],
		["Drafted", p.draft_text()],
		["Best role", Roles.get_role(Roles.best(p)).get("name", "-")],
	]
	for r in rows:
		grid.add_child(UI.label(r[0], 13, AppTheme.MUTED))
		grid.add_child(UI.label(r[1], 14))

	var con := UI.card("Contract")
	col.add_child(con)
	var cb := UI.body(con)
	var c := p.contract
	cb.add_child(UI.label("%s per season" % Game.money(c["cap_hit"]), 18, Color.WHITE))
	cb.add_child(UI.label("%d year%s remaining" % [c["years"], "" if c["years"] == 1 else "s"], 14))
	var tags := UI.hbox(6)
	cb.add_child(tags)
	tags.add_child(UI.pill(c["expiry_status"] + " at expiry", AppTheme.PANEL_3, AppTheme.TEXT))
	if c["elc"]:
		tags.add_child(UI.pill("Entry-level", AppTheme.BLUE))
	if c["no_trade_clause"]:
		tags.add_child(UI.pill("No-trade", AppTheme.ORANGE))

	var core := UI.card("Game engine ratings")
	col.add_child(core)
	var kb := UI.body(core)
	var cgrid := GridContainer.new()
	cgrid.columns = 3
	cgrid.add_theme_constant_override("h_separation", 10)
	kb.add_child(cgrid)
	for k in p.attributes:
		var v: int = p.attributes[k]
		cgrid.add_child(UI.label(Player.attr_label(k), 13, AppTheme.MUTED))
		cgrid.add_child(UI.meter(v * 5.0, AppTheme.attr_color(v), 70))
		cgrid.add_child(UI.label(str(v), 13, AppTheme.attr_color(v)))
	return col


# ------------------------------------------------------------------ bottom strip

func _bottom_strip() -> Control:
	var p := _player
	var row := UI.hbox(12)

	var m := Game.morale_of(p.id)
	var mc := UI.card("Morale")
	mc.custom_minimum_size = Vector2(170, 0)
	UI.body(mc).add_child(UI.label(AppTheme.morale_label(m), 22, AppTheme.morale_color(m)))
	UI.body(mc).add_child(UI.meter(m, AppTheme.morale_color(m), 140))
	row.add_child(mc)

	var cond := Game.condition_of(p.id)
	var cc := UI.card("Condition")
	cc.custom_minimum_size = Vector2(170, 0)
	UI.body(cc).add_child(UI.label("%d%%" % int(cond), 22, AppTheme.condition_color(cond)))
	UI.body(cc).add_child(UI.meter(cond, AppTheme.condition_color(cond), 140))
	row.add_child(cc)

	var fc := UI.card("Form (last 5)")
	var f := Game.form_of(p.id)
	UI.body(fc).add_child(FormStrip.make(f, 34))
	var avg5 := 0.0
	for r in f:
		avg5 += float(r)
	if not f.is_empty():
		avg5 /= f.size()
	UI.body(fc).add_child(UI.label("Average %s" % ("%.2f" % avg5 if avg5 > 0 else "-"), 13, AppTheme.rating_color(avg5)))
	row.add_child(fc)

	var sc := UI.card("Season stats")
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	UI.body(sc).add_child(grid)
	var line := Game.player_line(p.id)
	var cols: Array
	if p.is_goalie():
		var sa: int = line.get("sa", 0)
		var ga: int = line.get("ga", 0)
		cols = [["GP", line.get("gp", 0)], ["W", line.get("w", 0)], ["L", line.get("l", 0)], ["OTL", line.get("otl", 0)],
			["SV%", "%.3f" % ((float(sa - ga) / sa) if sa > 0 else 0.0)],
			["GAA", "%.2f" % (ga * 3600.0 / maxf(1.0, float(line.get("toi", 0))))], ["SO", line.get("so", 0)]]
	else:
		var gp: int = line.get("gp", 0)
		cols = [["GP", gp], ["G", line.get("g", 0)], ["A", line.get("a", 0)], ["PTS", line.get("pts", 0)],
			["+/-", "%+d" % int(line.get("pm", 0))], ["PIM", line.get("pim", 0)], ["SOG", line.get("shots", 0)],
			["PPG", line.get("ppg", 0)], ["TOI", UI.fmt_toi(float(line.get("toi", 0)) / maxi(1, gp))]]
	grid.columns = cols.size()
	grid.add_theme_constant_override("h_separation", 22)
	for c in cols:
		grid.add_child(UI.caption(c[0]))
	for c in cols:
		grid.add_child(UI.label(str(c[1]), 19, Color.WHITE))
	row.add_child(sc)

	var avg := Game.avg_rating(p.id)
	var ac := UI.card("Avg rating")
	ac.custom_minimum_size = Vector2(130, 0)
	UI.body(ac).add_child(UI.pill("%.2f" % avg if avg > 0 else "-", AppTheme.rating_color(avg) if avg > 0 else AppTheme.PANEL_3,
		UI.DARK_TEXT if avg > 0 else AppTheme.MUTED, 22))
	row.add_child(ac)
	return row
