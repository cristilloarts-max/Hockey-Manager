class_name UI
extends RefCounted
## Small helpers for building UI in code.

const USER_COLOR := Color("#7cc4ff")
const MUTED := AppTheme.MUTED
const DARK_TEXT := Color("#0b1120")


static func label(text: String, font_size: int = 0, color: Variant = null) -> Label:
	var l := Label.new()
	l.text = text
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	# Big text (names, numbers, headings) uses the condensed display face.
	if font_size >= 20:
		l.add_theme_font_override("font", AppTheme.font("display_bold" if font_size >= 26 else "display"))
	elif font_size >= 16:
		l.add_theme_font_override("font", AppTheme.font("medium"))
	if color != null:
		l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String) -> Label:
	return label(text.to_upper(), 30, Color.WHITE)


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	return b


static func hbox(separation: int = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func vbox(separation: int = 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func margin(child: Control, m: int = 12) -> MarginContainer:
	var c := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		c.add_theme_constant_override("margin_" + side, m)
	c.add_child(child)
	return c


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func rich(bbcode: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = bbcode
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


static func tier_color(tier: String) -> Color:
	return AppTheme.tier_color(tier)


## Small uppercase heading used above panels ("TECHNICAL", "FORM"...).
static func caption(text: String, color: Color = AppTheme.MUTED) -> Label:
	var l := label(text.to_upper(), 11, color)
	l.add_theme_font_override("font", AppTheme.font("caption"))
	return l


## A rounded panel with a vertical body. Add content to card.get_meta("body").
static func card(title: String = "", pad: int = 14, bg: Color = AppTheme.PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", AppTheme.card_box(bg, 12, pad))
	var content := vbox(10)
	panel.add_child(content)
	if title != "":
		content.add_child(caption(title))
	panel.set_meta("body", content)
	return panel


static func body(card_panel: PanelContainer) -> VBoxContainer:
	return card_panel.get_meta("body")


## A colored rounded tag ("Key Player", "W", "Inj").
static func pill(text: String, bg: Color, fg: Color = DARK_TEXT, font_size: int = 13) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", AppTheme.box(bg, 99, Color(0, 0, 0, 0), 0, 10, 3))
	var l := label(text, font_size, fg)
	if font_size < 20:
		l.add_theme_font_override("font", AppTheme.font("semibold"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## A thin colored bar for 0-100 values (condition, morale).
static func meter(value: float, color: Color, width: int = 80, height: int = 8) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 100
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, height)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", AppTheme.box(color, 3, Color(0, 0, 0, 0), 0, 0, 0))
	b.add_theme_stylebox_override("background", AppTheme.box(AppTheme.BG, 3, Color(0, 0, 0, 0), 0, 0, 0))
	return b


## Crest + team name in a row.
static func team_chip(team_id: String, crest_px: int = 22, font_size: int = 15) -> HBoxContainer:
	var row := hbox(8)
	var crest := TeamCrest.make(team_id, crest_px)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	var l := label(team_name(team_id), font_size)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func hex(c: Color) -> String:
	return c.to_html(false)


static func team_name(id: String) -> String:
	var t = League.get_team(id)
	return t.full_name() if t != null else id


static func fmt_toi(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]
