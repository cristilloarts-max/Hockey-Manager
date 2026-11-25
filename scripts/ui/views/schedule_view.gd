class_name ScheduleView
extends VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var top := UI.hbox(10)
	add_child(top)
	top.add_child(UI.heading("Schedule & Results"))
	top.add_child(UI.spacer())
	var team_id := Game.user_team_id
	var rec: Dictionary = Game.standings[team_id]
	top.add_child(UI.pill("Home %d-%d-%d" % [rec["home_w"], rec["home_l"], rec["home_otl"]], AppTheme.PANEL_3, AppTheme.TEXT))
	top.add_child(UI.pill("Away %d-%d-%d" % [rec["away_w"], rec["away_l"], rec["away_otl"]], AppTheme.PANEL_3, AppTheme.TEXT))
	add_child(UI.label("Double-click a played game for its box score, or an upcoming one to scout the opponent.", 13, AppTheme.MUTED))

	var table := DataTable.new()
	table.setup([["#", 44], ["Date", 170], ["", 40], ["", 10], ["Opponent", 0], ["Opp. record", 110],
		["Result", 80], ["Score", 80], ["Your record", 110]])
	table.row_activated.connect(func(idx):
		var g: Dictionary = Game.schedule[int(idx)]
		if g["played"]:
			Hub.go("Box Score", str(int(idx)))
		else:
			Hub.go("Club", g["away"] if g["home"] == team_id else g["home"]))
	add_child(table)

	var rows := []
	var w := 0
	var l := 0
	var otl := 0
	var n := 0
	for i in Game.team_games(team_id):
		var g: Dictionary = Game.schedule[i]
		n += 1
		var home: bool = g["home"] == team_id
		var opp: String = g["away"] if home else g["home"]
		var result := ""
		var score := ""
		var record := ""
		var row := {"id": i}
		var cell_bg := {3: League.get_team(opp).primary}
		if g["played"]:
			var mine: int = g["hg"] if home else g["ag"]
			var theirs: int = g["ag"] if home else g["hg"]
			var ot: String = g.get("ot", "")
			if mine > theirs:
				result = "W"
				w += 1
			elif ot != "":
				result = "OTL"
				otl += 1
			else:
				result = "L"
				l += 1
			if ot != "":
				result += " " + ot
			score = "%d-%d" % [mine, theirs]
			record = "%d-%d-%d" % [w, l, otl]
			cell_bg[6] = AppTheme.result_color(result)
		else:
			row["color"] = AppTheme.MUTED
		row["cells"] = [n, Game.date_string(g["day"]), "vs" if home else "@", "", UI.team_name(opp),
			Game.record_string(opp), result, score, record]
		row["keys"] = [n, g["day"], "vs" if home else "@", opp, UI.team_name(opp), 0, result, score, n]
		row["cell_bg"] = cell_bg
		rows.append(row)
	table.set_rows(rows)
	# Scroll to the next game.
	table.sort_by(0, false)
