class_name HomeView
extends VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var team_id := Game.user_team_id
	var team := League.get_team(team_id)
	add_child(UI.heading("Home"))

	var cards := UI.hbox(16)
	add_child(cards)

	# Next game.
	var next := Game.next_game_index(team_id)
	var next_txt := "Season complete"
	if next >= 0:
		var g: Dictionary = Game.schedule[next]
		var home: bool = g["home"] == team_id
		var opp: String = g["away"] if home else g["home"]
		next_txt = "%s\n%s %s\nOpponent record: %s" % [Game.date_string(g["day"]),
			"vs" if home else "@", UI.team_name(opp), Game.record_string(opp)]
	cards.add_child(_card("Next game", next_txt))

	# Last game.
	var last := Game.last_game_index(team_id)
	var last_txt := "No games played yet"
	if last >= 0:
		var g: Dictionary = Game.schedule[last]
		var home: bool = g["home"] == team_id
		var mine: int = g["hg"] if home else g["ag"]
		var theirs: int = g["ag"] if home else g["hg"]
		var opp: String = g["away"] if home else g["home"]
		var ot: String = g.get("ot", "")
		last_txt = "%s %d-%d %s %s%s" % ["W" if mine > theirs else "L", mine, theirs,
			"vs" if home else "@", UI.team_name(opp), "" if ot == "" else " (%s)" % ot]
	var last_card := _card("Last game", last_txt)
	if last >= 0:
		last_card.get_child(0).add_child(UI.button("Box score", func(): BoxScoreWindow.open(self, last)))
	cards.add_child(last_card)

	# Division position.
	var div_rows := Game.standings_sorted(func(t): return t.division == team.division)
	var pos := 1
	for r in div_rows:
		if r["team"] == team_id:
			break
		pos += 1
	var rec: Dictionary = Game.standings[team_id]
	cards.add_child(_card("%s Division" % team.division, "%s in the division\n%s, %d pts\nGoals %d-%d" % [
		Game.ordinal(pos), Game.record_string(team_id), rec["pts"], rec["gf"], rec["ga"]]))

	cards.add_child(_card("Salary cap", "Payroll %s\nCap space %s\nCap %s" % [
		Game.money(League.payroll(team_id)), Game.money(League.cap_space(team_id)),
		Game.money(League.finances.get("salary_cap", 0))]))

	# Inbox.
	add_child(UI.label("Inbox", 18))
	var scroll := ScrollContainer.new()
	UI.expand(scroll)
	add_child(scroll)
	var list := UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for m in Game.inbox.slice(0, 40):
		var panel := PanelContainer.new()
		var box := UI.vbox(4)
		panel.add_child(UI.margin(box, 10))
		box.add_child(UI.label("%s  -  %s" % [Game.short_date(int(m["day"])), m["title"]], 16))
		var body := UI.label(m["body"], 0, UI.MUTED)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)
		list.add_child(panel)


func _card(title: String, body: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 130)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(6)
	panel.add_child(UI.margin(box, 12))
	box.add_child(UI.label(title, 14, UI.MUTED))
	box.add_child(UI.label(body, 16))
	return panel
