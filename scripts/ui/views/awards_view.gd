class_name AwardsView
extends ScrollContainer
## Season awards. Before the regular season ends it shows the live races.


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var page := UI.vbox(14)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(page)
	var live: bool = Game.awards.is_empty()
	var list: Array = Awards.regular_season(Game) if live else Game.awards
	var top := UI.hbox(10)
	page.add_child(top)
	top.add_child(UI.heading("Award races" if live else "Season awards"))
	top.add_child(UI.spacer())
	if live:
		top.add_child(UI.pill("If the season ended today", AppTheme.PANEL_3, AppTheme.TEXT))
	elif Game.phase != "done":
		top.add_child(UI.pill("Cup and playoff MVP after the final", AppTheme.PANEL_3, AppTheme.TEXT))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(grid)
	for a in list:
		grid.add_child(_award_card(a))


func _award_card(a: Dictionary) -> Control:
	var big: bool = a["name"] in ["Stanton Cup", "Hartwell Trophy", "Conn Smith Trophy"]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var team_id: String = a.get("team", "")
	var border := AppTheme.GOLD if big else AppTheme.BORDER
	if team_id == Game.user_team_id:
		border = UI.USER_COLOR
	card.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.PANEL, 10, border, 2 if big or team_id == Game.user_team_id else 1, 14, 12))
	var box := UI.vbox(8)
	card.add_child(box)

	var head := UI.hbox(12)
	box.add_child(head)
	head.add_child(Trophy.make(40, a["name"] in ["Stanton Cup", "Wallace Trophy", "Campton Bowl", "Presidents' Shield"]))
	var titles := UI.vbox(0)
	titles.add_child(UI.label(a["name"], 17, AppTheme.GOLD if big else Color.WHITE))
	titles.add_child(UI.label(a["desc"], 12, AppTheme.MUTED))
	head.add_child(titles)
	box.add_child(HSeparator.new())

	if team_id == "":
		box.add_child(UI.label("Not enough games yet.", 14, AppTheme.MUTED))
		return card
	var win := Button.new()
	win.flat = true
	win.custom_minimum_size = Vector2(0, 58)
	var row := UI.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(row)
	if a["kind"] == "player":
		var p := League.get_player(int(a["winner"]))
		var j := Jersey.make(team_id, str(p.number) if p else "", 44)
		j.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(j)
		win.pressed.connect(func(): Hub.go("Player", int(a["winner"])))
	else:
		var c := TeamCrest.make(team_id, 40)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(c)
		win.pressed.connect(func(): Hub.go("Club", team_id))
	var txt := UI.vbox(0)
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	txt.add_child(UI.label(a["winner_name"], 16, Color.WHITE))
	txt.add_child(UI.label("%s  |  %s" % [League.get_team(team_id).name, a["line"]], 12, AppTheme.MUTED))
	row.add_child(txt)
	box.add_child(win)
	if not a["finalists"].is_empty():
		box.add_child(UI.caption("Finalists"))
		for f in a["finalists"]:
			box.add_child(UI.label("%s (%s)  %s" % [f["name"], f["team"], f["line"]], 12, AppTheme.TEXT))
	return card
