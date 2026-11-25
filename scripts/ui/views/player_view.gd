class_name PlayerView
extends VBoxContainer
## Player profile: one screen, no scrolling.
##   Header   - silhouette, bio, scouting description, ability / potential, draft badge
##   Middle   - Technical / Mental / Physical attributes as segmented bars
##   Bottom   - positions and play styles, current team, contract, season history

var player_id := 0
var _p: Player
var _team: Team


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_p = League.get_player(player_id)
	if _p == null:
		add_child(UI.label("Player not found."))
		return
	_team = League.get_team(_p.team_id)
	add_child(_header())
	var attrs := _attributes()
	attrs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(attrs)
	add_child(_bottom())


# ------------------------------------------------------------------ header

func _header() -> Control:
	var p := _p
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 168)
	var style := AppTheme.card_box(AppTheme.PANEL, 14, 0)
	panel.add_theme_stylebox_override("panel", style)
	var wash := TextureRect.new()
	wash.texture = AppTheme.gradient(_team.primary.darkened(0.3), Color(AppTheme.PANEL, 0.0), false, true)
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(wash)

	var row := UI.hbox(22)
	panel.add_child(UI.margin(row, 14))
	var avatar := Avatar.make(p.team_id, p.number, 136)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(avatar)

	# Bio + description.
	var bio := UI.vbox(3)
	bio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bio)
	bio.add_child(UI.label("%s  -  #%d" % [p.full_name(), p.number], 34, Color.WHITE))
	var role: Dictionary = Roles.get_role(Game.role_of(p))
	bio.add_child(UI.label("%s (%s)  %s" % [Player.SPOT_NAMES.get(p.position, p.position), p.position, role.get("name", "")], 17, AppTheme.TEXT))
	var line1 := UI.hbox(18)
	line1.add_child(UI.pill(p.nationality, AppTheme.PANEL_3, AppTheme.TEXT, 13))
	line1.add_child(UI.label("%d years old (%s)" % [p.age, p.birth_date], 15))
	line1.add_child(UI.label("H: %s" % p.height_text(), 15, AppTheme.MUTED))
	line1.add_child(UI.label("W: %d lbs / %d kg" % [int(p.weight_kg * 2.2046), p.weight_kg], 15, AppTheme.MUTED))
	line1.add_child(UI.label("Shoots: %s" % ("Left" if p.shoots == "L" else "Right"), 15, AppTheme.MUTED))
	bio.add_child(line1)
	var desc := UI.label(_description(), 13, AppTheme.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(620, 0)
	bio.add_child(desc)

	# Ability, status and actions.
	var right := UI.vbox(8)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	var ab := GridContainer.new()
	ab.columns = 2
	ab.add_theme_constant_override("h_separation", 26)
	ab.add_theme_constant_override("v_separation", 4)
	ab.add_child(UI.label("Current Ability (%d)" % p.overall, 13, Color.WHITE))
	ab.add_child(UI.label("Potential Ability (%s)" % p.potential_range(), 13, Color.WHITE))
	ab.add_child(StarRating.make(p.ability_stars(), 22))
	ab.add_child(StarRating.make(p.potential_stars(), 22))
	right.add_child(ab)
	var status_row := UI.hbox(6)
	var status := Game.squad_status(p)
	status_row.add_child(UI.pill(status, RosterView._status_color(status)))
	var m := Game.morale_of(p.id)
	status_row.add_child(UI.pill("Morale: %s" % AppTheme.morale_label(m), AppTheme.morale_color(m)))
	var cond := Game.condition_of(p.id)
	status_row.add_child(UI.pill("%d%%" % int(cond), AppTheme.condition_color(cond)))
	right.add_child(status_row)
	right.add_child(_actions())

	row.add_child(_draft_badge())
	return panel


func _actions() -> Control:
	var p := _p
	var box := UI.hbox(6)
	var roster := League.roster(p.team_id)
	var idx := roster.find(p)
	box.add_child(UI.button("<", func(): Hub.go("Player", roster[(idx - 1 + roster.size()) % roster.size()].id)))
	box.add_child(UI.button(">", func(): Hub.go("Player", roster[(idx + 1) % roster.size()].id)))
	if p.team_id != Game.user_team_id:
		var tb := UI.button("Trade for him", func(): Hub.go("Trade Center", {"team": p.team_id, "player": p.id}))
		tb.disabled = not Game.trades_open()
		box.add_child(tb)
	else:
		var on_block: bool = Game.trading_block.has(str(p.id))
		box.add_child(UI.button("Off the block" if on_block else "Trading block", func():
			if Game.trading_block.has(str(p.id)):
				Game.trading_block.erase(str(p.id))
			else:
				Game.trading_block[str(p.id)] = true
			Hub.current.refresh()))
		box.add_child(UI.button("Send down" if p.on_nhl_roster() else "Call up", func():
			Game.set_roster_status(p.id, "Reserve" if p.on_nhl_roster() else "NHL")
			Hub.current.refresh_bar()
			Hub.current.refresh()))
	return box


func _draft_badge() -> Control:
	var p := _p
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 130)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := AppTheme.box(Color("#0f2a5c"), 12, AppTheme.GOLD, 2, 12, 10)
	st.skew = Vector2(-0.08, 0)
	panel.add_theme_stylebox_override("panel", st)
	var box := UI.vbox(0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var drafted: bool = not p.draft.is_empty() and p.draft.get("pick", 0) > 0
	var top := UI.label("DRAFT", 16, AppTheme.GOLD)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(top)
	var year := UI.label(("'%02d" % (int(p.draft["year"]) % 100)) if drafted else "FREE", 40, Color.WHITE)
	year.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(year)
	var sub := UI.label(("ROUND %d  -  #%d" % [p.draft["round"], p.draft["pick"]]) if drafted else "UNDRAFTED", 13, AppTheme.TEXT)
	sub.add_theme_font_override("font", AppTheme.font("caption"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	return panel


## A short scouting paragraph built from his ratings, age and role.
func _description() -> String:
	var p := _p
	var total := 0.0
	var n := 0
	for k in p.details:
		total += p.details[k]
		n += 1
	var avg := total / maxf(1, n)
	var now := "is fighting for a regular NHL spot"
	if p.overall >= 94:
		now = "is one of the very best players in the world"
	elif p.overall >= 89:
		now = "is a genuine star"
	elif p.overall >= 85:
		now = "is a top-line NHL player"
	elif p.overall >= 81:
		now = "is an established NHL regular"
	elif p.overall >= 77:
		now = "is a reliable depth player"
	if p.age <= 22 and p.overall >= 81:
		now = "is already " + now.trim_prefix("is ")
	var ceiling := "suggests a depth role at his peak"
	if p.age >= 30:
		ceiling = "he is at or just past his peak"
	elif p.potential >= 96:
		ceiling = "points to franchise-player potential and a shot at becoming one of the league's elite stars"
	elif p.potential >= 92:
		ceiling = "suggests future star potential"
	elif p.potential >= 88:
		ceiling = "suggests a future top-line player"
	elif p.potential >= 84:
		ceiling = "suggests a dependable top-nine future"
	var best := []
	var keys := p.details.keys()
	keys.sort_custom(func(a, b): return p.details[a] > p.details[b])
	for k in keys.slice(0, 2):
		best.append(Player.attr_label(k).to_lower())
	var role: Dictionary = Roles.get_role(Game.role_of(p))
	var tail := "while his %s potential %s." % [p.potential_range(), ceiling]
	if p.age >= 30:
		tail = "and at %d %s." % [p.age, ceiling]
	return "With an average attribute rating of %.1f, %s %s. His %d current ability makes him a natural %s built on %s and %s, %s" % [
		avg, p.full_name(), now, p.overall, role.get("name", "player").to_lower(), best[0] if best.size() > 0 else "skill",
		best[1] if best.size() > 1 else "smarts", tail]


# ------------------------------------------------------------------ attributes

func _attributes() -> Control:
	var card := UI.card("", 18)
	var cols := UI.hbox(44)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.body(card).add_child(cols)
	var keys: Dictionary = Roles.get_role(Game.role_of(_p)).get("keys", {})
	var groups := _p.detail_groups()
	for group in groups:
		var col := UI.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(group, 16, AppTheme.MUTED))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		col.add_child(gap)
		for k in groups[group]:
			col.add_child(_attr_row(k, keys.has(k)))
		cols.add_child(col)
	return card


func _attr_row(key: String, key_attr: bool) -> Control:
	var v := _p.detail(key)
	var col := AppTheme.attr_color(v)
	var row := UI.hbox(10)
	row.custom_minimum_size = Vector2(0, 30)
	var left := UI.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_l := UI.label(Player.attr_label(key), 13, Color.WHITE if key_attr else AppTheme.TEXT)
	name_l.add_theme_font_override("font", AppTheme.font("semibold" if key_attr else "medium"))
	if key_attr:
		name_l.tooltip_text = "Key attribute for his role"
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(name_l)
	left.add_child(SegmentBar.make(v, col, 7))
	row.add_child(left)
	var val := UI.label(str(v), 20, col)
	val.custom_minimum_size = Vector2(28, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(val)
	return row


# ------------------------------------------------------------------ bottom

func _bottom() -> Control:
	var row := UI.hbox(12)
	row.custom_minimum_size = Vector2(0, 136)
	row.add_child(_styles_card())
	row.add_child(_team_card())
	row.add_child(_contract_card())
	row.add_child(_history_card())
	return row


## Positions (mini rink) and play styles (roles with stars and familiarity).
func _styles_card() -> Control:
	var p := _p
	var card := UI.card("Positions & play styles", 12)
	card.custom_minimum_size = Vector2(500, 0)
	var row := UI.hbox(14)
	UI.body(card).add_child(row)
	var rink := Rink.new()
	rink.vertical = false
	rink.custom_minimum_size = Vector2(170, 96)
	rink.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if p.is_goalie():
		rink.dots = {"G": AppTheme.GREEN}
		rink.highlight_spot = "G"
	else:
		for spot in Player.SKATER_SPOTS:
			rink.dots[spot] = AppTheme.tier_color(p.familiarity_label(spot))
		rink.highlight_spot = p.position
	row.add_child(rink)
	var list := UI.vbox(2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(list)
	var current := Game.role_of(p)
	for key in Roles.ranked(p).slice(0, 4):
		var r := UI.hbox(8)
		r.add_child(StarRating.make(Roles.stars(p, key), 11))
		var fam := Game.role_familiarity(p, key)
		var name_l := UI.label(Roles.get_role(key)["name"], 13, Color.WHITE if key == current else AppTheme.TEXT)
		if key == current:
			name_l.add_theme_font_override("font", AppTheme.font("semibold"))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(name_l)
		r.add_child(UI.label(("PLAYING  " if key == current else "") + Game.role_familiarity_label(fam), 11,
			AppTheme.GREEN if fam >= 90 else (AppTheme.LIME if fam >= 70 else AppTheme.YELLOW)))
		list.add_child(r)
	if not p.is_goalie():
		list.add_child(UI.label("Change his role from Squad > Lines.", 11, AppTheme.FAINT))
	return card


func _team_card() -> Control:
	var card := UI.card("Current team", 12)
	card.custom_minimum_size = Vector2(150, 0)
	var crest := TeamCrest.make(_team.id, 58)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.body(card).add_child(crest)
	var nm := UI.label(_team.name, 15, Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.body(card).add_child(nm)
	var link := Button.new()
	link.flat = true
	link.text = "Club page"
	link.pressed.connect(func(): Hub.go("Club", _team.id))
	UI.body(card).add_child(link)
	return card


func _contract_card() -> Control:
	var c := _p.contract
	var card := UI.card("Current contract", 12)
	card.custom_minimum_size = Vector2(190, 0)
	UI.body(card).add_child(UI.label(Game.money(_p.team_cap_hit()), 34, Color.WHITE))
	UI.body(card).add_child(UI.label("%d year%s left  -  %s" % [c["years"], "" if c["years"] == 1 else "s", c["expiry_status"]], 13, AppTheme.MUTED))
	var tags := UI.hbox(4)
	if c["elc"]:
		tags.add_child(UI.pill("Entry-level", AppTheme.BLUE, UI.DARK_TEXT, 11))
	if c["no_trade_clause"]:
		tags.add_child(UI.pill("No-trade", AppTheme.ORANGE, UI.DARK_TEXT, 11))
	if int(c.get("retained", 0)) > 0:
		tags.add_child(UI.pill("Retained", AppTheme.PANEL_3, AppTheme.TEXT, 11))
	UI.body(card).add_child(tags)
	return card


## This season (from the game) plus his real previous seasons.
func _history_card() -> Control:
	var p := _p
	var card := UI.card("", 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 3)
	UI.body(card).add_child(grid)
	var rows := []
	var line := Game.player_line(p.id)
	if p.is_goalie():
		var head := ["Season", "Team", "GP", "W", "L", "OTL", "SV%", "GAA", "SO"]
		grid.columns = head.size()
		var sa: int = line.get("sa", 0)
		var ga: int = line.get("ga", 0)
		rows.append([League.season_label, _team.full_name(), line.get("gp", 0), line.get("w", 0), line.get("l", 0),
			line.get("otl", 0), "%.3f" % ((float(sa - ga) / sa) if sa > 0 else 0.0),
			"%.2f" % (ga * 3600.0 / maxf(1.0, float(line.get("toi", 0)))), line.get("so", 0)])
		for h in p.history:
			var hsa: int = h.get("sa", 0)
			var hga: int = h.get("ga", 0)
			rows.append([h["season"], h["team"], h["gp"], h.get("w", 0), h.get("l", 0), h.get("otl", 0),
				"%.3f" % ((float(hsa - hga) / hsa) if hsa > 0 else 0.0),
				"%.2f" % (float(hga) / maxf(1.0, h["gp"])), h.get("so", 0)])
		_grid_rows(grid, head, rows)
	else:
		var head := ["Season", "Team", "GP", "G", "A", "PTS", "PPG", "+/-", "PIM"]
		grid.columns = head.size()
		var gp: int = line.get("gp", 0)
		var pts: int = line.get("g", 0) + line.get("a", 0)
		rows.append([League.season_label, _team.full_name(), gp, line.get("g", 0), line.get("a", 0), pts,
			"%.2f" % (float(pts) / gp) if gp > 0 else "-", "%+d" % int(line.get("pm", 0)), line.get("pim", 0)])
		for h in p.history:
			var hp: int = int(h.get("g", 0)) + int(h.get("a", 0))
			rows.append([h["season"], "%s (%s)" % [h["team"], h["league"]] if h["league"] != "NHL" else h["team"],
				h["gp"], h.get("g", 0), h.get("a", 0), hp, "%.2f" % (float(hp) / maxf(1.0, h["gp"])),
				"%+d" % int(h.get("pm", 0)), h.get("pim", 0)])
		_grid_rows(grid, head, rows)
	return card


func _grid_rows(grid: GridContainer, head: Array, rows: Array) -> void:
	for h in head:
		var l := UI.label(h, 14, Color.WHITE)
		l.add_theme_font_override("font", AppTheme.font("display"))
		grid.add_child(l)
	for i in rows.size():
		for v in rows[i]:
			var l := UI.label(str(v), 14, AppTheme.TEXT if i > 0 else Color.WHITE)
			if i == 0:
				l.add_theme_font_override("font", AppTheme.font("semibold"))
			grid.add_child(l)
