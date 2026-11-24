class_name TitleScreen
extends CenterContainer

signal new_game
signal load_game


func _ready() -> void:
	var box := UI.vbox(16)
	box.custom_minimum_size = Vector2(360, 0)
	add_child(box)
	var title := UI.label("HOCKEY MANAGER", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UI.label("Season %s" % League.season_label, 18, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(HSeparator.new())
	box.add_child(UI.button("New Game", func(): new_game.emit()))
	var load_btn := UI.button("Load Game", func(): load_game.emit())
	load_btn.disabled = not Game.has_save()
	box.add_child(load_btn)
	box.add_child(UI.button("Quit", func(): get_tree().quit()))
	for b in box.get_children():
		if b is Button:
			b.custom_minimum_size = Vector2(0, 44)
