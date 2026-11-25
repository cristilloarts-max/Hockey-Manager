class_name AppTheme
extends RefCounted
## The game's look: a dark navy base, a hot-pink action color, team colors
## for identity, and color scales that make good / average / bad readable at
## a glance (attributes, match ratings, morale, condition, results).

# ---- palette (deep slate with soft layers)
const BG := Color("#080c16")
const BG_2 := Color("#0c1220")
const PANEL := Color("#111a2b")
const PANEL_2 := Color("#172236")
const PANEL_3 := Color("#213049")
const BORDER := Color(1, 1, 1, 0.07)
const TEXT := Color("#e7ebf3")
const MUTED := Color("#8d97ab")
const FAINT := Color("#566178")
const ACCENT := Color("#ff3d71")       # Continue / primary actions
const ACCENT_2 := Color("#6c5cff")     # selected toggles, highlights
const GOLD := Color("#ffcb52")

# ---- fonts (Inter for text, Barlow Condensed for headings and numbers)
const FONT_DIR := "res://assets/fonts/"
static var _fonts := {}

# ---- scales
const RED := Color("#ff5a5f")
const ORANGE := Color("#ff9f45")
const YELLOW := Color("#ffd447")
const LIME := Color("#a6e35a")
const GREEN := Color("#2fe39a")
const BLUE := Color("#5ab0ff")

const RESULT_W := Color("#2fe39a")
const RESULT_L := Color("#ff5a5f")
const RESULT_OT := Color("#ffb347")


## Attribute 1-20: red (weak) -> orange -> yellow -> lime -> green (elite).
static func attr_color(v: int) -> Color:
	if v <= 5:
		return RED
	if v <= 9:
		return ORANGE
	if v <= 12:
		return YELLOW
	if v <= 15:
		return LIME
	return GREEN


## Match rating (about 5-10).
static func rating_color(r: float) -> Color:
	if r <= 0.0:
		return FAINT
	if r < 6.2:
		return RED
	if r < 6.6:
		return ORANGE
	if r < 7.0:
		return YELLOW
	if r < 7.5:
		return LIME
	return GREEN


static func morale_label(m: int) -> String:
	if m >= 85:
		return "Superb"
	if m >= 70:
		return "Very Good"
	if m >= 55:
		return "Good"
	if m >= 40:
		return "Okay"
	if m >= 25:
		return "Poor"
	return "Very Poor"


static func morale_color(m: int) -> Color:
	if m >= 85:
		return GREEN
	if m >= 70:
		return LIME
	if m >= 55:
		return YELLOW
	if m >= 40:
		return ORANGE
	return RED


static func condition_color(c: float) -> Color:
	if c >= 90:
		return GREEN
	if c >= 80:
		return LIME
	if c >= 70:
		return YELLOW
	if c >= 60:
		return ORANGE
	return RED


## Overall on the 74-99 scale.
static func ovr_color(ovr: int) -> Color:
	if ovr >= 92:
		return GREEN
	if ovr >= 86:
		return LIME
	if ovr >= 81:
		return YELLOW
	if ovr >= 77:
		return ORANGE
	return RED


static func result_color(code: String) -> Color:
	if code.begins_with("W"):
		return RESULT_W
	if code.begins_with("L"):
		return RESULT_L
	return RESULT_OT


static func tier_color(tier: String) -> Color:
	match tier:
		"Natural":
			return GREEN
		"Accomplished":
			return LIME
		"Competent":
			return YELLOW
		"Unconvincing":
			return ORANGE
	return RED


# ---- fonts

## "body", "medium", "semibold", "bold", "display", "display_bold" or "caption".
static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	match kind:
		"body":
			f = _load("inter", 400)
		"medium":
			f = _load("inter", 500)
		"semibold":
			f = _load("inter", 600)
		"bold":
			f = _load("inter", 700)
		"display":
			f = _load("barlow-condensed", 600)
		"display_bold":
			f = _load("barlow-condensed", 700)
		"caption":
			var v := FontVariation.new()
			v.base_font = font("semibold")
			v.spacing_glyph = 1
			f = v
		"menu":
			var v := FontVariation.new()
			v.base_font = font("display")
			v.spacing_glyph = 1
			f = v
		_:
			f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f


