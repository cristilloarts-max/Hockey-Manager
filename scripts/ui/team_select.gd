class_name TeamSelect
extends MarginContainer
## Pick the team to take over.

signal team_chosen(team_id)
signal back

var _table: DataTable
var _details: VBoxContainer
var _choose_btn: Button
var _selected := ""


func _ready() -> void:
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 24)
	var root := UI.vbox(12)
	add_child(root)

	var top := UI.hbox()
	top.add_child(UI.button("< Back", func(): back.emit()))
	top.add_child(UI.heading("Choose your team"))
	root.add_child(top)
	root.add_child(UI.label("Double-click a team, or select it and press Take Over. Click a column title to sort.", 0, UI.MUTED))

	var body := UI.hbox(16)
	UI.expand(body)
	root.add_child(body)

	_table = DataTable.new()
	_table.setup([["Team", 0], ["Conference", 110], ["Division", 120], ["Strength", 90],
		["Payroll", 100], ["Cap space", 100], ["Best player", 230]])
	_table.row_selected.connect(_on_selected)
	_table.row_activated.connect(func(id): team_chosen.emit(id))
	body.add_child(_table)

	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(380, 0)
	body.add_child(side_panel)
	_details = UI.vbox(6)
	side_panel.add_child(UI.margin(_details))

	_choose_btn = UI.button("Take Over", func():
		if _selected != "":
			team_chosen.emit(_selected))
	_choose_btn.disabled = true
	_choose_btn.custom_minimum_size = Vector2(0, 44)
	root.add_child(_choose_btn)

	var rows := []
	for t in League.team_list():
		var r := League.roster(t.id)
		var best = r[0] if not r.is_empty() else null
		var strength := League.team_strength(t.id)
		var payroll := League.payroll(t.id)
		var space := League.cap_space(t.id)
		rows.append({"id": t.id,
			"cells": [t.full_name(), t.conference, t.division, "%.1f" % strength,
				Game.money(payroll), Game.money(space),
				"%s (%d)" % [best.full_name(), best.overall] if best else "-"],
			"keys": [t.full_name(), t.conference, t.division, strength, payroll, space,
				best.overall if best else 0]})
	_table.set_rows(rows)
	_table.sort_by(3, true)
	_show_details("")


func _on_selected(id) -> void:
	_selected = id
	_choose_btn.disabled = false
	_choose_btn.text = "Take Over the %s" % UI.team_name(id)
	_show_details(id)


func _show_details(id: String) -> void:
	for c in _details.get_children():
		c.queue_free()
	if id == "":
		_details.add_child(UI.label("Select a team to see its key players.", 0, UI.MUTED))
		return
	var t := League.get_team(id)
	_details.add_child(UI.heading(t.full_name()))
	_details.add_child(UI.label("%s Conference, %s Division" % [t.conference, t.division], 0, UI.MUTED))
	_details.add_child(UI.label("Payroll %s  |  Cap space %s" % [Game.money(League.payroll(id)), Game.money(League.cap_space(id))]))
	_details.add_child(HSeparator.new())
	_details.add_child(UI.label("Top players", 16))
	var r := League.roster(id)
	for p in r.slice(0, 8):
		_details.add_child(UI.label("%-3s %s  %d  (age %d, %s)" % [p.position, p.full_name(), p.overall, p.age, Game.money(p.cap_hit())]))
	var young := r.filter(func(p): return p.age <= 22)
	young.sort_custom(func(a, b): return a.potential > b.potential)
	if not young.is_empty():
		_details.add_child(HSeparator.new())
		_details.add_child(UI.label("Top young players", 16))
		for p in young.slice(0, 4):
			_details.add_child(UI.label("%-3s %s  %d, potential %s (age %d)" % [p.position, p.full_name(), p.overall, p.potential_range(), p.age]))
