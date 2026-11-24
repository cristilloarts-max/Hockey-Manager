class_name ClubView
extends ScrollContainer
## Club overview: identity card, league position chart, recent results,
## upcoming games and key personnel. Used for your team (Home) and for any
## opponent (shown in their colors).

var team_id := ""


func _ready() -> void:
	if team_id == "":
		team_id = Game.user_team_id
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var team := League.get_team(team_id)
	var page := UI.vbox(14)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(page)

	var cols := UI.hbox(14)
	page.add_child(cols)
	cols.add_child(_identity(team))

	var mid := UI.vbox(14)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var chart_card := UI.card("League position")
	var chart := RankChart.new()
	chart.ranks = Game.rank_history.get(team_id, [])
	chart.line_color = team.accent()
	chart.custom_minimum_size = Vector2(0, 230)
	UI.body(chart_card).add_child(chart)
	mid.add_child(chart_card)
	mid.add_child(_results(team))
	mid.add_child(_upcoming())

	cols.add_child(_personnel(team))

	if team_id == Game.user_team_id:
		page.add_child(_inbox_preview())
	else:
		page.add_child(_their_roster())


# ------------------------------------------------------------------ identity

func _identity(team: Team) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	panel.add_theme_stylebox_override("panel", AppTheme.box(AppTheme.PANEL, 10, Color(0, 0, 0, 0), 0, 0, 0))
	var col := UI.vbox(0)
	panel.add_child(col)

	# Color band with the crest.
	var band := PanelContainer.new()
	var bs := AppTheme.box(team.primary, 10, Color(0, 0, 0, 0), 0, 16, 18)
	bs.corner_radius_bottom_left = 0
	bs.corner_radius_bottom_right = 0
	bs.border_color = team.secondary
	bs.border_width_bottom = 4
	band.add_theme_stylebox_override("panel", bs)
	col.add_child(band)
	var bc := UI.vbox(6)
	band.add_child(bc)
	var crest := TeamCrest.make(team.id, 96)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bc.add_child(crest)
	var city := UI.label(team.city.to_upper(), 14, Color(team.on_primary(), 0.8))
	city.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bc.add_child(city)
	var nm := UI.label(team.name, 28, team.on_primary())
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bc.add_child(nm)

	var facts := UI.vbox(10)
	col.add_child(UI.margin(facts, 16))
	var rec: Dictionary = Game.standings[team.id]
	var league_rank := _rank(func(_t): return true)
	var div_rank := _rank(func(t): return t.division == team.division)
	var big := UI.hbox(10)
	facts.add_child(big)
	big.add_child(_stat_block(Game.ordinal(div_rank), "in %s" % team.division, _rank_color(div_rank, 8)))
	big.add_child(_stat_block(str(rec["pts"]), "points", Color.WHITE))
	big.add_child(_stat_block(Game.record_string(team.id), "W-L-OTL", Color.WHITE))
	facts.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	facts.add_child(grid)
	var roster := League.roster(team.id)
	var age_sum := 0.0
	for p in roster:
		age_sum += p.age
	var pp := _pp_pct(team.id)
	var rows := [
		["Conference", "%s  (%s overall)" % [team.conference, Game.ordinal(league_rank)]],
		["Goals", "%d for, %d against" % [rec["gf"], rec["ga"]]],
		["Streak", rec["streak"] if rec["streak"] != "" else "-"],
		["Power play", ("%.1f%%" % pp) if pp >= 0 else "-"],
		["Team strength", "%.1f" % League.team_strength(team.id)],
		["Average age", "%.1f" % (age_sum / maxf(1, roster.size()))],
		["Payroll", Game.money(League.payroll(team.id))],
		["Cap space", Game.money(League.cap_space(team.id))],
	]
	for r in rows:
		grid.add_child(UI.label(r[0], 13, AppTheme.MUTED))
		grid.add_child(UI.label(r[1], 14))
	if team.id != Game.user_team_id:
		facts.add_child(UI.button("Back to my club", func(): Hub.go("Overview")))
	return panel


