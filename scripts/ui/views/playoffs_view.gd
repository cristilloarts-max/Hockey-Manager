class_name PlayoffsView
extends VBoxContainer
## Playoff bracket (West on the left, East on the right, final in the middle).
## During the regular season it shows the current playoff picture.


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	if Game.phase == "regular":
		_picture()
		return
	var top := UI.hbox(10)
	add_child(top)
	top.add_child(UI.heading("Stanton Cup Playoffs"))
	top.add_child(UI.spacer())
	if Game.phase == "playoffs":
		top.add_child(UI.pill(Game.ROUND_NAMES[Game.playoffs["round"] - 1], AppTheme.ACCENT_2, Color.WHITE))
	if Game.phase == "done":
		add_child(_champion_banner(Game.playoffs["champion"]))

	var scroll := ScrollContainer.new()
	UI.expand(scroll)
	add_child(scroll)
	var bracket := UI.hbox(10)
	bracket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bracket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(bracket)
	bracket.add_child(_column("Western", 1, 4))
	bracket.add_child(_column("Western", 2, 2))
	bracket.add_child(_column("Western", 3, 1))
	bracket.add_child(_column("Final", 4, 1))
	bracket.add_child(_column("Eastern", 3, 1))
	bracket.add_child(_column("Eastern", 2, 2))
	bracket.add_child(_column("Eastern", 1, 4))

	var mine := Game.user_series()
	if not mine.is_empty():
		add_child(_my_games(mine))


func _column(conf: String, rnd: int, slots: int) -> Control:
	var col := UI.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(170, 0)
	var title := UI.caption(("%s - " % conf if conf != "Final" else "") + Game.ROUND_NAMES[rnd - 1])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var series := Game.series_in_round(rnd).filter(func(s): return s["conf"] == conf)
	for k in slots:
		var top := Control.new()
		top.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(top)
		var s: Dictionary = {}
		for x in series:
			if x["slot"] == k:
				s = x
		col.add_child(_series_card(s))
		var bottom := Control.new()
		bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(bottom)
	return col


func _series_card(s: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var mine: bool = not s.is_empty() and (s["high"] == Game.user_team_id or s["low"] == Game.user_team_id)
	var style := AppTheme.box(AppTheme.PANEL_2 if not s.is_empty() else AppTheme.PANEL, 8, AppTheme.ACCENT if mine else AppTheme.BORDER, 2 if mine else 1, 8, 6)
	panel.add_theme_stylebox_override("panel", style)
	var box := UI.vbox(4)
	panel.add_child(box)
	if s.is_empty():
		var tbd := UI.label("TBD", 13, AppTheme.FAINT)
		tbd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tbd)
		box.add_child(UI.label(" ", 13))
		return panel
	for side in [["high", "w_high"], ["low", "w_low"]]:
		var team_id: String = s[side[0]]
		var wins: int = s[side[1]]
		var lost: bool = s["winner"] != "" and s["winner"] != team_id
		var won: bool = s["winner"] == team_id
		var row := UI.hbox(6)
		row.modulate = Color(1, 1, 1, 0.45) if lost else Color.WHITE
		row.add_child(TeamCrest.make(team_id, 20))
		var link := Button.new()
		link.flat = true
		link.text = League.get_team(team_id).name
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link.add_theme_color_override("font_color", AppTheme.GREEN if won else (UI.USER_COLOR if team_id == Game.user_team_id else AppTheme.TEXT))
		link.pressed.connect(func(): Hub.go("Club", team_id))
		row.add_child(link)
		row.add_child(UI.label(str(wins), 18, AppTheme.GREEN if won else Color.WHITE))
		box.add_child(row)
	return panel


func _champion_banner(team_id: String) -> Control:
	var team := League.get_team(team_id)
	var panel := PanelContainer.new()
	var st := AppTheme.box(team.primary.darkened(0.3), 10, AppTheme.GOLD, 2, 20, 14)
	panel.add_theme_stylebox_override("panel", st)
	var row := UI.hbox(18)
	panel.add_child(row)
	row.add_child(Trophy.make(64, true))
	row.add_child(TeamCrest.make(team_id, 60))
	var txt := UI.vbox(2)
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	txt.add_child(UI.caption("Stanton Cup Champions", AppTheme.GOLD))
	txt.add_child(UI.label(team.full_name(), 30, Color.WHITE))
	var fin: String = Game.playoffs.get("finalist", "")
	if fin != "":
		txt.add_child(UI.label("Defeated the %s in the final" % League.get_team(fin).full_name(), 14, AppTheme.TEXT))
	row.add_child(txt)
	if team_id == Game.user_team_id:
		row.add_child(UI.spacer())
		row.add_child(UI.label("YOU WON IT ALL!", 26, AppTheme.GOLD))
	return panel


func _my_games(s: Dictionary) -> Control:
	var card := UI.card("Your series: %s  (%d-%d)" % [Game.ROUND_NAMES[s["round"] - 1],
		s["w_high"] if s["high"] == Game.user_team_id else s["w_low"],
		s["w_low"] if s["high"] == Game.user_team_id else s["w_high"]])
	var row := UI.hbox(8)
	UI.body(card).add_child(row)
	for idx in s["games"]:
		var g: Dictionary = Game.playoffs["games"][idx]
		var home: bool = g["home"] == Game.user_team_id
		var mine: int = g["hg"] if home else g["ag"]
		var theirs: int = g["ag"] if home else g["hg"]
		var code := "W" if mine > theirs else "L"
		var b := Button.new()
		b.text = "G%d  %s %d-%d%s" % [g["game"], code, mine, theirs, "" if g["ot"] == "" else " OT"]
		b.add_theme_stylebox_override("normal", AppTheme.box(Color(AppTheme.result_color(code), 0.25), 6))
		b.pressed.connect(func(): Hub.go("Box Score", "p%d" % idx))
		row.add_child(b)
	if s["games"].is_empty():
		row.add_child(UI.label("Game 1 is next.", 14, AppTheme.MUTED))
	return card


## Regular season: who's in right now.
func _picture() -> void:
	add_child(UI.heading("Playoff picture"))
	add_child(UI.label("If the season ended today. Top 3 in each division plus two wild cards per conference.", 13, AppTheme.MUTED))
	var spots := Game.playoff_teams()
	var row := UI.hbox(14)
	UI.expand(row)
	add_child(row)
	for conf in ["Western", "Eastern"]:
		var card := UI.card("%s Conference" % conf)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var list := UI.body(card)
		var n := 0
		for r in Game.standings_sorted(func(t): return t.conference == conf):
			n += 1
			var line := UI.hbox(8)
			var inside: bool = spots.has(r["team"])
			line.add_child(UI.pill(str(n), AppTheme.GREEN if inside else AppTheme.PANEL_3, UI.DARK_TEXT if inside else AppTheme.MUTED, 12))
			line.add_child(TeamCrest.make(r["team"], 20))
			var nm := UI.label(UI.team_name(r["team"]), 14, UI.USER_COLOR if r["team"] == Game.user_team_id else (AppTheme.TEXT if inside else AppTheme.MUTED))
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(nm)
			line.add_child(UI.label("%d pts" % r["pts"], 14, AppTheme.TEXT))
			list.add_child(line)
			if n == 8:
				list.add_child(HSeparator.new())
