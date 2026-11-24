class_name Hub
extends VBoxContainer
## Main game screen. Football Manager-style navigation:
##   row 1: back/forward, your crest, section menus, date + next game, Continue
##   row 2: the current section's pages
## Any view can navigate with Hub.go("Player", pid), Hub.go("Club", team_id)...

signal quit_to_title

const SECTIONS := {
	"HOME": ["Overview", "Inbox"],
	"SQUAD": ["Players", "Lines", "Contracts"],
	"TACTICS": ["Tactics"],
	"LEAGUE": ["Schedule", "Standings", "Stats", "Playoffs", "Awards"],
}
## Pages that belong to a section without having their own sub-tab.
const PAGE_SECTION := {"Player": "SQUAD", "Club": "LEAGUE"}

static var current: Hub

var _history: Array = []     ## [page, arg]
var _hist_index := -1
var _page := ""
var _arg: Variant = null
var _section := ""
var _content: MarginContainer
var _view: Control
var _menu_buttons := {}
var _subbar: HBoxContainer
var _date_label: Label
var _next_label: Label
var _record_label: Label
var _continue_btn: Button
var _back_btn: Button
var _fwd_btn: Button


static func go(page: String, arg: Variant = null) -> void:
	if current != null:
		current.navigate(page, arg)


func _ready() -> void:
	current = self
	add_theme_constant_override("separation", 0)
	var team := League.get_team(Game.user_team_id)

	# ---- row 1: main bar in team colors
	var bar := PanelContainer.new()
	var bar_style := AppTheme.box(team.primary.darkened(0.55).lerp(AppTheme.BG, 0.25), 0, Color(0, 0, 0, 0), 0, 10, 6)
	bar_style.border_color = team.accent()
	bar_style.border_width_bottom = 3
	bar.add_theme_stylebox_override("panel", bar_style)
	add_child(bar)
	var row := UI.hbox(6)
	bar.add_child(row)
	_back_btn = _icon_button("<", func(): _step_history(-1))
	_fwd_btn = _icon_button(">", func(): _step_history(1))
	row.add_child(_back_btn)
	row.add_child(_fwd_btn)
	var crest := TeamCrest.make(team.id, 34)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	row.add_child(gap)
	for section in SECTIONS:
		var b := _menu_button(section)
		b.pressed.connect(navigate.bind(SECTIONS[section][0]))
		row.add_child(b)
		_menu_buttons[section] = b
	row.add_child(UI.spacer())
	var date_box := UI.vbox(0)
	date_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_date_label = UI.label("", 15)
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_label = UI.label("", 12, AppTheme.MUTED)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_box.add_child(_date_label)
	date_box.add_child(_next_label)
	row.add_child(date_box)
	_continue_btn = Button.new()
	_continue_btn.text = "Continue   >>"
	_continue_btn.custom_minimum_size = Vector2(200, 44)
	_continue_btn.add_theme_font_size_override("font_size", 17)
	_continue_btn.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.ACCENT, 4))
	_continue_btn.add_theme_stylebox_override("hover", AppTheme.box(AppTheme.ACCENT.lightened(0.12), 4))
	_continue_btn.add_theme_stylebox_override("pressed", AppTheme.box(AppTheme.ACCENT.darkened(0.15), 4))
	_continue_btn.add_theme_stylebox_override("disabled", AppTheme.box(AppTheme.PANEL_2, 4))
	_continue_btn.tooltip_text = "Sim to your next game and show the result."
	_continue_btn.pressed.connect(_on_continue)
	row.add_child(_continue_btn)
	var more := MenuButton.new()
	more.text = "..."
	more.flat = false
	more.custom_minimum_size = Vector2(40, 44)
	var popup := more.get_popup()
	popup.add_item("Sim to end of season", 0)
	popup.add_separator()
	popup.add_item("Save game", 1)
	popup.add_item("Main menu", 2)
	popup.id_pressed.connect(_on_menu)
	row.add_child(more)

	# ---- row 2: sub-tabs
	var sub := PanelContainer.new()
	sub.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.BG_2, 0, Color(0, 0, 0, 0), 0, 16, 0))
	add_child(sub)
	var sub_row := UI.hbox(4)
	sub.add_child(sub_row)
	_subbar = UI.hbox(2)
	sub_row.add_child(_subbar)
	sub_row.add_child(UI.spacer())
	_record_label = UI.label("", 13, AppTheme.MUTED)
	_record_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub_row.add_child(_record_label)

	# ---- page area
	_content = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, 18)
	UI.expand(_content)
	add_child(_content)

	_refresh_bar()
	navigate("Overview")


func _exit_tree() -> void:
	if current == self:
		current = null


# ------------------------------------------------------------------ navigation

func navigate(page: String, arg: Variant = null, record: bool = true) -> void:
	if record:
		_history = _history.slice(0, _hist_index + 1)
		_history.append([page, arg])
		_hist_index = _history.size() - 1
	_page = page
	_arg = arg
	_show_page()


func _step_history(delta: int) -> void:
	var i := _hist_index + delta
	if i < 0 or i >= _history.size():
		return
	_hist_index = i
	navigate(_history[i][0], _history[i][1], false)


