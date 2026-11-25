class_name MatchView
extends VBoxContainer
## Game day. Pre-game -> live replay with a running clock (score, shots and
## play-by-play update as it goes) -> intermissions between periods ->
## final breakdown. The game is simulated when you press Play; the screen
## then plays it back period by period.

## Game seconds per real second: 1x shows a period in about five minutes.
## Game seconds per real second. 1x is slow enough to follow every pass
## (a 20-minute period takes about 10 minutes).
const SPEEDS := [["1x", 2.0], ["2x", 4.0], ["4x", 8.0], ["8x", 16.0]]
const PERIOD_NAMES := ["1ST", "2ND", "3RD", "OT", "2OT", "3OT", "4OT", "5OT"]

var _res: Dictionary = {}
var _game: Dictionary = {}         ## today's game info before it's played
var _state := "pre"                ## pre, live, paused, intermission, final
var _t := 0.0                      ## game clock in seconds since puck drop
var _speed := 2.0
var _hold := 0.0                   ## real seconds to freeze (after goals)
var _viz: RinkVisualizer
var _chor: Choreographer
var _caption: Label
var _goal_card: HBoxContainer
var _ev := 0                       ## next event index
var _events: Array = []
var _period_ends: Array = []
var _period_idx := 0
var _score := [0, 0]
var _shots := [0, 0]
var _feed_lines: Array = []
var _reg_ot := false              ## regular-season 5-minute overtime (and maybe a shootout)

var _clock_label: Label
var _period_label: Label
var _score_labels: Array = []
var _shot_labels: Array = []
var _feed: RichTextLabel
var _flash: Label
var _flash_time := 0.0
var _controls: HBoxContainer
var _body: Control
var _play_btn: Button


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_game = Game.user_game_today()
	if _game.is_empty():
		_no_game()
		return
	_pre_game()


# ------------------------------------------------------------------ pre-game

