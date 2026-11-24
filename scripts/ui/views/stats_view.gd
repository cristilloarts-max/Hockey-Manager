class_name StatsView
extends VBoxContainer

var _mode := 0   ## 0 skaters, 1 goalies
var _mine_only := false
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
	var mine := CheckBox.new()
	mine.text = "My team only"
	mine.toggled.connect(func(on):
		_mine_only = on
		_fill())
	top.add_child(mine)
	_table = DataTable.new()
	_table.row_activated.connect(func(id): PlayerWindow.open(self, int(id)))
	add_child(_table)
	_fill()


func _fill() -> void:
	var rows := []
	if _mode == 0:
		_table.setup([["Player", 0], ["Team", 60], ["Pos", 50], ["GP", 50], ["G", 50], ["A", 50], ["PTS", 55],
			["+/-", 50], ["PIM", 50], ["SOG", 55], ["S%", 60], ["PPG", 50], ["SHG", 50], ["TOI/GP", 75]])
		for key in Game.skater_stats:
			var p := League.get_player(int(key))
			if p == null or (_mine_only and p.team_id != Game.user_team_id):
				continue
			var s: Dictionary = Game.skater_stats[key]
			var sp: float = 100.0 * s["g"] / s["shots"] if s["shots"] > 0 else 0.0
			var toi: float = float(s["toi"]) / maxi(1, s["gp"])
			rows.append({"id": p.id,
				"cells": [p.full_name(), p.team_id, p.position, s["gp"], s["g"], s["a"], s["pts"], s["pm"], s["pim"],
					s["shots"], "%.1f" % sp, s["ppg"], s["shg"], UI.fmt_toi(toi)],
				"keys": [p.last_name, p.team_id, p.position, s["gp"], s["g"], s["a"], s["pts"] + s["g"] * 0.001, s["pm"],
					s["pim"], s["shots"], sp, s["ppg"], s["shg"], toi]})
		_table.set_rows(rows)
		_table.sort_by(6, true)
	else:
		_table.setup([["Goalie", 0], ["Team", 60], ["GP", 50], ["W", 50], ["L", 50], ["OTL", 50], ["SA", 60],
			["GA", 50], ["SV%", 70], ["GAA", 60], ["SO", 50]])
		for key in Game.goalie_season:
			var p := League.get_player(int(key))
			if p == null or (_mine_only and p.team_id != Game.user_team_id):
				continue
			var s: Dictionary = Game.goalie_season[key]
			var sv: float = float(s["sa"] - s["ga"]) / s["sa"] if s["sa"] > 0 else 0.0
			var gaa: float = s["ga"] * 3600.0 / maxf(1.0, s["toi"])
			rows.append({"id": p.id,
				"cells": [p.full_name(), p.team_id, s["gp"], s["w"], s["l"], s["otl"], s["sa"], s["ga"],
					"%.3f" % sv, "%.2f" % gaa, s["so"]],
				"keys": [p.last_name, p.team_id, s["gp"], s["w"], s["l"], s["otl"], s["sa"], s["ga"], sv, -gaa, s["so"]]})
		_table.set_rows(rows)
		_table.sort_by(3, true)
