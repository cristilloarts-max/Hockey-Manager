class_name PlayerWindow
extends AcceptDialog
## Player profile: bio, attributes, position familiarity, contract, season stats.

const SKATER_ATTRS := [["skating", "Skating"], ["shooting", "Shooting"], ["passing", "Passing"],
	["puck_handling", "Puck handling"], ["offense_iq", "Offensive IQ"], ["defense", "Defense"],
	["physical", "Physical"], ["endurance", "Endurance"], ["faceoffs", "Faceoffs"]]
const GOALIE_ATTRS := [["reflexes", "Reflexes"], ["positioning", "Positioning"],
	["rebound_control", "Rebound control"], ["glove", "Glove"], ["puck_handling", "Puck handling"],
	["consistency", "Consistency"], ["mental", "Mental"]]


static func open(parent: Node, pid: int) -> void:
	var p := League.get_player(pid)
	if p == null:
		return
	var w := PlayerWindow.new()
	w._build(p)
	parent.add_child(w)
	w.popup_centered(Vector2i(820, 600))


func _build(p: Player) -> void:
	title = "%s  #%d" % [p.full_name(), p.number]
	ok_button_text = "Close"
	var root := UI.hbox(24)
	add_child(root)

	# ---- left: bio, contract, stats
	var left := UI.vbox(6)
	left.custom_minimum_size = Vector2(340, 0)
	root.add_child(left)
	left.add_child(UI.label(p.full_name(), 24))
	left.add_child(UI.label("%s  |  %s  |  Shoots %s" % [UI.team_name(p.team_id), p.position, p.shoots], 0, UI.MUTED))
	left.add_child(UI.label("Age %d  |  %s  |  %d cm, %d kg" % [p.age, p.nationality, p.height_cm, p.weight_kg], 0, UI.MUTED))
	left.add_child(HSeparator.new())
	left.add_child(UI.label("Overall %d    Potential %s" % [p.overall, p.potential_range()], 20))
	left.add_child(HSeparator.new())
	var c := p.contract
	left.add_child(UI.label("Contract", 16))
	left.add_child(UI.label("%s per year, %d year%s left" % [Game.money(c["cap_hit"]), c["years"], "" if c["years"] == 1 else "s"]))
	var flags := []
	if c["elc"]:
		flags.append("Entry-level")
	flags.append("%s at expiry" % c["expiry_status"])
	if c["no_trade_clause"]:
		flags.append("No-trade clause")
	left.add_child(UI.label(", ".join(flags), 0, UI.MUTED))
	left.add_child(HSeparator.new())
	left.add_child(UI.label("This season", 16))
	var line := Game.player_line(p.id)
	if line.is_empty():
		left.add_child(UI.label("No games played", 0, UI.MUTED))
	elif p.is_goalie():
		var sa: int = line["sa"]
		left.add_child(UI.label("%d GP, %d-%d-%d, %.3f SV%%, %.2f GAA, %d SO" % [line["gp"], line["w"], line["l"], line["otl"],
			(float(sa - line["ga"]) / sa) if sa > 0 else 0.0, line["ga"] * 3600.0 / maxf(1.0, line["toi"]), line["so"]]))
	else:
		left.add_child(UI.label("%d GP, %d G, %d A, %d PTS, %+d, %d PIM" % [line["gp"], line["g"], line["a"], line["pts"], line["pm"], line["pim"]]))
		left.add_child(UI.label("%d shots, %s TOI per game, %d PPG" % [line["shots"], UI.fmt_toi(float(line["toi"]) / maxi(1, line["gp"])), line["ppg"]], 0, UI.MUTED))

	# ---- middle: attributes
	var mid := UI.vbox(4)
	mid.custom_minimum_size = Vector2(200, 0)
	root.add_child(mid)
	mid.add_child(UI.label("Attributes", 16))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	mid.add_child(grid)
	for a in (GOALIE_ATTRS if p.is_goalie() else SKATER_ATTRS):
		grid.add_child(UI.label(a[1]))
		var v := p.attr(a[0])
		var col := Color(0.95, 0.3, 0.3) if v <= 6 else (Color(0.95, 0.85, 0.35) if v <= 11 else (Color(0.65, 0.9, 0.45) if v <= 15 else Color(0.35, 0.85, 0.4)))
		grid.add_child(UI.label(str(v), 0, col))

	# ---- right: positions
	if not p.is_goalie():
		var right := UI.vbox(4)
		root.add_child(right)
		right.add_child(UI.label("Positions", 16))
		var side_txt := "Prefers his off side (one-timer threat)" if p.prefers_off_side else "Prefers his strong side (wall play, breakouts)"
		var side_lbl := UI.label(side_txt, 0, UI.MUTED)
		side_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side_lbl.custom_minimum_size = Vector2(220, 0)
		right.add_child(side_lbl)
		var pgrid := GridContainer.new()
		pgrid.columns = 3
		pgrid.add_theme_constant_override("h_separation", 12)
		right.add_child(pgrid)
		for spot in Player.SKATER_SPOTS:
			var tier := p.familiarity_label(spot)
			var name_txt: String = spot + (" *" if spot == p.position else "")
			pgrid.add_child(UI.label(name_txt))
			pgrid.add_child(UI.label(str(p.familiarity_at(spot))))
			pgrid.add_child(UI.label(tier, 0, UI.tier_color(tier)))
		right.add_child(UI.label("* preferred", 12, UI.MUTED))
