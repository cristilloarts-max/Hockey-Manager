extends Control
## Root scene: swaps between the title screen, team picker and the hub.

var _current: Control


func _ready() -> void:
	theme = AppTheme.build()
	get_window().theme = theme
	# Deep gradient background.
	var bg := TextureRect.new()
	bg.texture = AppTheme.gradient(Color("#0e1626"), AppTheme.BG)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if not League.load_default():
		_swap(UI.label("Could not load data/league.json. Run tools/build_league.py first.", 20))
		return
	get_window().min_size = Vector2i(1280, 760)
	show_title()


func _swap(screen: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = screen
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_title() -> void:
	var t := TitleScreen.new()
	t.new_game.connect(show_team_select)
	t.load_game.connect(_on_load)
	_swap(t)


func show_team_select() -> void:
	League.load_default()
	var s := TeamSelect.new()
	s.team_chosen.connect(_on_team_chosen)
	s.back.connect(show_title)
	_swap(s)


func show_hub() -> void:
	var h := Hub.new()
	h.quit_to_title.connect(show_title)
	_swap(h)


func _on_team_chosen(team_id: String) -> void:
	Game.new_game(team_id)
	show_hub()


func _on_load() -> void:
	if Game.load_game():
		show_hub()
