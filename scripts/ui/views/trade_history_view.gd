class_name TradeHistoryView
extends VBoxContainer
## Every trade made this season.


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UI.heading("Trade history"))
	if Game.trade_history.is_empty():
		add_child(UI.label("No trades yet this season.", 15, AppTheme.MUTED))
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.expand(scroll)
	add_child(scroll)
	var list := UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var history := Game.trade_history.duplicate()
	history.reverse()
	for t in history:
		var mine: bool = t["a"] == Game.user_team_id or t["b"] == Game.user_team_id
		var card := UI.card("", 12)
		if mine:
			card.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.PANEL, 8, UI.USER_COLOR, 1, 12, 12))
		var row := UI.hbox(24)
		UI.body(card).add_child(row)
		var date := UI.label(Game.short_date(int(t["day"])), 14, AppTheme.MUTED)
		date.custom_minimum_size = Vector2(70, 0)
		row.add_child(date)
		for side in [[t["b"], t["a_gives"]], [t["a"], t["b_gives"]]]:
			var col := UI.vbox(4)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var head := UI.hbox(8)
			head.add_child(TeamCrest.make(side[0], 22))
			head.add_child(UI.label("%s get" % League.get_team(side[0]).name, 15, League.get_team(side[0]).accent()))
			col.add_child(head)
			for item in side[1]:
				col.add_child(UI.label(item, 14))
			row.add_child(col)
		list.add_child(card)