func _no_game() -> void:
	add_child(UI.heading("No game today"))
	add_child(UI.label("Your next game is on the calendar above. Continue moves one day at a time.", 15, AppTheme.MUTED))
	var b := UI.button("Continue to the next day", func():
		Game.advance_day()
		Hub.current.refresh_bar()
		Hub.go("Overview"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(b)


func _pre_game() -> void:
	var home: String = _game["home"]
	var away: String = _game["away"]
	var label: String = _game.get("label", "")
	add_child(UI.caption("Game day  -  %s%s" % [Game.date_string(), ("  -  " + label) if label != "" else ""]))
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 0)
	card.custom_minimum_size = Vector2(0, 220)
	add_child(card)
	card.add_child(_team_block(away, false, "AWAY"))
	var mid := UI.vbox(8)
	mid.custom_minimum_size = Vector2(220, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var at := UI.label("@", 56, AppTheme.MUTED)
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(at)
	card.add_child(mid)
	card.add_child(_team_block(home, true, "HOME"))

	var tips := UI.card("Before puck drop", 16)
	add_child(tips)
	var tb := UI.body(tips)
	var mine: Lineup = Game.lineups[Game.user_team_id]
	var g1 := League.get_player(mine.goalies[0])
	tb.add_child(UI.label("Your starter: %s.  Line 1: %s" % [g1.full_name() if g1 else "-", _line_text(mine.forwards[0])], 14))
	var row := UI.hbox(10)
	tb.add_child(row)
	row.add_child(UI.button("Edit lines", func(): Hub.go("Lines")))
	row.add_child(UI.button("Tactics", func(): Hub.go("Tactics")))
	row.add_child(UI.spacer())
	var quick := UI.button("Quick result", func(): _start(true))
	quick.tooltip_text = "Skip the replay and go straight to the final."
	row.add_child(quick)
	var play := Button.new()
	play.text = "PLAY GAME"
	play.custom_minimum_size = Vector2(240, 54)
	play.add_theme_font_override("font", AppTheme.font("menu"))
	play.add_theme_font_size_override("font_size", 24)
	var st := AppTheme.box(AppTheme.ACCENT, 12, Color(0, 0, 0, 0), 0, 20, 10)
	st.shadow_color = Color(AppTheme.ACCENT, 0.4)
	st.shadow_size = 14
	play.add_theme_stylebox_override("normal", st)
	play.add_theme_stylebox_override("hover", AppTheme.box(AppTheme.ACCENT.lightened(0.1), 12, Color(0, 0, 0, 0), 0, 20, 10))
	play.pressed.connect(func(): _start(false))
	row.add_child(play)


func _line_text(line: Array) -> String:
	var names := []
	for pid in line:
		var p := League.get_player(pid)
		names.append(p.last_name if p else "-")
	return " - ".join(names)


func _team_block(id: String, home: bool, tag: String) -> Control:
	var team := League.get_team(id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := AppTheme.card_box(team.primary.darkened(0.25), 14, 20)
	panel.add_theme_stylebox_override("panel", st)
	var col := UI.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var c := TeamCrest.make(id, 84)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(c)
	var t := UI.label(tag, 12, Color(team.on_primary(), 0.7))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var nm := UI.label(team.full_name(), 28, team.on_primary())
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(nm)
	var rec := UI.label("%s  -  %s" % [Game.record_string(id), TradeAI.strategy_label(id).split(" -")[0]], 14, Color(team.on_primary(), 0.8))
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rec)
	return panel


# ------------------------------------------------------------------ start

func _start(quick: bool) -> void:
	var problems := Game.roster_problems(Game.user_team_id)
	if not problems.is_empty():
		var d := AcceptDialog.new()
		d.title = "Fix your roster first"
		d.dialog_text = "\n".join(problems)
		add_child(d)
		d.popup_centered()
		return
	var keys := Game.advance_day()
	Hub.current.refresh_bar()
	if keys.is_empty() or not Game.box_scores.has(keys[-1]):
		Hub.go("Overview")
		return
	_res = Game.box_scores[keys[-1]]
	_events = _res["events"].duplicate()
	_events.sort_custom(func(a, b): return float(a.get("t", 0)) < float(b.get("t", 0)))
	_period_ends = _compute_period_ends()
	_chor = Choreographer.new()
	_chor.build(_res, _period_ends)
	for c in get_children():
		c.queue_free()
	# Set the state first so the speed/pause row is built for live play.
	_state = "live"
	_build_live()
	if quick:
		_skip_to_final()


## When each period ends (seconds since puck drop).
func _compute_period_ends() -> Array:
	var n: int = _res["periods"].size()
	var playoff := false
	for e in _events:
		if str(e.get("period", "")).begins_with("OT") and str(e.get("period", "")).length() > 2:
			playoff = true
	var last_goal := 0.0
	var last_event := 0.0
	for e in _events:
		last_event = maxf(last_event, float(e.get("t", 0)))
		if e["type"] == "goal":
			last_goal = maxf(last_goal, float(e.get("t", 0)))
	_reg_ot = not playoff and n >= 4
	var ends := []
	for p in range(1, n + 1):
		if p <= 3:
			ends.append(p * 1200.0)
		elif _reg_ot:
			# 5-minute overtime; a shootout plays out right after it.
			ends.append(last_event + 0.5 if _res["ot"] == "SO" else maxf(last_goal, 3600.0))
		else:
			ends.append(last_goal if p == n else p * 1200.0)
	return ends


# ------------------------------------------------------------------ live layout

func _build_live() -> void:
	var home: String = _res["home"]
	var away: String = _res["away"]
	# Scoreboard.
	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", 0)
	board.custom_minimum_size = Vector2(0, 110)
	add_child(board)
	board.add_child(_score_block(away, 0, true))
	var mid := PanelContainer.new()
	mid.custom_minimum_size = Vector2(200, 0)
	mid.add_theme_stylebox_override("panel", AppTheme.box(Color("#05080f"), 0, Color(0, 0, 0, 0), 0, 10, 8))
	var mc := UI.vbox(0)
	mc.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(mc)
	_period_label = UI.label("1ST", 18, AppTheme.GOLD)
	_period_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mc.add_child(_period_label)
	_clock_label = UI.label("20:00", 44, Color.WHITE)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mc.add_child(_clock_label)
	board.add_child(mid)
	board.add_child(_score_block(home, 1, false))

	_flash = UI.label("", 30, Color.WHITE)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.custom_minimum_size = Vector2(0, 36)
	add_child(_flash)

	_body = UI.hbox(12)
	UI.expand(_body)
	add_child(_body)
	# The rink, with an EDGE-style event bar underneath.
	var rink_col := UI.vbox(8)
	rink_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rink_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(rink_col)
	var rink_card := PanelContainer.new()
	rink_card.add_theme_stylebox_override("panel", AppTheme.card_box(Color("#e9edf2"), 14, 6))
	UI.expand(rink_card)
	rink_col.add_child(rink_card)
	_viz = RinkVisualizer.new()
	_viz.setup(_chor, _res["home"], _res["away"])
	UI.expand(_viz)
	rink_card.add_child(_viz)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", AppTheme.card_box(AppTheme.PANEL, 12, 10))
	rink_col.add_child(bar)
	var bar_row := UI.hbox(14)
	bar.add_child(bar_row)
	_caption = UI.label("Puck drop", 16, Color.WHITE)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.clip_text = true
	bar_row.add_child(_caption)
	_goal_card = UI.hbox(10)
	bar_row.add_child(_goal_card)

	var feed_card := UI.card("Play-by-play", 14)
	feed_card.custom_minimum_size = Vector2(340, 0)
	feed_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(feed_card)
	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	_feed.scroll_active = true
	UI.expand(_feed)
	UI.body(feed_card).add_child(_feed)

	_controls = UI.hbox(10)
	add_child(_controls)
	_build_controls()


func _score_block(id: String, idx: int, left: bool) -> Control:
	var team := League.get_team(id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := AppTheme.box(team.primary.darkened(0.2), 14, Color(0, 0, 0, 0), 0, 18, 10)
	if left:
		st.corner_radius_top_right = 0
		st.corner_radius_bottom_right = 0
	else:
		st.corner_radius_top_left = 0
		st.corner_radius_bottom_left = 0
	panel.add_theme_stylebox_override("panel", st)
	var row := UI.hbox(16)
	panel.add_child(row)
	var crest := TeamCrest.make(id, 60)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := UI.label(team.full_name(), 22, team.on_primary())
	var sog := UI.label("SOG 0", 14, Color(team.on_primary(), 0.75))
	info.add_child(nm)
	info.add_child(sog)
	var score := UI.label("0", 64, team.on_primary())
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if left:
		row.add_child(crest)
		row.add_child(info)
		row.add_child(score)
	else:
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(score)
		row.add_child(info)
		row.add_child(crest)
	if _score_labels.size() < 2:
		_score_labels.resize(2)
		_shot_labels.resize(2)
	_score_labels[idx] = score
	_shot_labels[idx] = sog
	return panel


func _build_controls() -> void:
	for c in _controls.get_children():
		c.queue_free()
	match _state:
		"live", "paused":
			_play_btn = UI.button("Pause" if _state == "live" else "Play", func():
				_state = "paused" if _state == "live" else "live"
				_build_controls())
			_play_btn.custom_minimum_size = Vector2(110, 40)
			_play_btn.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.ACCENT if _state == "paused" else AppTheme.PANEL_2, 10, AppTheme.BORDER, 1, 14, 8))
			_controls.add_child(_play_btn)
			_controls.add_child(UI.label("Speed", 13, AppTheme.MUTED))
			var group := ButtonGroup.new()
			for sp in SPEEDS:
				var b := Button.new()
				b.text = sp[0]
				b.toggle_mode = true
				b.button_group = group
				b.button_pressed = absf(_speed - float(sp[1])) < 0.1
				b.pressed.connect(func(): _speed = sp[1])
				_controls.add_child(b)
			_controls.add_child(UI.spacer())
			_controls.add_child(UI.button("Skip to end of period", _skip_period))
			_controls.add_child(UI.button("Skip to final", _skip_to_final))
		"intermission":
			var n := _period_idx
			var card := UI.card("", 14)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var row := UI.hbox(16)
			UI.body(card).add_child(row)
			row.add_child(UI.label("END OF %s PERIOD" % PERIOD_NAMES[n - 1], 26, AppTheme.GOLD))
			row.add_child(UI.label("%s %d  -  %s %d     Shots %d - %d" % [_res["away"], _score[0], _res["home"], _score[1],
				_shots[0], _shots[1]], 18, Color.WHITE))
			row.add_child(UI.spacer())
			var go := UI.button("Start %s period" % PERIOD_NAMES[n].to_lower() if n < 3 else "Start overtime", func():
				_state = "live"
				_build_controls())
			go.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.ACCENT, 10, Color(0, 0, 0, 0), 0, 16, 8))
			row.add_child(go)
			row.add_child(UI.button("Skip to final", _skip_to_final))
			_controls.add_child(card)
		"final":
			_controls.add_child(UI.spacer())
			var done := UI.button("Finish", func(): Hub.go("Overview"))
			done.custom_minimum_size = Vector2(200, 44)
			done.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.ACCENT, 10, Color(0, 0, 0, 0), 0, 16, 8))
			_controls.add_child(done)