func _stat_block(value: String, caption: String, color: Color) -> Control:
	var b := UI.vbox(0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.label(value, 24, color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(v)
	var c := UI.label(caption, 12, AppTheme.MUTED)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(c)
	return b


func _rank(filter: Callable) -> int:
	var i := 1
	for r in Game.standings_sorted(filter):
		if r["team"] == team_id:
			return i
		i += 1
	return i


func _rank_color(rank: int, of: int) -> Color:
	var f := float(rank - 1) / maxf(1.0, of - 1)
	if f <= 0.25:
		return AppTheme.GREEN
	if f <= 0.5:
		return AppTheme.LIME
	if f <= 0.75:
		return AppTheme.YELLOW
	return AppTheme.RED


func _pp_pct(id: String) -> float:
	var goals := 0
	var opps := 0
	for key in Game.box_scores:
		var res: Dictionary = Game.box_scores[key]
		for side in ["home", "away"]:
			if res[side] == id:
				goals += int(res[side + "_pp"][0])
				opps += int(res[side + "_pp"][1])
	return 100.0 * goals / opps if opps > 0 else -1.0


# ------------------------------------------------------------------ results

func _results(team: Team) -> Control:
	var card := UI.card("Recent results")
	var row := UI.hbox(10)
	UI.body(card).add_child(row)
	var played := []
	for i in Game.team_games(team.id):
		if Game.schedule[i]["played"]:
			played.append(i)
	if played.is_empty():
		row.add_child(UI.label("No games played yet.", 14, AppTheme.MUTED))
		return card
	for i in played.slice(maxi(0, played.size() - 8)):
		var g: Dictionary = Game.schedule[i]
		var home: bool = g["home"] == team.id
		var opp: String = g["away"] if home else g["home"]
		var mine: int = g["hg"] if home else g["ag"]
		var theirs: int = g["ag"] if home else g["hg"]
		var code := "W" if mine > theirs else ("OTL" if g.get("ot", "") != "" else "L")
		var tile := Button.new()
		tile.flat = true
		tile.custom_minimum_size = Vector2(78, 104)
		tile.tooltip_text = "%s %s - %s" % ["vs" if home else "@", UI.team_name(opp), Game.short_date(g["day"])]
		var col := UI.vbox(4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(col)
		var crest := TeamCrest.make(opp, 34)
		crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(crest)
		var ha := UI.label("%s %s" % ["vs" if home else "@", opp], 11, AppTheme.MUTED)
		ha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ha)
		var score := UI.pill("%d-%d" % [mine, theirs], AppTheme.result_color(code), UI.DARK_TEXT, 14)
		score.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(score)
		if Game.box_scores.has(str(i)):
			tile.pressed.connect(func(): BoxScoreWindow.open(self, i))
		row.add_child(tile)
	return card


func _upcoming() -> Control:
	var card := UI.card("Upcoming")
	var list := UI.vbox(6)
	UI.body(card).add_child(list)
	var shown := 0
	for i in Game.team_games(team_id):
		var g: Dictionary = Game.schedule[i]
		if g["played"]:
			continue
		var home: bool = g["home"] == team_id
		var opp: String = g["away"] if home else g["home"]
		var row := UI.hbox(10)
		var date := UI.label(Game.short_date(g["day"]), 14, AppTheme.MUTED)
		date.custom_minimum_size = Vector2(70, 0)
		row.add_child(date)
		row.add_child(UI.label("vs" if home else "@", 14, AppTheme.MUTED))
		var link := Button.new()
		link.flat = true
		link.text = UI.team_name(opp)
		link.pressed.connect(func(): Hub.go("Club", opp))
		row.add_child(TeamCrest.make(opp, 22))
		row.add_child(link)
		row.add_child(UI.spacer())
		row.add_child(UI.label(Game.record_string(opp), 14, AppTheme.MUTED))
		list.add_child(row)
		shown += 1
		if shown >= 4:
			break
	if shown == 0:
		list.add_child(UI.label("No games left this season.", 14, AppTheme.MUTED))
	return card


# ------------------------------------------------------------------ people

func _personnel(team: Team) -> Control:
	var card := UI.card("Key personnel")
	card.custom_minimum_size = Vector2(300, 0)
	var list := UI.body(card)
	var roster := League.roster(team.id)
	var skaters := roster.filter(func(p): return not p.is_goalie())
	var goalies := roster.filter(func(p): return p.is_goalie())
	var picks := []
	if not skaters.is_empty():
		var captain = skaters[0]
		for p in skaters:
			if p.detail("leadership") * 2 + p.overall / 10.0 > captain.detail("leadership") * 2 + captain.overall / 10.0:
				captain = p
		picks.append(["Captain", captain, "Leadership %d" % captain.detail("leadership")])
		picks.append(["Best player", roster[0], "Overall %d" % roster[0].overall])
		var scorer = null
		var best_pts := -1
		for p in skaters:
			var pts: int = Game.player_line(p.id).get("pts", 0)
			if pts > best_pts:
				best_pts = pts
				scorer = p
		if best_pts > 0:
			picks.append(["Top scorer", scorer, "%d points" % best_pts])
	if not goalies.is_empty():
		var lineup: Lineup = Game.lineups.get(team.id)
		var starter = League.get_player(lineup.goalies[0]) if lineup else goalies[0]
		if starter == null:
			starter = goalies[0]
		picks.append(["Starting goalie", starter, "Overall %d" % starter.overall])
	var young := roster.filter(func(p): return p.age <= 22)
	young.sort_custom(func(a, b): return a.potential > b.potential)
	if not young.is_empty():
		picks.append(["Hot prospect", young[0], "Age %d, potential %s" % [young[0].age, young[0].potential_range()]])

	for pk in picks:
		var p = pk[1]
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(0, 64)
		var row := UI.hbox(12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(row)
		var j := Jersey.make(team.id, p.number, 46)
		j.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(j)
		var txt := UI.vbox(0)
		txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		txt.add_child(UI.caption(pk[0], team.accent()))
		txt.add_child(UI.label(p.full_name(), 16, Color.WHITE))
		txt.add_child(UI.label(pk[2], 12, AppTheme.MUTED))
		row.add_child(txt)
		b.pressed.connect(func(): Hub.go("Player", p.id))
		list.add_child(b)
	return card


func _inbox_preview() -> Control:
	var card := UI.card("Inbox")
	var list := UI.body(card)
	for m in Game.inbox.slice(0, 4):
		list.add_child(InboxView.message_row(m))
	var more := UI.button("Open inbox", func(): Hub.go("Inbox"))
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	list.add_child(more)
	return card


func _their_roster() -> Control:
	var card := UI.card("Roster")
	card.custom_minimum_size = Vector2(0, 520)
	var table := RosterView.make_table(team_id)
	UI.body(card).add_child(table)
	return card
