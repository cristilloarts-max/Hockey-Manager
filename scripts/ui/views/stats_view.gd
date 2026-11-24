class_name StatsView
extends VBoxContainer

var _mode := 0   ## 0 skaters, 1 goalies
var _mine_only := false
var _playoffs := false
var _table: DataTable


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var top := UI.hbox(12)
	add_child(top)
	top.add_child(UI.heading("League Stats"))
	var mode := OptionButton.new()
	mode.add_item("Skaters")
	mode.add_item("Goalies")
	mode.item_selected.connect(func(i):
		_mode = i
		_fill())
	top.add_child(mode)
	var season := OptionButton.new()
	season.add_item("Regular season")
	season.add_item("Playoffs")
	season.disabled = Game.phase == "regular"
	season.item_selected.connect(func(i):
		_playoffs = i == 1
		_fill())
	top.add_child(season)
	var mine := CheckBox.new()
	mine.text = "My team only"
	mine.toggled.connect(func(on):
		_mine_only = on
		_fill())
	top.add_child(mine)
	_table = DataTable.new()
	_table.row_activated.connect(func(id): Hub.go("Player", int(id)))
	add_child(_table)
	_fill()


func _fill() -> void:
	var rows := []
	if _mode == 0:
		_table.setup([["", 10], ["Player", 0], ["Team", 60], ["Pos", 50], ["GP", 50], ["G", 50], ["A", 50], ["PTS", 55],
			["+/-", 50], ["PIM", 50], ["SOG", 55], ["S%", 60], ["PPG", 50], ["SHG", 50], ["TOI/GP", 75], ["Avg Rat", 70]])
		var src: Dictionary = Game.playoff_skaters if _playoffs else Game.skater_stats
		for key in src:
			var p := League.get_player(int(key))
			if p == null or (_mine_only and p.team_id != Game.user_team_id):
				continue
			var s: Dictionary = src[key]
			var sp: float = 100.0 * s["g"] / s["shots"] if s["shots"] > 0 else 0.0
			var toi: float = float(s["toi"]) / maxi(1, s["gp"])
			var avg: float = float(s.get("rsum", 0.0)) / s["rn"] if s.get("rn", 0) > 0 else 0.0
			var row := {"id": p.id,
				"cells": ["", p.full_name(), p.team_id, p.position, s["gp"], s["g"], s["a"], s["pts"], "%+d" % int(s["pm"]), s["pim"],
					s["shots"], "%.1f" % sp, s["ppg"], s["shg"], UI.fmt_toi(toi), "%.2f" % avg if avg > 0 else "-"],
				"keys": [p.team_id, p.last_name, p.team_id, p.position, s["gp"], s["g"], s["a"], s["pts"] + s["g"] * 0.001, s["pm"],
					s["pim"], s["shots"], sp, s["ppg"], s["shg"], toi, avg],
				"cell_bg": {0: League.get_team(p.team_id).primary}}
			if avg > 0:
				row["cell_bg"][15] = AppTheme.rating_color(avg)
			if p.team_id == Game.user_team_id:
				row["bg"] = Color(UI.USER_COLOR, 0.10)
			rows.append(row)
		_table.set_rows(rows)
		_table.sort_by(7, true)
	else:
		_table.setup([["", 10], ["Goalie", 0], ["Team", 60], ["GP", 50], ["W", 50], ["L", 50], ["OTL", 50], ["SA", 60],
			["GA", 50], ["SV%", 70], ["GAA", 60], ["SO", 50], ["Avg Rat", 70]])
		var gsrc: Dictionary = Game.playoff_goalies if _playoffs else Game.goalie_season
		for key in gsrc:
			var p := League.get_player(int(key))
			if p == null or (_mine_only and p.team_id != Game.user_team_id):
				continue
			var s: Dictionary = gsrc[key]
			var sv: float = float(s["sa"] - s["ga"]) / s["sa"] if s["sa"] > 0 else 0.0
			var gaa: float = s["ga"] * 3600.0 / maxf(1.0, s["toi"])
			var avg: float = float(s.get("rsum", 0.0)) / s["rn"] if s.get("rn", 0) > 0 else 0.0
			var row := {"id": p.id,
				"cells": ["", p.full_name(), p.team_id, s["gp"], s["w"], s["l"], s["otl"], s["sa"], s["ga"],
					"%.3f" % sv, "%.2f" % gaa, s["so"], "%.2f" % avg if avg > 0 else "-"],
				"keys": [p.team_id, p.last_name, p.team_id, s["gp"], s["w"], s["l"], s["otl"], s["sa"], s["ga"], sv, -gaa, s["so"], avg],
				"cell_bg": {0: League.get_team(p.team_id).primary},
				"cell_colors": {9: AppTheme.GREEN if sv >= 0.915 else (AppTheme.RED if sv < 0.895 and s["gp"] > 0 else AppTheme.TEXT)}}
			if avg > 0:
				row["cell_bg"][12] = AppTheme.rating_color(avg)
			if p.team_id == Game.user_team_id:
				row["bg"] = Color(UI.USER_COLOR, 0.10)
			rows.append(row)
		_table.set_rows(rows)
		_table.sort_by(4, true)
