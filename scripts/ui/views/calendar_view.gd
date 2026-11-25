class_name CalendarView
extends VBoxContainer
## Month calendar: your games (home/away, opponent, result), today highlighted.

var _year := 0
var _month := 0
var _grid: GridContainer
var _title: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var today := Game.date_of(Game.day)
	_year = int(today["year"])
	_month = int(today["month"])
	var top := UI.hbox(10)
	add_child(top)
	top.add_child(UI.button("<", func(): _shift(-1)))
	_title = UI.label("", 30, Color.WHITE)
	_title.custom_minimum_size = Vector2(260, 0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_title)
	top.add_child(UI.button(">", func(): _shift(1)))
	top.add_child(UI.spacer())
	top.add_child(UI.pill("Home", AppTheme.GREEN.darkened(0.2), UI.DARK_TEXT))
	top.add_child(UI.pill("Away", AppTheme.BLUE, UI.DARK_TEXT))
	top.add_child(UI.pill("Today", AppTheme.ACCENT, Color.WHITE))

	var head := GridContainer.new()
	head.columns = 7
	head.add_theme_constant_override("h_separation", 8)
	add_child(head)
	for wd in ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]:
		var l := UI.caption(wd)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(l)
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	UI.expand(_grid)
	add_child(_grid)
	_fill()


func _shift(delta: int) -> void:
	_month += delta
	if _month < 1:
		_month = 12
		_year -= 1
	elif _month > 12:
		_month = 1
		_year += 1
	_fill()


func _fill() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_title.text = "%s %d" % [["January", "February", "March", "April", "May", "June", "July", "August",
		"September", "October", "November", "December"][_month - 1].to_upper(), _year]
	var first := Game.day_index(_year, _month, 1)
	var lead: int = int(Game.date_of(first)["weekday"])
	for i in lead:
		_grid.add_child(Control.new())
	var games := Game.user_calendar()
	var d := first
	while int(Game.date_of(d)["month"]) == _month:
		_grid.add_child(_cell(d, games.get(d, {})))
		d += 1


func _cell(d: int, g: Dictionary) -> Control:
	var dt := Game.date_of(d)
	var today := d == Game.day
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 92)
	var bg := Color(1, 1, 1, 0.03)
	var border := Color(1, 1, 1, 0.05)
	if not g.is_empty():
		var home: bool = g["home"] == Game.user_team_id
		bg = Color(AppTheme.GREEN if home else AppTheme.BLUE, 0.10)
		border = Color(AppTheme.GREEN if home else AppTheme.BLUE, 0.45)
	if today:
		border = AppTheme.ACCENT
	b.add_theme_stylebox_override("normal", AppTheme.box(bg, 10, border, 2 if today else 1, 8, 6))
	b.add_theme_stylebox_override("hover", AppTheme.box(Color(1, 1, 1, 0.08), 10, border, 1, 8, 6))
	var col := UI.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_top = 6
	col.offset_right = -8
	b.add_child(col)
	col.add_child(UI.label(str(dt["day"]), 20, AppTheme.ACCENT if today else (Color.WHITE if d >= Game.day else AppTheme.MUTED)))
	if g.is_empty():
		return b
	var home: bool = g["home"] == Game.user_team_id
	var opp: String = g["away"] if home else g["home"]
	var row := UI.hbox(6)
	row.add_child(TeamCrest.make(opp, 24))
	var txt := UI.vbox(0)
	txt.add_child(UI.label("%s %s" % ["vs" if home else "@", League.get_team(opp).name], 13, Color.WHITE))
	if g.get("playoff", false):
		txt.add_child(UI.label("Playoffs", 11, AppTheme.GOLD))
	row.add_child(txt)
	col.add_child(row)
	if g["played"]:
		var mine: int = g["mine"]
		var theirs: int = g["theirs"]
		var code := "W" if mine > theirs else ("OTL" if g.get("ot", "") != "" else "L")
		col.add_child(UI.pill("%s %d-%d%s" % [code.substr(0, 1), mine, theirs, "" if g.get("ot", "") == "" else " " + g["ot"]],
			AppTheme.result_color(code), UI.DARK_TEXT, 12))
		b.pressed.connect(func(): Hub.go("Box Score", g["key"]))
	elif today:
		b.pressed.connect(func(): Hub.go("Match"))
	else:
		b.pressed.connect(func(): Hub.go("Club", opp))
	return b
