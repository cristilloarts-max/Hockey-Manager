class_name RosterView
extends VBoxContainer
## Your players. Colors: overall and average rating as tiles, condition and
## morale as colored text, squad status in the last column.

var _filter := 0   ## 0 all, 1 forwards, 2 defense, 3 goalies
var _table: DataTable


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var top := UI.hbox(10)
	add_child(top)
	top.add_child(UI.heading("Players"))
	var group := ButtonGroup.new()
	var names := ["All", "Forwards", "Defense", "Goalies"]
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == 0
		b.custom_minimum_size = Vector2(90, 32)
		b.pressed.connect(func():
			_filter = i
			_fill())
		top.add_child(b)
	top.add_child(UI.spacer())
	var roster := League.roster(Game.user_team_id)
	var age := 0.0
	for p in roster:
		age += p.age
	top.add_child(UI.pill("%d players" % roster.size(), AppTheme.PANEL_3, AppTheme.TEXT))
	top.add_child(UI.pill("Avg age %.1f" % (age / maxf(1, roster.size())), AppTheme.PANEL_3, AppTheme.TEXT))
	top.add_child(UI.pill("Cap space %s" % Game.money(League.cap_space(Game.user_team_id)), AppTheme.PANEL_3, AppTheme.TEXT))
	add_child(UI.label("Double-click a player to open his profile. Click a column title to sort.", 13, AppTheme.MUTED))

	_table = make_table(Game.user_team_id)
	add_child(_table)
	_fill()


## A styled roster table for any team (also used on opponents' club pages).
static func make_table(team_id: String, filter: int = 0) -> DataTable:
	var t := DataTable.new()
	t.setup([["", 10], ["#", 40], ["Player", 0], ["Pos", 46], ["Role", 56], ["Age", 46], ["OVR", 52],
		["Potential", 84], ["Cond", 60], ["Morale", 92], ["Form", 56], ["GP", 44], ["G", 40], ["A", 40],
		["PTS", 48], ["Avg Rat", 64], ["Cap Hit", 90], ["Status", 132]])
	t.row_activated.connect(func(id): Hub.go("Player", int(id)))
	t.set_rows(rows_for(team_id, filter))
	t.sort_by(6, true)
	return t


static func rows_for(team_id: String, filter: int) -> Array:
	var team := League.get_team(team_id)
	var rows := []
	for p in League.roster(team_id):
		if filter == 1 and (p.is_goalie() or p.is_defense()):
			continue
		if filter == 2 and not p.is_defense():
			continue
		if filter == 3 and not p.is_goalie():
			continue
		var line := Game.player_line(p.id)
		var gp: int = line.get("gp", 0)
		var g: int = line.get("g", 0)
		var a: int = line.get("a", 0)
		var cond := Game.condition_of(p.id)
		var m := Game.morale_of(p.id)
		var f := Game.form_of(p.id)
		var favg := 0.0
		for r in f:
			favg += float(r)
		if not f.is_empty():
			favg /= f.size()
		var avg := Game.avg_rating(p.id)
		var status := Game.squad_status(p)
		var cell_bg := {0: team.primary, 6: AppTheme.ovr_color(p.overall)}
		if favg > 0:
			cell_bg[10] = AppTheme.rating_color(favg)
		if avg > 0:
			cell_bg[15] = AppTheme.rating_color(avg)
		rows.append({"id": p.id,
			"cells": ["", p.number, p.full_name(), p.position, Roles.get_role(Roles.best(p)).get("abbr", ""), p.age,
				p.overall, p.potential_range(), "%d%%" % int(cond), AppTheme.morale_label(m),
				"%.1f" % favg if favg > 0 else "-", gp, g if not p.is_goalie() else 0, a if not p.is_goalie() else 0,
				g + a if not p.is_goalie() else 0, "%.2f" % avg if avg > 0 else "-", Game.money(p.cap_hit()), status],
			"keys": [0, p.number, p.last_name, p.position, "", p.age, p.overall, p.potential, cond, m, favg, gp, g, a,
				g + a, avg, p.cap_hit(), status],
			"cell_bg": cell_bg,
			"cell_colors": {8: AppTheme.condition_color(cond), 9: AppTheme.morale_color(m), 17: _status_color(status)}})
	return rows


static func _status_color(status: String) -> Color:
	match status:
		"Key Player":
			return AppTheme.GOLD
		"Important Player":
			return AppTheme.GREEN
		"Regular Starter":
			return AppTheme.LIME
		"Prospect":
			return AppTheme.BLUE
	return AppTheme.MUTED


func _fill() -> void:
	_table.set_rows(rows_for(Game.user_team_id, _filter))
