class_name StandingsView
extends VBoxContainer

var _mode := 0   ## 0 division, 1 conference, 2 league
var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var top := UI.hbox(12)
	add_child(top)
	top.add_child(UI.heading("Standings"))
	var mode := OptionButton.new()
	for m in ["Division", "Conference", "League"]:
		mode.add_item(m)
	mode.item_selected.connect(func(i):
		_mode = i
		_fill())
	top.add_child(mode)
	top.add_child(UI.label("Top 3 in each division + 2 wild cards per conference make the playoffs (marked *).", 0, UI.MUTED))
	var scroll := ScrollContainer.new()
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
	for g in groups:
		_body.add_child(UI.label(g[0], 18))
		var rows: Array = Game.standings_sorted(g[1])
		var table := DataTable.new()
		table.custom_minimum_size = Vector2(0, 36 + 28 * rows.size())
		table.setup([["", 36], ["Team", 0], ["GP", 50], ["W", 50], ["L", 50], ["OTL", 50], ["PTS", 55],
			["P%", 65], ["RW", 50], ["GF", 50], ["GA", 50], ["DIFF", 60], ["Home", 90], ["Away", 90], ["L10", 80], ["STRK", 60]])
		var out := []
		var rank := 0
		for r in rows:
			rank += 1
			var l10: Array = r["last10"]
			var lw := l10.count("W")
			var ll := l10.count("L")
			var lo := l10.count("O")
			var pct: float = float(r["pts"]) / maxf(1.0, r["gp"] * 2.0)
			var mark := "*" if playoff.has(r["team"]) else ""
			var row := {"id": r["team"],
				"cells": [str(rank) + mark, UI.team_name(r["team"]), r["gp"], r["w"], r["l"], r["otl"], r["pts"],
					"%.3f" % pct, r["rw"], r["gf"], r["ga"], r["gf"] - r["ga"],
					"%d-%d-%d" % [r["home_w"], r["home_l"], r["home_otl"]],
					"%d-%d-%d" % [r["away_w"], r["away_l"], r["away_otl"]],
					"%d-%d-%d" % [lw, ll, lo], r["streak"]],
				"keys": [rank, UI.team_name(r["team"]), r["gp"], r["w"], r["l"], r["otl"], r["pts"], pct,
					r["rw"], r["gf"], r["ga"], r["gf"] - r["ga"], r["home_w"], r["away_w"], lw, r["streak"]]}
			if r["team"] == Game.user_team_id:
				row["color"] = UI.USER_COLOR
			out.append(row)
		table.set_rows(out)
		_body.add_child(table)


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