# ------------------------------------------------------------------ playback

func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.text = ""
	if _state != "live":
		return
	if _hold > 0.0:
		_hold -= delta
		if _viz:
			_viz.update(_t, 0.0)
		return
	var step := delta * _speed
	_t += step
	_advance_to(_t)
	if _viz and _state != "final":
		_viz.update(_t, step)
		var st := _chor.state_at(_t)
		var label: String = st.get("label", "")
		if label != "":
			_caption.text = label
		if _viz.note != "" and _t < _viz.note_until and not _caption.text.ends_with(_viz.note):
			_caption.text = (label + "     |     " if label != "" else "") + _viz.note


func _advance_to(t: float) -> void:
	while _ev < _events.size() and float(_events[_ev].get("t", 0)) <= t:
		_apply(_events[_ev])
		_ev += 1
	if _period_idx < _period_ends.size() and t >= _period_ends[_period_idx]:
		_t = _period_ends[_period_idx]
		_period_idx += 1
		if _period_idx >= _period_ends.size():
			_finish()
			return
		_state = "intermission"
		_update_clock()
		_build_controls()
		return
	_update_clock()


func _update_clock() -> void:
	var p := mini(_period_idx, _period_ends.size() - 1)
	var start := 0.0 if p == 0 else float(_period_ends[p - 1])
	var length := 300.0 if (p == 3 and _reg_ot) else 1200.0
	var left := maxf(0.0, start + length - _t)
	_clock_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	_period_label.text = PERIOD_NAMES[mini(p, PERIOD_NAMES.size() - 1)] + (" PERIOD" if p < 3 else "")