## Loads a bundled font with its latin-ext fallback (accented names).
## Falls back to Godot's default font if the files are missing.
static func _load(family: String, weight: int) -> Font:
	var path := "%s%s-latin-%d-normal.woff2" % [FONT_DIR, family, weight]
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var main := load(path) as FontFile
	if main == null:
		return ThemeDB.fallback_font
	var ext_path := "%s%s-latin-ext-%d-normal.woff2" % [FONT_DIR, family, weight]
	if ResourceLoader.exists(ext_path):
		var ext := load(ext_path) as FontFile
		if ext != null:
			main.fallbacks = [ext]
	return main


# ---- style boxes

static func box(bg: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		pad_h: int = 12, pad_v: int = 7) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.anti_aliasing = true
	s.corner_detail = 10
	return s


## A raised card: hairline border and a soft shadow.
static func card_box(bg: Color = PANEL, radius: int = 12, pad: int = 16) -> StyleBoxFlat:
	var s := box(bg, radius, BORDER, 1, pad, pad)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 3)
	return s


static func underline(color: Color, bg: Color = Color(0, 0, 0, 0), width: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = color
	s.border_width_bottom = width
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## A vertical gradient texture (backgrounds, glows).
static func gradient(top: Color, bottom: Color, radial: bool = false, horizontal: bool = false) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	if radial:
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
	elif horizontal:
		tex.fill_from = Vector2(0.0, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
	else:
		tex.fill_from = Vector2(0.5, 0.0)
		tex.fill_to = Vector2(0.5, 1.0)
	return tex


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 15

	# Text
	for cls in ["Label", "Button", "OptionButton", "CheckBox", "CheckButton", "LineEdit", "MenuButton"]:
		t.set_color("font_color", cls, TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font("body"))
	t.set_font("bold_font", "RichTextLabel", font("semibold"))
	t.set_constant("line_separation", "RichTextLabel", 4)
	t.set_constant("line_spacing", "Label", 2)

	# Panels
	t.set_stylebox("panel", "PanelContainer", card_box(PANEL, 12, 0))
	t.set_stylebox("panel", "Panel", card_box(PANEL, 12, 12))

	# Buttons
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_font("font", cls, font("medium"))
		t.set_font_size("font_size", cls, 14)
		t.set_stylebox("normal", cls, box(PANEL_2, 8, BORDER, 1, 14, 8))
		t.set_stylebox("hover", cls, box(PANEL_3, 8, Color(1, 1, 1, 0.12), 1, 14, 8))
		t.set_stylebox("pressed", cls, box(ACCENT_2, 8, ACCENT_2.lightened(0.2), 1, 14, 8))
		t.set_stylebox("hover_pressed", cls, box(ACCENT_2.lightened(0.08), 8, ACCENT_2.lightened(0.25), 1, 14, 8))
		t.set_stylebox("disabled", cls, box(BG_2, 8, BORDER, 1, 14, 8))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, FAINT)
	t.set_constant("h_separation", "Button", 8)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())

	# Tables
	t.set_font("font", "Tree", font("body"))
	t.set_font_size("font_size", "Tree", 14)
	t.set_font("title_button_font", "Tree", font("caption"))
	t.set_font_size("title_button_font_size", "Tree", 11)
	t.set_stylebox("panel", "Tree", box(BG_2, 12, BORDER, 1, 0, 4))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	var sel := box(Color(ACCENT_2, 0.22), 0, Color(0, 0, 0, 0), 0, 0, 0)
	sel.border_color = ACCENT_2
	sel.border_width_left = 3
	t.set_stylebox("selected", "Tree", sel)
	t.set_stylebox("selected_focus", "Tree", sel)
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	var head := box(PANEL, 0, Color(0, 0, 0, 0), 0, 10, 9)
	head.border_color = BORDER
	head.border_width_bottom = 1
	t.set_stylebox("title_button_normal", "Tree", head)
	var head_hover := head.duplicate() as StyleBoxFlat
	head_hover.bg_color = PANEL_2
	t.set_stylebox("title_button_hover", "Tree", head_hover)
	t.set_stylebox("title_button_pressed", "Tree", head_hover)
	t.set_color("title_button_color", "Tree", MUTED)
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.04))
	t.set_color("relationship_line_color", "Tree", Color(0, 0, 0, 0))
	t.set_constant("draw_guides", "Tree", 1)
	t.set_constant("draw_relationship_lines", "Tree", 0)
	t.set_constant("v_separation", "Tree", 10)
	t.set_constant("h_separation", "Tree", 8)
	t.set_constant("item_margin", "Tree", 0)
	t.set_constant("inner_item_margin_left", "Tree", 8)
	t.set_constant("inner_item_margin_right", "Tree", 8)

	# Tabs
	t.set_font("font", "TabContainer", font("semibold"))
	t.set_font_size("font_size", "TabContainer", 14)
	t.set_stylebox("panel", "TabContainer", card_box(PANEL, 12, 12))
	t.set_stylebox("tab_selected", "TabContainer", underline(ACCENT_2, Color(1, 1, 1, 0.04)))
	t.set_stylebox("tab_unselected", "TabContainer", underline(Color(0, 0, 0, 0)))
	t.set_stylebox("tab_hovered", "TabContainer", underline(PANEL_3))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)

	# Scrollbars: slim, appear as soft pills.
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, box(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, 2, 2))
		t.set_stylebox("grabber", cls, box(Color(1, 1, 1, 0.10), 4, Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber_highlight", cls, box(Color(1, 1, 1, 0.22), 4, Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber_pressed", cls, box(Color(1, 1, 1, 0.3), 4, Color(0, 0, 0, 0), 0, 3, 3))

	# Popups, dialogs, tooltips
	var pop := box(PANEL_2, 10, BORDER, 1, 8, 8)
	pop.shadow_color = Color(0, 0, 0, 0.5)
	pop.shadow_size = 14
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", box(ACCENT_2, 6, Color(0, 0, 0, 0), 0, 8, 4))
	t.set_font("font", "PopupMenu", font("medium"))
	t.set_font_size("font_size", "PopupMenu", 14)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_constant("v_separation", "PopupMenu", 10)
	t.set_stylebox("panel", "AcceptDialog", box(BG_2, 0, Color(0, 0, 0, 0), 0, 16, 16))
	var win := box(PANEL, 14, BORDER, 1, 0, 0)
	win.shadow_color = Color(0, 0, 0, 0.6)
	win.shadow_size = 24
	t.set_stylebox("embedded_border", "Window", win)
	t.set_stylebox("embedded_unfocused_border", "Window", win)
	t.set_font("title_font", "Window", font("display"))
	t.set_font_size("title_font_size", "Window", 18)
	t.set_color("title_color", "Window", TEXT)
	t.set_stylebox("panel", "TooltipPanel", box(PANEL_3, 8, BORDER, 1, 10, 7))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font("font", "TooltipLabel", font("body"))
	t.set_font_size("font_size", "TooltipLabel", 13)

	# Misc
	var sep := StyleBoxLine.new()
	sep.color = BORDER
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	var vsep := StyleBoxLine.new()
	vsep.color = BORDER
	vsep.thickness = 1
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)
	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.06), 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT_2, 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("normal", "LineEdit", box(BG_2, 8, BORDER, 1))
	t.set_stylebox("focus", "LineEdit", box(BG_2, 8, ACCENT_2, 1))
	return t
