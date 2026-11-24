class_name ScheduleView
extends VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UI.heading("Schedule & Results"))
	add_child(UI.label("Double-click a played game for the box score and play-by-play.", 0, UI.MUTED))
	var table := DataTable.new()
	table.setup([["#", 50], ["Date", 170], ["", 40], ["Opponent", 0], ["Result", 90], ["Score", 90], ["Record", 100]])
	table.row_activated.connect(func(idx): BoxScoreWindow.open(self, int(idx)))
	add_child(table)

	var team_id := Game.user_team_id
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
		var color := Color.WHITE
		if g["played"]:
			var mine: int = g["hg"] if home else g["ag"]
			var theirs: int = g["ag"] if home else g["hg"]
			var ot: String = g.get("ot", "")
			if mine > theirs:
				result = "W"
				w += 1
				color = Color(0.5, 0.9, 0.55)
			elif ot != "":
				result = "OTL"
				otl += 1
				color = Color(0.95, 0.85, 0.4)
			else:
				result = "L"
				l += 1
				color = Color(1, 0.55, 0.5)
			if ot != "":
				result += " (%s)" % ot
			score = "%d-%d" % [mine, theirs]
			record = "%d-%d-%d" % [w, l, otl]
		else:
			color = UI.MUTED
		rows.append({"id": i, "cells": [n, Game.date_string(g["day"]), "vs" if home else "@", UI.team_name(opp), result, score, record],
			"keys": [n, g["day"], "vs" if home else "@", UI.team_name(opp), result, score, n], "color": color})
	table.set_rows(rows)
