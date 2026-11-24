class_name TitleScreen
extends Control

signal new_game
signal load_game


func _ready() -> void:
	# A faded rink in the background.
	var rink := Rink.new()
	rink.vertical = false
	rink.modulate = Color(1, 1, 1, 0.35)
	rink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rink.offset_left = 120
	rink.offset_right = -120
	rink.offset_top = 90
	rink.offset_bottom = -90
	add_child(rink)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", AppTheme.box(Color(AppTheme.BG, 0.92), 14, AppTheme.BORDER, 1, 40, 34))
	center.add_child(panel)
	var box := UI.vbox(14)
	box.custom_minimum_size = Vector2(380, 0)
	panel.add_child(box)
	var title := UI.label("HOCKEY MANAGER", 46, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var stripe := ColorRect.new()
	stripe.color = AppTheme.ACCENT
	stripe.custom_minimum_size = Vector2(0, 4)
	box.add_child(stripe)
	var sub := UI.label("Season %s" % League.season_label, 16, AppTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)
	var start := UI.button("New Career", func(): new_game.emit())
	start.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.ACCENT, 6))
	start.add_theme_stylebox_override("hover", AppTheme.box(AppTheme.ACCENT.lightened(0.1), 6))
	box.add_child(start)
	var load_btn := UI.button("Load Career", func(): load_game.emit())
	load_btn.disabled = not Game.has_save()
	box.add_child(load_btn)
	box.add_child(UI.button("Quit", func(): get_tree().quit()))
	for b in box.get_children():
		if b is Button:
			b.custom_minimum_size = Vector2(0, 48)
			b.add_theme_font_size_override("font_size", 18)
