class_name StandingsView
extends VBoxContainer

var _mode := 0   ## 0 division, 1 conference, 2 league
var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var top := UI.hbox(10)
	add_child(top)
	top.add_child(UI.heading("Standings"))
	var group := ButtonGroup.new()
	var names := ["Division", "Conference", "League"]
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == 0
		b.custom_minimum_size = Vector2(100, 32)
		b.pressed.connect(func():
			_mode = i
			_fill())
		top.add_child(b)
	top.add_child(UI.spacer())
	top.add_child(UI.pill("Playoff spot", AppTheme.GREEN))
	top.add_child(UI.pill("Your team", UI.USER_COLOR))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.expand(scroll)
	add_child(scroll)
	_body = UI.vbox(16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_fill()


func _fill() -> void:
	for c in _body.get_children():
		c.queue_free()
	var playoff := _playoff_teams()
	var groups := []
	if _mode == 0:
		for d in ["Atlantic", "Metropolitan", "Central", "Pacific"]:
			groups.append([d + " Division", func(t): return t.division == d])
	elif _mode == 1:
		for c in ["Eastern", "Western"]:
			groups.append([c + " Conference", func(t): return t.conference == c])
	else:
		groups.append(["League", Callable()])
	var grid := GridContainer.new()
	grid.columns = 2 if _mode < 2 else 1
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for g in groups:
		var rows: Array = Game.standings_sorted(g[1])
		var card := UI.card(g[0], 10)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var table := DataTable.new()
		table.row_height = 28
		table.custom_minimum_size = Vector2(0, 40 + 37 * rows.size())
		table.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		table.setup([["", 36], ["", 10], ["Team", 0], ["GP", 44], ["W", 44], ["L", 44], ["OTL", 48], ["PTS", 52],
			["DIFF", 56], ["L10", 72], ["STRK", 56]])
		table.row_activated.connect(func(id): Hub.go("Club", id))
		var out := []
		var rank := 0
		for r in rows:
			rank += 1
			var l10: Array = r["last10"]
			var diff: int = r["gf"] - r["ga"]
			var row := {"id": r["team"],
				"cells": [rank, "", UI.team_name(r["team"]), r["gp"], r["w"], r["l"], r["otl"], r["pts"],
					"%+d" % diff, "%d-%d-%d" % [l10.count("W"), l10.count("L"), l10.count("O")], r["streak"]],
				"keys": [rank, r["team"], UI.team_name(r["team"]), r["gp"], r["w"], r["l"], r["otl"], r["pts"],
					diff, l10.count("W"), r["streak"]],
				"cell_bg": {1: League.get_team(r["team"]).primary},
				"cell_colors": {8: AppTheme.GREEN if diff > 0 else (AppTheme.RED if diff < 0 else AppTheme.MUTED),
					10: AppTheme.result_color(r["streak"]) if r["streak"] != "" else AppTheme.MUTED}}
			if playoff.has(r["team"]):
				row["cell_bg"][0] = Color(AppTheme.GREEN, 0.85)
			if r["team"] == Game.user_team_id:
				row["bg"] = Color(UI.USER_COLOR, 0.16)
				row["color"] = Color.WHITE
			out.append(row)
		table.set_rows(out)
		UI.body(card).add_child(table)


## Top 3 per division plus the next 2 best in each conference.
func _playoff_teams() -> Dictionary:
	var spots := {}
	for conf in ["Eastern", "Western"]:
		var taken := {}
		var divs := []
		for t in League.teams.values():
			if t.conference == conf and not divs.has(t.division):
				divs.append(t.division)
		for d in divs:
			var rows: Array = Game.standings_sorted(func(t): return t.division == d)
			for r in rows.slice(0, 3):
				taken[r["team"]] = true
		var wild := 0
		for r in Game.standings_sorted(func(t): return t.conference == conf):
			if wild >= 2:
				break
			if not taken.has(r["team"]):
				taken[r["team"]] = true
				wild += 1
		spots.merge(taken)
	return spots