func _apply(e: Dictionary) -> void:
	var side := 0 if e["team"] == _res["away"] else 1
	match e["type"]:
		"shift":
			return
		"shot":
			_shots[side] += 1
			_shot_labels[side].text = "SOG %d" % _shots[side]
			return
		"goal":
			var sc: Array = e.get("score", [0, 0])
			_score = [int(sc[1]), int(sc[0])]   # events store [home, away]
			_score_labels[0].text = str(_score[0])
			_score_labels[1].text = str(_score[1])
			var team := League.get_team(e["team"])
			_flash.text = "GOAL!  %s" % team.full_name().to_upper()
			_flash.add_theme_color_override("font_color", team.accent())
			_flash_time = 2.5
			_hold = 2.2
			_show_goal_card(e)
	var color := "#b8c2d8"
	match e["type"]:
		"goal":
			color = "#" + (AppTheme.RESULT_W if e["team"] == Game.user_team_id else AppTheme.RESULT_L).to_html(false)
		"penalty":
			color = "#ffd27f"
		"end":
			color = "#8fb8ff"
		"save":
			color = "#8a96b2"
	var tag := ""
	if e["team"] != "":
		tag = "[color=#%s][b]%s[/b][/color]  " % [League.get_team(e["team"]).accent().to_html(false), e["team"]]
	var stamp: String = e["period"] + (" " + e["time"] if e["time"] != "" else "")
	var text: String = e["text"]
	if e["type"] == "goal":
		text = "[b]%s[/b]" % text
	_feed_lines.push_front("[color=#55617d]%s[/color]   %s[color=%s]%s[/color]" % [stamp, tag, color, text])
	_feed.text = "\n".join(_feed_lines)


