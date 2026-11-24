class_name InboxView
extends ScrollContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(list)
	list.add_child(UI.heading("Inbox"))
	if Game.inbox.is_empty():
		list.add_child(UI.label("No messages.", 14, AppTheme.MUTED))
	for m in Game.inbox:
		list.add_child(message_row(m))


## A message card with a colored stripe: green for wins, red for losses.
static func message_row(m: Dictionary) -> Control:
	var title: String = m["title"]
	var stripe := AppTheme.ACCENT_2
	if title.begins_with("Win"):
		stripe = AppTheme.RESULT_W
	elif title.begins_with("Loss"):
		stripe = AppTheme.RESULT_L
	var panel := PanelContainer.new()
	var style := AppTheme.box(AppTheme.PANEL_2, 6, Color(0, 0, 0, 0), 0, 14, 10)
	style.border_color = stripe
	style.border_width_left = 4
	panel.add_theme_stylebox_override("panel", style)
	var box := UI.vbox(4)
	panel.add_child(box)
	var head := UI.hbox(10)
	box.add_child(head)
	head.add_child(UI.label(title, 16, Color.WHITE))
	head.add_child(UI.spacer())
	head.add_child(UI.label(Game.short_date(int(m["day"])), 12, AppTheme.MUTED))
	var body := UI.label(m["body"], 14, AppTheme.MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return panel
