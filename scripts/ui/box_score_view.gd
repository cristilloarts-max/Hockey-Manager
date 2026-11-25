class_name BoxScoreView
extends ScrollContainer
## Box score + play-by-play for one of your games, as a full page.
## The live match screen reuses build_content() for its final breakdown.

var key := ""   ## schedule index (regular season) or "p<n>" (playoffs)


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if not Game.box_scores.has(key):
		add_child(UI.label("No box score for that game.", 15, AppTheme.MUTED))
		return
	var content := BoxScoreView.build_content(Game.box_scores[key])
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)


static func build_content(res: Dictionary, with_scoreboard: bool = true) -> VBoxContainer:
	var v := BoxScoreView.new()
	return v._build(res, with_scoreboard)


func _build(res: Dictionary, with_scoreboard: bool) -> VBoxContainer:
	var home: String = res["home"]
	var away: String = res["away"]
	var suffix := "" if res["ot"] == "" else " (%s)" % res["ot"]
	var box := UI.vbox(12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if with_scoreboard:
		box.add_child(_scoreboard(res, away, home, suffix))

	# Three stars.
	var stars_card := UI.card("Three stars")
	var srow := UI.hbox(24)
	UI.body(stars_card).add_child(srow)
	var n := 0
	for pid in res["stars"]:
		n += 1
		var p = League.get_player(int(pid))
		if p == null:
			continue
		var line: Dictionary = res["stats"][pid]
		var item := UI.hbox(10)
		item.add_child(UI.label("*".repeat(n), 18, AppTheme.GOLD))
		var j := Jersey.make(p.team_id, p.number, 40)
		j.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(j)
		var txt := UI.vbox(0)
		txt.add_child(UI.label(p.full_name(), 15, Color.WHITE))
		txt.add_child(UI.label("%s   %dG %dA   rating %.1f" % [p.team_id, line["g"], line["a"], float(line.get("rating", 0.0))], 12, AppTheme.MUTED))
		item.add_child(txt)
		srow.add_child(item)
	box.add_child(stars_card)

	# Skater tables.
	for side in [away, home]:
		var team := League.get_team(side)
		var card := UI.card("")
		var head := UI.hbox(10)
		head.add_child(TeamCrest.make(side, 26))
		head.add_child(UI.label(team.full_name(), 17, team.accent()))
		UI.body(card).add_child(head)
		var t := DataTable.new()
		t.custom_minimum_size = Vector2(0, 300)
		t.setup([["", 10], ["Player", 0], ["Pos", 50], ["G", 40], ["A", 40], ["P", 40], ["+/-", 50], ["SOG", 50],
			["PIM", 50], ["TOI", 70], ["Rating", 70]])
		t.row_activated.connect(func(id): Hub.go("Player", int(id)))
		var rows := []
		for pid in res["stats"]:
			var line: Dictionary = res["stats"][pid]
			if line["team"] != side:
				continue
			var p = League.get_player(int(pid))
			if p == null:
				continue
			var rating: float = float(line.get("rating", 0.0))
			rows.append({"id": p.id,
				"cells": ["", p.full_name(), p.position, int(line["g"]), int(line["a"]), int(line["g"]) + int(line["a"]),
					"%+d" % int(line["pm"]), int(line["shots"]), int(line["pim"]), UI.fmt_toi(line["toi"]), "%.1f" % rating],
				"keys": [0, p.full_name(), p.position, int(line["g"]), int(line["a"]), int(line["g"]) + int(line["a"]),
					int(line["pm"]), int(line["shots"]), int(line["pim"]), float(line["toi"]), rating],
				"cell_bg": {0: team.primary, 10: AppTheme.rating_color(rating)}})
		t.set_rows(rows)
		t.sort_by(10, true)
		UI.body(card).add_child(t)
		for gid in res["goalies"]:
			var gl: Dictionary = res["goalies"][gid]
			if gl["team"] != side:
				continue
			var g = League.get_player(int(gid))
			var sa := int(gl["sa"])
			var sv := sa - int(gl["ga"])
			var grow := UI.hbox(10)
			grow.add_child(UI.label("Goalie  %s" % (g.full_name() if g else str(gid)), 14))
			grow.add_child(UI.label("%d saves on %d shots (%.3f)" % [sv, sa, (float(sv) / sa) if sa > 0 else 0.0], 14, AppTheme.MUTED))
			if gl["decision"] != "":
				grow.add_child(UI.pill(gl["decision"], AppTheme.result_color(gl["decision"])))
			var gr: float = float(gl.get("rating", 0.0))
			if gr > 0:
				grow.add_child(UI.pill("%.1f" % gr, AppTheme.rating_color(gr)))
			UI.body(card).add_child(grow)
		box.add_child(card)

	# Play-by-play.
	var pbp_card := UI.card("Play-by-play")
	var pbp := ""
	for e in res["events"]:
		if e["type"] == "shot":
			continue
		var color := "#b8c2d8"
		match e["type"]:
			"goal":
				color = "#" + (AppTheme.RESULT_W if e["team"] == Game.user_team_id else AppTheme.RESULT_L).to_html(false)
			"penalty":
				color = "#ffd27f"
			"end":
				color = "#8fb8ff"
			"save":
				color = "#8a96b2"
		var stamp: String = e["period"]
		if e["time"] != "":
			stamp += " " + e["time"]
		var tag := ""
		if e["team"] != "":
			var tc: Color = League.get_team(e["team"]).accent()
			tag = "[color=#%s][b]%s[/b][/color]  " % [tc.to_html(false), e["team"]]
		var text: String = e["text"]
		if e["type"] == "goal":
			text = "[b]%s[/b]" % text
		pbp += "[color=#55617d]%s[/color]   %s[color=%s]%s[/color]\n" % [stamp, tag, color, text]
	UI.body(pbp_card).add_child(UI.rich(pbp))
	box.add_child(pbp_card)
	queue_free()
	return box


func _scoreboard(res: Dictionary, away: String, home: String, suffix: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.PANEL, 10, Color(0, 0, 0, 0), 0, 0, 0))
	var row := UI.hbox(0)
	panel.add_child(row)
	row.add_child(_side_block(away, res["away_goals"], res["away_shots"], res["away_pp"], true))
	var mid := UI.vbox(4)
	mid.custom_minimum_size = Vector2(240, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var final_l := UI.label("FINAL" + suffix, 14, AppTheme.MUTED)
	final_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(final_l)
	var periods: Array = res["periods"]
	var grid := GridContainer.new()
	grid.columns = periods.size() + 1
	grid.add_theme_constant_override("h_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_child(UI.label("", 12))
	for i in periods.size():
		grid.add_child(UI.caption(str(i + 1) if i < 3 else "OT"))
	for side in [[away, 1], [home, 0]]:
		grid.add_child(UI.label(side[0], 13, AppTheme.MUTED))
		for pr in periods:
			grid.add_child(UI.label(str(int(pr[side[1]])), 14))
	mid.add_child(grid)
	row.add_child(mid)
	row.add_child(_side_block(home, res["home_goals"], res["home_shots"], res["home_pp"], false))
	return panel


func _side_block(id: String, goals: Variant, shots: Variant, pp: Array, left: bool) -> Control:
	var team := League.get_team(id)
	var block := PanelContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := AppTheme.box(team.primary.darkened(0.25), 10, Color(0, 0, 0, 0), 0, 18, 14)
	if left:
		st.corner_radius_top_right = 0
		st.corner_radius_bottom_right = 0
	else:
		st.corner_radius_top_left = 0
		st.corner_radius_bottom_left = 0
	block.add_theme_stylebox_override("panel", st)
	var row := UI.hbox(14)
	block.add_child(row)
	var crest := TeamCrest.make(id, 56)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := UI.label(team.full_name(), 18, team.on_primary())
	var sub := UI.label("SOG %d   PP %d/%d" % [int(shots), int(pp[0]), int(pp[1])], 13, Color(team.on_primary(), 0.75))
	info.add_child(nm)
	info.add_child(sub)
	var score := UI.label(str(int(goals)), 44, team.on_primary())
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if left:
		row.add_child(crest)
		row.add_child(info)
		row.add_child(score)
	else:
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(score)
		row.add_child(info)
		row.add_child(crest)
	return block
