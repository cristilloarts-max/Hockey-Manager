class_name OffersView
extends ScrollContainer
## Trade offers AI teams have sent you.


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var page := UI.vbox(12)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(page)
	var top := UI.hbox(10)
	page.add_child(top)
	top.add_child(UI.heading("Trade offers"))
	top.add_child(UI.spacer())
	top.add_child(UI.label("Put players on your trading block (from their profile) to attract more offers.", 13, AppTheme.MUTED))
	if not Game.trades_open():
		page.add_child(UI.label("Trading is closed until the offseason.", 15, AppTheme.MUTED))
	if Game.offers.is_empty():
		page.add_child(UI.label("No offers right now. AI teams call more often as the deadline gets close.", 15, AppTheme.MUTED))
	for o in Game.offers:
		page.add_child(_offer_card(o))
	if not Game.trading_block.is_empty():
		var card := UI.card("Your trading block")
		for key in Game.trading_block:
			var p := League.get_player(int(key))
			if p != null and p.team_id == Game.user_team_id:
				var row := UI.hbox(8)
				row.add_child(UI.label("%s  (%s, %d)" % [p.full_name(), p.position, p.overall], 14))
				row.add_child(UI.button("Remove", func():
					Game.trading_block.erase(key)
					Hub.go("Offers")))
				UI.body(card).add_child(row)
		page.add_child(card)


func _offer_card(o: Dictionary) -> Control:
	var trade: Dictionary = o["trade"]
	var from: String = o["from"]
	var team := League.get_team(from)
	var panel := PanelContainer.new()
	var st := AppTheme.box(AppTheme.PANEL, 10, Color(0, 0, 0, 0), 0, 16, 14)
	st.border_color = team.accent()
	st.border_width_left = 6
	panel.add_theme_stylebox_override("panel", st)
	var box := UI.vbox(8)
	panel.add_child(box)
	var head := UI.hbox(10)
	box.add_child(head)
	head.add_child(TeamCrest.make(from, 34))
	var t := UI.vbox(0)
	t.add_child(UI.label("Offer from the %s" % team.full_name(), 17, Color.WHITE))
	t.add_child(UI.label("%s  |  expires %s" % [TradeAI.strategy_label(from), Game.short_date(o["expires"])], 12, AppTheme.MUTED))
	head.add_child(t)
	head.add_child(UI.spacer())
	var fair := TradeAI.fair_for(trade, Game.user_team_id)
	var verdict := "Great for you" if fair >= 1.15 else ("Fair" if fair >= 0.95 else ("Slightly in their favor" if fair >= 0.8 else "Lopsided"))
	var vcol := AppTheme.GREEN if fair >= 1.15 else (AppTheme.LIME if fair >= 0.95 else (AppTheme.YELLOW if fair >= 0.8 else AppTheme.RED))
	head.add_child(UI.pill(verdict, vcol))

	var cols := UI.hbox(30)
	box.add_child(cols)
	for side in [["They want", "a_gives"], ["They offer", "b_gives"]]:
		var c := UI.vbox(4)
		c.add_child(UI.caption(side[0]))
		for asset in trade[side[1]]:
			c.add_child(UI.label(TradeAI.describe(asset), 15))
		cols.add_child(c)

	var buttons := UI.hbox(8)
	box.add_child(buttons)
	var accept := UI.button("Accept", func():
		var err := Game.accept_offer(int(o["id"]))
		if err != "":
			var d := AcceptDialog.new()
			d.title = "Trade failed"
			d.dialog_text = err
			add_child(d)
			d.popup_centered()
		if Hub.current != null:
			Hub.current.refresh_bar()
		Hub.go("Offers"))
	accept.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.GREEN.darkened(0.35), 6))
	buttons.add_child(accept)
	buttons.add_child(UI.button("Decline", func():
		Game.decline_offer(int(o["id"]))
		Hub.go("Offers")))
	buttons.add_child(UI.button("Negotiate in Trade Center", func(): Hub.go("Trade Center", {"trade": trade})))
	return panel