## EDGE-style goal card: scorer, assists, score, time, shot type.
func _show_goal_card(e: Dictionary) -> void:
	if _goal_card == null:
		return
	for c in _goal_card.get_children():
		c.queue_free()
	var scorer := League.get_player(int(e.get("pid", 0)))
	var team := League.get_team(e["team"])
	var num := UI.pill(str(scorer.number) if scorer else "", team.primary, team.on_primary(), 14)
	_goal_card.add_child(num)
	var who := UI.vbox(0)
	var goals: int = Game.player_line(scorer.id).get("g", 0) if scorer else 0
	who.add_child(UI.label("%s (%d)%s" % [scorer.full_name() if scorer else "?", goals,
		"  PPG" if e.get("pp", false) else ("  SHG" if e.get("sh", false) else "")], 15, Color.WHITE))
	var helpers := []
	for aid in e.get("assists", []):
		var ap := League.get_player(int(aid))
		if ap:
			helpers.append(ap.short_name())
	who.add_child(UI.label(", ".join(helpers) if not helpers.is_empty() else "Unassisted", 12, AppTheme.MUTED))
	_goal_card.add_child(who)
	var sc: Array = e.get("score", [0, 0])
	for box in [["%d-%d" % [int(sc[1]), int(sc[0])], "Score"], ["%s (%s)" % [e["time"], e["period"]], "Time"],
			[str(e.get("shot", "Shot")).capitalize(), "Shot"]]:
		var b := UI.vbox(0)
		b.add_child(UI.label(box[0], 15, Color.WHITE))
		b.add_child(UI.caption(box[1]))
		_goal_card.add_child(b)


func _skip_period() -> void:
	if _period_idx < _period_ends.size():
		_advance_to(_period_ends[_period_idx])
		if _viz and _state != "final":
			_viz.update(_t, 10.0)


func _skip_to_final() -> void:
	_t = 99999.0
	while _ev < _events.size():
		_apply(_events[_ev])
		_ev += 1
	_period_idx = _period_ends.size()
	_finish()


func _finish() -> void:
	_state = "final"
	_score = [int(_res["away_goals"]), int(_res["home_goals"])]
	_score_labels[0].text = str(_score[0])
	_score_labels[1].text = str(_score[1])
	_shot_labels[0].text = "SOG %d" % int(_res["away_shots"])
	_shot_labels[1].text = "SOG %d" % int(_res["home_shots"])
	_clock_label.text = "FINAL"
	_period_label.text = _res["ot"] if _res["ot"] != "" else "GAME OVER"
	var won: bool = (_res["home"] == Game.user_team_id) == (int(_res["home_goals"]) > int(_res["away_goals"]))
	_flash.text = "WIN!" if won else "LOSS"
	_flash.add_theme_color_override("font_color", AppTheme.RESULT_W if won else AppTheme.RESULT_L)
	_flash_time = 0.0
	# Breakdown replaces the live feed.
	for c in _body.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.expand(scroll)
	var content := BoxScoreView.build_content(_res, false)
	scroll.add_child(content)
	_body.add_child(scroll)
	_body.add_child(_around_league())
	_build_controls()


## Other scores from the same day.
func _around_league() -> Control:
	var card := UI.card("Around the league", 14)
	card.custom_minimum_size = Vector2(300, 0)
	var list := UI.body(card)
	var game_day := Game.day - 1
	var rows := []
	if Game.phase == "regular" or not Game.playoffs.has("games"):
		for g in Game.schedule:
			if g["day"] == game_day and g["played"]:
				rows.append(g)
	else:
		for g in Game.playoffs.get("games", []):
			if g["day"] == game_day:
				rows.append(g)
		for g in Game.schedule:
			if g["day"] == game_day and g["played"]:
				rows.append(g)
	for g in rows:
		if g["home"] == Game.user_team_id or g["away"] == Game.user_team_id:
			continue
		var r := UI.hbox(6)
		r.add_child(TeamCrest.make(g["away"], 18))
		r.add_child(UI.label("%s %d" % [g["away"], g["ag"]], 14, Color.WHITE if g["ag"] > g["hg"] else AppTheme.MUTED))
		r.add_child(UI.label("@", 12, AppTheme.FAINT))
		r.add_child(TeamCrest.make(g["home"], 18))
		r.add_child(UI.label("%s %d" % [g["home"], g["hg"]], 14, Color.WHITE if g["hg"] > g["ag"] else AppTheme.MUTED))
		if g.get("ot", "") != "":
			r.add_child(UI.label(g["ot"], 12, AppTheme.ORANGE))
		list.add_child(r)
	if list.get_child_count() <= 1:
		list.add_child(UI.label("No other games today.", 13, AppTheme.MUTED))
	return card
