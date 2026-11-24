class_name AppTheme
extends RefCounted
## The game's look: a dark navy base, a hot-pink action color, team colors
## for identity, and color scales that make good / average / bad readable at
## a glance (attributes, match ratings, morale, condition, results).

# ---- palette
const BG := Color("#0b1120")
const BG_2 := Color("#0f1729")
const PANEL := Color("#141d33")
const PANEL_2 := Color("#1a2540")
const PANEL_3 := Color("#22305a")
const BORDER := Color("#26324f")
const TEXT := Color("#e8edf7")
const MUTED := Color("#8a96b2")
const FAINT := Color("#55617d")
const ACCENT := Color("#e8336d")       # Continue / primary actions
const ACCENT_2 := Color("#7c4dff")     # selected toggles, highlights
const GOLD := Color("#ffc94a")

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


static func ovr_color(ovr: int) -> Color:
	return attr_color(int(round((ovr - 40) / 3.0)))


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


# ---- style boxes

static func box(bg: Color, radius: int = 6, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		pad_h: int = 10, pad_v: int = 6) -> StyleBoxFlat:
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
	return s


static func underline(color: Color, bg: Color = Color(0, 0, 0, 0), width: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = color
	s.border_width_bottom = width
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15

	# Text
	for cls in ["Label", "Button", "OptionButton", "CheckBox", "CheckButton", "LineEdit", "MenuButton"]:
		t.set_color("font_color", cls, TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)

	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 8, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("panel", "Panel", box(PANEL, 8))

	# Buttons
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, box(PANEL_2, 6))
		t.set_stylebox("hover", cls, box(PANEL_3, 6))
		t.set_stylebox("pressed", cls, box(ACCENT_2, 6))
		t.set_stylebox("hover_pressed", cls, box(ACCENT_2.lightened(0.1), 6))
		t.set_stylebox("disabled", cls, box(BG_2, 6))
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, FAINT)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())

	# Tables
	t.set_stylebox("panel", "Tree", box(BG_2, 8, BORDER, 1, 0, 0))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", box(Color("#2c3f78"), 0))
	t.set_stylebox("selected_focus", "Tree", box(Color("#33498a"), 0))
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("title_button_normal", "Tree", box(PANEL, 0, Color(0, 0, 0, 0), 0, 8, 7))
	t.set_stylebox("title_button_hover", "Tree", box(PANEL_2, 0, Color(0, 0, 0, 0), 0, 8, 7))
	t.set_stylebox("title_button_pressed", "Tree", box(PANEL_3, 0, Color(0, 0, 0, 0), 0, 8, 7))
	t.set_color("title_button_color", "Tree", MUTED)
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_color("guide_color", "Tree", Color(0, 0, 0, 0))
	t.set_color("relationship_line_color", "Tree", Color(0, 0, 0, 0))
	t.set_constant("draw_guides", "Tree", 0)
	t.set_constant("draw_relationship_lines", "Tree", 0)
	t.set_constant("v_separation", "Tree", 8)
	t.set_constant("h_separation", "Tree", 6)
	t.set_constant("item_margin", "Tree", 0)
	t.set_font_size("title_button_font_size", "Tree", 13)

	# Tabs
	t.set_stylebox("panel", "TabContainer", box(PANEL, 8))
	t.set_stylebox("tab_selected", "TabContainer", underline(ACCENT_2, PANEL_2))
	t.set_stylebox("tab_unselected", "TabContainer", underline(Color(0, 0, 0, 0)))
	t.set_stylebox("tab_hovered", "TabContainer", underline(PANEL_3))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)

	# Scrollbars
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, box(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber", cls, box(PANEL_3, 4))
		t.set_stylebox("grabber_highlight", cls, box(FAINT, 4))
		t.set_stylebox("grabber_pressed", cls, box(MUTED, 4))

	# Popups, dialogs, tooltips
	t.set_stylebox("panel", "PopupMenu", box(PANEL_2, 6, BORDER, 1, 6, 6))
	t.set_stylebox("hover", "PopupMenu", box(ACCENT_2, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_stylebox("panel", "AcceptDialog", box(BG_2, 0, Color(0, 0, 0, 0), 0, 12, 12))
	t.set_stylebox("embedded_border", "Window", box(PANEL, 8, BORDER, 1, 0, 0))
	t.set_color("title_color", "Window", TEXT)
	t.set_stylebox("panel", "TooltipPanel", box(PANEL_2, 6, BORDER, 1, 8, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)

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
	t.set_stylebox("background", "ProgressBar", box(BG_2, 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT_2, 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("normal", "LineEdit", box(BG_2, 6, BORDER, 1))
	t.set_stylebox("focus", "LineEdit", box(BG_2, 6, ACCENT_2, 1))
	return t
