class_name TeamSelect
extends MarginContainer
## Pick the team to take over: a wall of team cards in club colors, with a
## detail panel for the selected club.

signal team_chosen(team_id)
signal back

var _details: VBoxContainer
var _choose_btn: Button
var _selected := ""
var _cards := {}


func _ready() -> void:
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 24)
	var root := UI.vbox(14)
	add_child(root)

	var top := UI.hbox(12)
	root.add_child(top)
	top.add_child(UI.button("<  Back", func(): back.emit()))
	top.add_child(UI.label("Choose your club", 26, Color.WHITE))
	top.add_child(UI.spacer())
	top.add_child(UI.label("Strength = average rating of the top 18 skaters and the starting goalie", 13, AppTheme.MUTED))

	var body := UI.hbox(18)
	UI.expand(body)
	root.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.expand(scroll)
	body.add_child(scroll)
	var lists := UI.vbox(16)
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lists)
	for conf in ["Eastern", "Western"]:
		lists.add_child(UI.caption("%s Conference" % conf))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lists.add_child(grid)
		var teams := League.team_list().filter(func(t): return t.conference == conf)
		teams.sort_custom(func(a, b): return a.division + a.city < b.division + b.city)
		for t in teams:
			grid.add_child(_team_card(t))

	var side_panel := UI.card("", 0)
	side_panel.custom_minimum_size = Vector2(400, 0)
	body.add_child(side_panel)
	_details = UI.body(side_panel)
	_details.add_theme_constant_override("separation", 0)

	_choose_btn = Button.new()
	_choose_btn.text = "Select a club"
	_choose_btn.disabled = true
	_choose_btn.custom_minimum_size = Vector2(0, 50)
	_choose_btn.add_theme_font_size_override("font_size", 18)
	_choose_btn.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.ACCENT, 6))
	_choose_btn.add_theme_stylebox_override("hover", AppTheme.box(AppTheme.ACCENT.lightened(0.1), 6))
	_choose_btn.add_theme_stylebox_override("disabled", AppTheme.box(AppTheme.PANEL_2, 6))
	_choose_btn.pressed.connect(func():
		if _selected != "":
			team_chosen.emit(_selected))
	root.add_child(_choose_btn)
	_show_details("")


func _team_card(t: Team) -> Control:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := AppTheme.box(AppTheme.PANEL, 8, Color(0, 0, 0, 0), 0, 0, 0)
	normal.border_color = t.primary
	normal.border_width_left = 6
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = AppTheme.PANEL_2
	var on: StyleBoxFlat = normal.duplicate()
	on.bg_color = t.primary.darkened(0.35)
	on.border_color = t.accent()
	on.set_border_width_all(2)
	on.border_width_left = 6
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	var row := UI.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -8
	b.add_child(row)
	var crest := TeamCrest.make(t.id, 44)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	var txt := UI.vbox(2)
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(UI.label(t.city, 12, AppTheme.MUTED))
	txt.add_child(UI.label(t.name, 17, Color.WHITE))
	var strength := League.team_strength(t.id)
	txt.add_child(StarRating.make(clampf(roundf((strength - 55.0) / 25.0 * 10.0) / 2.0, 0.5, 5.0), 12))
	row.add_child(txt)
	b.pressed.connect(func(): _select(t.id))
	_cards[t.id] = b
	return b


func _select(id: String) -> void:
	_selected = id
	for k in _cards:
		_cards[k].button_pressed = k == id
	_choose_btn.disabled = false
	_choose_btn.text = "Take over the %s   >>" % UI.team_name(id)
	_show_details(id)


func _show_details(id: String) -> void:
	for c in _details.get_children():
		c.queue_free()
	if id == "":
		_details.add_child(UI.margin(UI.label("Pick a club to see its roster, strengths and cap situation.", 14, AppTheme.MUTED), 18))
		return
	var t := League.get_team(id)
	var band := PanelContainer.new()
	var bs := AppTheme.box(t.primary, 8, Color(0, 0, 0, 0), 0, 18, 16)
	bs.corner_radius_bottom_left = 0
	bs.corner_radius_bottom_right = 0
	bs.border_color = t.secondary
	bs.border_width_bottom = 4
	band.add_theme_stylebox_override("panel", bs)
	_details.add_child(band)
	var bh := UI.hbox(14)
	band.add_child(bh)
	bh.add_child(TeamCrest.make(id, 64))
	var names := UI.vbox(2)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(UI.label(t.city.to_upper(), 13, Color(t.on_primary(), 0.8)))
	names.add_child(UI.label(t.name, 26, t.on_primary()))
	names.add_child(UI.label("%s  |  %s" % [t.conference, t.division], 12, Color(t.on_primary(), 0.8)))
	bh.add_child(names)

	var content := UI.vbox(10)
	_details.add_child(UI.margin(content, 16))
	var facts := UI.hbox(10)
	content.add_child(facts)
	for f in [["Strength", "%.1f" % League.team_strength(id)], ["Payroll", Game.money(League.payroll(id))],
			["Cap space", Game.money(League.cap_space(id))]]:
		var fb := UI.vbox(0)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.add_child(UI.caption(f[0]))
		fb.add_child(UI.label(f[1], 18, Color.WHITE))
		facts.add_child(fb)
	content.add_child(HSeparator.new())
	content.add_child(UI.caption("Top players"))
	var r := League.roster(id)
	for p in r.slice(0, 7):
		content.add_child(_player_row(p, "%s  |  age %d  |  %s" % [p.position, p.age, Game.money(p.cap_hit())]))
	var young := r.filter(func(p): return p.age <= 22)
	young.sort_custom(func(a, b): return a.potential > b.potential)
	if not young.is_empty():
		content.add_child(HSeparator.new())
		content.add_child(UI.caption("Top prospects"))
		for p in young.slice(0, 3):
			content.add_child(_player_row(p, "%s  |  age %d  |  potential %s" % [p.position, p.age, p.potential_range()]))


func _player_row(p: Player, sub: String) -> Control:
	var row := UI.hbox(10)
	var j := Jersey.make(p.team_id, p.number, 32)
	j.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(j)
	var txt := UI.vbox(0)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(UI.label(p.full_name(), 15, Color.WHITE))
	txt.add_child(UI.label(sub, 12, AppTheme.MUTED))
	row.add_child(txt)
	var o := UI.pill(str(p.overall), AppTheme.ovr_color(p.overall), UI.DARK_TEXT, 14)
	row.add_child(o)
	return row