func refresh() -> void:
	_refresh_bar()
	_show_page()


func _show_page() -> void:
	if _view != null:
		_view.queue_free()
	match _page:
		"Overview":
			_view = ClubView.new()
		"Club":
			var cv := ClubView.new()
			cv.team_id = _arg
			_view = cv
		"Inbox":
			_view = InboxView.new()
		"Players":
			_view = RosterView.new()
		"Player":
			var pv := PlayerView.new()
			pv.player_id = int(_arg)
			_view = pv
		"Lines":
			_view = LinesView.new()
		"Contracts":
			_view = CapView.new()
		"Tactics":
			_view = TacticsView.new()
		"Schedule":
			_view = ScheduleView.new()
		"Standings":
			_view = StandingsView.new()
		"Stats":
			_view = StatsView.new()
		"Playoffs":
			_view = PlayoffsView.new()
		"Awards":
			_view = AwardsView.new()
		_:
			_view = ClubView.new()
	UI.expand(_view)
	_content.add_child(_view)
	# Section highlight + sub-tabs.
	var section := ""
	for s in SECTIONS:
		if _page in SECTIONS[s]:
			section = s
	if section == "":
		section = PAGE_SECTION.get(_page, "HOME")
	if section != _section or _subbar.get_child_count() == 0:
		_section = section
		for c in _subbar.get_children():
			c.queue_free()
		for pg in SECTIONS[section]:
			var b := _sub_button(pg)
			b.pressed.connect(navigate.bind(pg))
			_subbar.add_child(b)
	for s in _menu_buttons:
		_menu_buttons[s].button_pressed = s == section
	for b in _subbar.get_children():
		if b is Button:
			b.button_pressed = b.text == _page
	_back_btn.disabled = _hist_index <= 0
	_fwd_btn.disabled = _hist_index >= _history.size() - 1


func _refresh_bar() -> void:
	var team_id := Game.user_team_id
	var r: Dictionary = Game.standings[team_id]
	_record_label.text = "%s   %s   %d pts" % [League.get_team(team_id).full_name(), Game.record_string(team_id), r["pts"]]
	if Game.is_season_over():
		var champ: String = Game.playoffs.get("champion", "")
		_date_label.text = "Season complete"
		_next_label.text = "%s won the Stanton Cup" % League.get_team(champ).name if champ != "" else ""
		_continue_btn.disabled = true
		_continue_btn.text = "Season Over"
		return
	_date_label.text = Game.date_string()
	_continue_btn.text = "Continue   >>"
	var info := Game.next_game_info()
	if not info.is_empty():
		var home: bool = info["home"] == team_id
		var opp: String = info["away"] if home else info["home"]
		var days: int = info["day"] - Game.day
		var when := "today" if days <= 0 else ("tomorrow" if days == 1 else "in %d days" % days)
		var label: String = info["label"]
		_next_label.text = "%s%s %s %s" % [label + ": " if label != "" else "", "vs" if home else "@", League.get_team(opp).name, when]
	elif Game.phase == "playoffs":
		_next_label.text = "Playoffs: %s" % Game.ROUND_NAMES[Game.playoffs["round"] - 1]
		_continue_btn.text = "Sim Round   >>"


# ------------------------------------------------------------------ actions

func _on_continue() -> void:
	var roster_issues := Game.roster_problems(Game.user_team_id)
	if not roster_issues.is_empty() and Game.phase != "done":
		var stop := AcceptDialog.new()
		stop.title = "Fix your roster first"
		stop.dialog_text = "\n".join(roster_issues) + "\n\nUse Squad > Players to call players up or send them to the reserve list."
		add_child(stop)
		stop.popup_centered()
		return
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
	refresh()
	if not mine.is_empty():
		BoxScoreWindow.open(self, mine[-1])


func _on_menu(id: int) -> void:
	match id:
		0:
			Game.sim_to_end()
			_refresh_bar()
			navigate("Standings")
		1:
			var ok := Game.save_game()
			var dlg := AcceptDialog.new()
			dlg.title = "Save"
			dlg.dialog_text = "Game saved." if ok else "Could not save the game."
			add_child(dlg)
			dlg.popup_centered()
		2:
			quit_to_title.emit()


# ------------------------------------------------------------------ styling

func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 16)
	var clear := Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", AppTheme.box(clear, 4, clear, 0, 14, 6))
	b.add_theme_stylebox_override("hover", AppTheme.box(Color(1, 1, 1, 0.08), 4, clear, 0, 14, 6))
	var on := AppTheme.underline(League.get_team(Game.user_team_id).accent(), Color(1, 1, 1, 0.06), 3)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	return b


func _sub_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 36)
	var clear := Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", AppTheme.underline(clear))
	b.add_theme_stylebox_override("hover", AppTheme.underline(AppTheme.PANEL_3))
	b.add_theme_stylebox_override("pressed", AppTheme.underline(AppTheme.ACCENT_2))
	b.add_theme_stylebox_override("hover_pressed", AppTheme.underline(AppTheme.ACCENT_2))
	b.add_theme_color_override("font_color", AppTheme.MUTED)
	return b


func _icon_button(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb)
	b.custom_minimum_size = Vector2(34, 34)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b
