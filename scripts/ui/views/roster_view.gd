class_name RosterView
extends VBoxContainer
## Your players. Colors: overall and average rating as tiles, condition and
## morale as colored text, squad status in the last column.

var _filter := 0   ## 0 all, 1 forwards, 2 defense, 3 goalies
var _table: DataTable
var _selected := 0
var _down_btn: Button
var _up_btn: Button


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
	var team_id := Game.user_team_id
	var nhl := League.nhl_roster(team_id)
	var goalies := nhl.filter(func(p): return p.is_goalie()).size()
	var size_ok: bool = nhl.size() <= Game.roster_max() and nhl.size() >= Game.roster_min()
	var space := League.cap_space(team_id)
	top.add_child(UI.pill("NHL roster %d / %d" % [nhl.size(), Game.roster_max()], AppTheme.GREEN if size_ok else AppTheme.RED))
	top.add_child(UI.pill("Goalies %d" % goalies, AppTheme.GREEN if goalies >= 2 else AppTheme.RED))
	top.add_child(UI.pill("Cap space %s" % Game.money(space), AppTheme.GREEN if space >= 0 else AppTheme.RED))

	var actions := UI.hbox(8)
	add_child(actions)
	actions.add_child(UI.label("Double-click a player for his profile. Select one to move him:", 13, AppTheme.MUTED))
	_down_btn = UI.button("Send to Reserve", func(): _move("Reserve"))
	_up_btn = UI.button("Call Up to NHL", func(): _move("NHL"))
	_down_btn.disabled = true
	_up_btn.disabled = true
	actions.add_child(_down_btn)
	actions.add_child(_up_btn)
	actions.add_child(UI.spacer())
	var problems := Game.roster_problems(team_id)
	if not problems.is_empty():
		actions.add_child(UI.label("! " + problems[0], 13, AppTheme.RED))
	else:
		actions.add_child(UI.label("Roster is legal: max 23 on the NHL roster, two goalies, under the cap. Reserve players only count against the cap above %s." % Game.money(League.finances.get("bury_allowance", 1150000)), 12, AppTheme.MUTED))

	_table = make_table(Game.user_team_id)
	_table.row_selected.connect(func(id):
		_selected = int(id)
		var p := League.get_player(_selected)
		_down_btn.disabled = p == null or not p.on_nhl_roster()
		_up_btn.disabled = p == null or p.on_nhl_roster())
	add_child(_table)
	_fill()


func _move(status: String) -> void:
	if _selected == 0:
		return
	Game.set_roster_status(_selected, status)
	if Hub.current != null:
		Hub.current.refresh()


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
		var cell_bg := {0: team.primary if p.on_nhl_roster() else AppTheme.PANEL_3, 6: AppTheme.ovr_color(p.overall)}
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
			"cell_colors": {8: AppTheme.condition_color(cond), 9: AppTheme.morale_color(m), 17: _status_color(status)},
			"color": AppTheme.TEXT if p.on_nhl_roster() else AppTheme.FAINT})
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
