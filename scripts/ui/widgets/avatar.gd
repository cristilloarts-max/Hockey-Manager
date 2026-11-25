class_name Avatar
extends Control
## A neutral player silhouette wearing his team's sweater (no real photos).

var primary := Color("#3a4a6b")
var secondary := Color.WHITE
var number := ""


static func make(team_id: String, num: Variant, px: int = 150) -> Avatar:
	var a := Avatar.new()
	var t = League.get_team(team_id)
	if t != null:
		a.primary = t.primary
		a.secondary = t.secondary
	a.number = "" if num == null else str(num)
	a.custom_minimum_size = Vector2(px, px)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


func _draw() -> void:
	var w := size.x
	var h := size.y
	var skin := Color("#3a465f")
	var shade := Color("#2c364b")
	# Shoulders / sweater.
	var body := PackedVector2Array()
	body.append(Vector2(w * 0.08, h))
	for i in 9:
		var a := PI + i * PI / 8.0
		body.append(Vector2(w * 0.5 + cos(a) * w * 0.42, h * 0.98 + sin(a) * h * 0.30))
	body.append(Vector2(w * 0.92, h))
	draw_colored_polygon(body, primary)
	# Sweater stripes and collar.
	draw_line(Vector2(w * 0.14, h * 0.88), Vector2(w * 0.86, h * 0.88), secondary, maxf(2.0, h * 0.035))
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.40, h * 0.70), Vector2(w * 0.60, h * 0.70),
		Vector2(w * 0.5, h * 0.80)]), secondary)
	# Neck and head.
	draw_rect(Rect2(w * 0.43, h * 0.56, w * 0.14, h * 0.16), shade)
	draw_circle(Vector2(w * 0.5, h * 0.40), w * 0.19, skin)
	draw_circle(Vector2(w * 0.5, h * 0.33), w * 0.17, Color("#1f2638"))  # hair
	draw_circle(Vector2(w * 0.5, h * 0.42), w * 0.16, skin)
	if number != "" and number != "0":
		var font := AppTheme.font("display_bold")
		var fs := int(h * 0.14)
		var col := Color(0.08, 0.08, 0.1) if primary.get_luminance() > 0.6 else Color.WHITE
		draw_string(font, Vector2(0, h * 0.99), number, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(col, 0.85))
