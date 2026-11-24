class_name RosterView
extends VBoxContainer

var _table: DataTable
var _filter := 0   ## 0 all, 1 forwards, 2 defense, 3 goalies


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var top := UI.hbox(12)
	add_child(top)
	top.add_child(UI.heading("Roster"))
	var filter := OptionButton.new()
	for f in ["All players", "Forwards", "Defense", "Goalies"]:
		filter.add_item(f)
	filter.item_selected.connect(func(i):
		_filter = i
		_fill())
	top.add_child(filter)
	top.add_child(UI.label("Double-click a player for his profile. 'Also plays' lists spots he's comfortable at (familiarity 14+).", 0, UI.MUTED))

	_table = DataTable.new()
	_table.setup([["#", 44], ["Name", 0], ["Pos", 50], ["Also plays", 100], ["Side", 90], ["Age", 50],
		["OVR", 55], ["POT", 70], ["GP", 50], ["G", 45], ["A", 45], ["PTS", 55], ["Cap hit", 95], ["Yrs", 45], ["Status", 70]])
	_table.row_activated.connect(func(id): PlayerWindow.open(self, int(id)))
	add_child(_table)
	_fill()
	_table.sort_by(6, true)


func _fill() -> void:
	var rows := []
	for p in League.roster(Game.user_team_id):
		if _filter == 1 and (p.is_goalie() or p.is_defense()):
			continue
		if _filter == 2 and not p.is_defense():
			continue
		if _filter == 3 and not p.is_goalie():
			continue
		var line := Game.player_line(p.id)
		var gp: int = line.get("gp", 0)
		var g: int = line.get("g", 0) if not p.is_goalie() else 0
		var a: int = line.get("a", 0) if not p.is_goalie() else 0
		var side := ""
		if not p.is_goalie() and p.position != "C":
			side = "Off side" if p.prefers_off_side else "Strong side"
		elif p.position == "C":
			side = "%s shot" % p.shoots
		rows.append({"id": p.id,
			"cells": [p.number, p.full_name(), p.position, ", ".join(p.comfortable), side, p.age,
				p.overall, p.potential_range(), gp, g, a, g + a, Game.money(p.cap_hit()),
				p.contract["years"], p.contract["expiry_status"]],
			"keys": [p.number, p.last_name, p.position, ", ".join(p.comfortable), side, p.age,
				p.overall, p.potential, gp, g, a, g + a, p.cap_hit(), p.contract["years"], p.contract["expiry_status"]]})
	_table.set_rows(rows)
