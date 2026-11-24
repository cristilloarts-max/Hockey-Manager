class_name Hub
extends HBoxContainer
## Main game screen: navigation on the left, top bar with the calendar
## controls, and the active view.

signal quit_to_title

const VIEWS := ["Home", "Roster", "Lines", "Tactics", "Contracts & Cap", "Schedule", "Standings", "League Stats"]

var _content: Control
var _view: Control
var _view_name := ""
var _nav_buttons := {}
var _team_label: Label
var _record_label: Label
var _date_label: Label
var _continue_btn: Button
var _sim_end_btn: Button


func _ready() -> void:
	add_theme_constant_override("separation", 0)

	# ---- navigation
	var nav_panel := PanelContainer.new()
	nav_panel.custom_minimum_size = Vector2(200, 0)
	add_child(nav_panel)
	var nav := UI.vbox(4)
	nav_panel.add_child(UI.margin(nav, 10))
	var team := League.get_team(Game.user_team_id)
	nav.add_child(UI.label(team.city, 14, UI.MUTED))
	nav.add_child(UI.label(team.name, 22))
	nav.add_child(HSeparator.new())
	var group := ButtonGroup.new()
	for v in VIEWS:
		var b := Button.new()
		b.text = v
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 36)
		b.pressed.connect(show_view.bind(v))
		nav.add_child(b)
		_nav_buttons[v] = b
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	nav.add_child(UI.button("Save Game", _on_save))
	nav.add_child(UI.button("Main Menu", func(): quit_to_title.emit()))

	# ---- main column
	var main := UI.vbox(0)
	UI.expand(main)
	add_child(main)

	var bar_panel := PanelContainer.new()
	main.add_child(bar_panel)
	var bar := UI.hbox(16)
	bar_panel.add_child(UI.margin(bar, 10))
	_team_label = UI.label(team.full_name(), 20)
	bar.add_child(_team_label)
	_record_label = UI.label("", 16, UI.MUTED)
	bar.add_child(_record_label)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_date_label = UI.label("", 16)
	bar.add_child(_date_label)
	_continue_btn = UI.button("Continue  >", _on_continue)
	_continue_btn.custom_minimum_size = Vector2(150, 36)
	_continue_btn.tooltip_text = "Sim to your next game and show the result."
	bar.add_child(_continue_btn)
	_sim_end_btn = UI.button("Sim to End of Season", _on_sim_end)
	bar.add_child(_sim_end_btn)

	_content = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, 16)
	UI.expand(_content)
	main.add_child(_content)

	_refresh_bar()
	_nav_buttons["Home"].button_pressed = true
	show_view("Home")


func show_view(view_name: String) -> void:
	if _view != null:
		_view.queue_free()
	_view_name = view_name
	match view_name:
		"Home":
			_view = HomeView.new()
		"Roster":
			_view = RosterView.new()
		"Lines":
			_view = LinesView.new()
		"Tactics":
			_view = TacticsView.new()
		"Contracts & Cap":
			_view = CapView.new()
		"Schedule":
			_view = ScheduleView.new()
		"Standings":
			_view = StandingsView.new()
		"League Stats":
			_view = StatsView.new()
	UI.expand(_view)
	_content.add_child(_view)
	if _nav_buttons.has(view_name):
		_nav_buttons[view_name].button_pressed = true


func _refresh_bar() -> void:
	var r: Dictionary = Game.standings[Game.user_team_id]
	_record_label.text = "%s  |  %d pts" % [Game.record_string(Game.user_team_id), r["pts"]]
	if Game.is_season_over():
		_date_label.text = "Regular season complete"
		_continue_btn.disabled = true
		_sim_end_btn.disabled = true
	else:
		_date_label.text = Game.date_string()


func _on_continue() -> void:
	var lineup: Lineup = Game.lineups[Game.user_team_id]
	var problems := lineup.problems()
	if not problems.is_empty():
		var dlg := ConfirmationDialog.new()
		dlg.title = "Lineup problems"
		dlg.dialog_text = "\n".join(problems) + "\n\nEmpty spots will be auto-filled. Continue anyway?"
		dlg.confirmed.connect(_do_continue)
		add_child(dlg)
		dlg.popup_centered()
		return
	_do_continue()


func _do_continue() -> void:
	var mine := Game.sim_to_next_game()
	_refresh_bar()
	show_view(_view_name)
	if not mine.is_empty():
		BoxScoreWindow.open(self, mine[-1])


func _on_sim_end() -> void:
	Game.sim_to_end()
	_refresh_bar()
	show_view("Standings")


func _on_save() -> void:
	var ok := Game.save_game()
	var dlg := AcceptDialog.new()
	dlg.title = "Save"
	dlg.dialog_text = "Game saved." if ok else "Could not save the game."
	add_child(dlg)
	dlg.popup_centered()
