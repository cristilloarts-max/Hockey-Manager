class_name UI
extends RefCounted
## Small helpers for building UI in code.

const TIER_COLORS := {
	"Natural": Color(0.35, 0.85, 0.4),
	"Accomplished": Color(0.65, 0.9, 0.45),
	"Competent": Color(0.95, 0.85, 0.35),
	"Unconvincing": Color(0.98, 0.6, 0.25),
	"Awkward": Color(0.95, 0.3, 0.3),
}
const USER_COLOR := Color(0.55, 0.8, 1.0)
const MUTED := Color(0.65, 0.65, 0.7)


static func label(text: String, font_size: int = 0, color: Variant = null) -> Label:
	var l := Label.new()
	l.text = text
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if color != null:
		l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String) -> Label:
	return label(text, 22)


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
	return TIER_COLORS.get(tier, Color.WHITE)


static func hex(c: Color) -> String:
	return c.to_html(false)


static func team_name(id: String) -> String:
	var t = League.get_team(id)
	return t.full_name() if t != null else id


static func fmt_toi(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]
