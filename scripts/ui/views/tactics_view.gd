class_name TacticsView
extends VBoxContainer
## Built from Tactics.GROUPS: a mentality bar on top, then a card per area.

## Settings the current sim already uses (the rest are stored for phase 6).
const WIRED := ["forecheck.system", "forecheck.intensity", "d_zone.collapse", "d_zone.blocking",
	"o_zone.shot_selection", "power_play.threat", "power_play.movement", "power_play.usage",
	"penalty_kill.pressure", "game.mentality", "game.physicality", "game.discipline",
	"situations.protect_lead", "situations.pull_goalie_1", "situations.pull_goalie_2"]
const MENTALITY_COLORS := ["#3d7bff", "#3fa0ff", "#4cc3d9", "#8a96b2", "#ffb347", "#ff7a45", "#ff4d5e"]

var _tac: Tactics
var _pickers := {}
var _mentality_buttons := []


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_tac = Game.tactics[Game.user_team_id]

	var top := UI.hbox(10)
	add_child(top)
	top.add_child(UI.heading("Tactics"))
	top.add_child(UI.spacer())
	top.add_child(UI.pill("Affects games now", AppTheme.GREEN))
	top.add_child(UI.pill("Saved for later phases", AppTheme.PANEL_3, AppTheme.MUTED))
	top.add_child(UI.button("Reset to defaults", _reset))

	# Mentality strip.
	var ment_card := UI.card("Mentality")
	add_child(ment_card)
	var strip := UI.hbox(4)
	UI.body(ment_card).add_child(strip)
	var opts: Array = _setting("game", "mentality")["options"]
	for i in opts.size():
		var b := Button.new()
		b.text = opts[i]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		var col := Color.html(MENTALITY_COLORS[i])
		b.add_theme_stylebox_override("normal", AppTheme.box(Color(col, 0.18), 4))
		b.add_theme_stylebox_override("hover", AppTheme.box(Color(col, 0.35), 4))
		b.add_theme_stylebox_override("pressed", AppTheme.box(col, 4))
		b.add_theme_stylebox_override("hover_pressed", AppTheme.box(col, 4))
		b.add_theme_color_override("font_pressed_color", UI.DARK_TEXT)
		b.add_theme_color_override("font_hover_pressed_color", UI.DARK_TEXT)
		b.pressed.connect(func():
			_tac.set_value("game.mentality", i)
			_sync_mentality())
		strip.add_child(b)
		_mentality_buttons.append(b)
	_sync_mentality()

	# Area cards.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.expand(scroll)
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for g in Tactics.GROUPS:
		var card := UI.card(g["label"])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var body := UI.body(card)
		for s in g["settings"]:
			var key := "%s.%s" % [g["key"], s["key"]]
			if key == "game.mentality":
				continue
			var row := UI.hbox(8)
			var dot := UI.label("•", 11, AppTheme.GREEN if key in WIRED else AppTheme.FAINT)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			var lbl := UI.label(s["label"], 14, AppTheme.TEXT if key in WIRED else AppTheme.MUTED)
			lbl.custom_minimum_size = Vector2(150, 0)
			lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(lbl)
			var opt := OptionButton.new()
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for o in s["options"]:
				opt.add_item(o)
			opt.select(_tac.get_value(key))
			opt.item_selected.connect(func(i): _tac.set_value(key, i))
			_pickers[key] = opt
			row.add_child(opt)
			body.add_child(row)
		grid.add_child(card)


func _setting(group_key: String, setting_key: String) -> Dictionary:
	for g in Tactics.GROUPS:
		if g["key"] == group_key:
			for s in g["settings"]:
				if s["key"] == setting_key:
					return s
	return {}


func _sync_mentality() -> void:
	var v := _tac.get_value("game.mentality")
	for i in _mentality_buttons.size():
		_mentality_buttons[i].button_pressed = i == v


func _reset() -> void:
	_tac.reset()
	for k in _pickers:
		_pickers[k].select(_tac.get_value(k))
	_sync_mentality()
