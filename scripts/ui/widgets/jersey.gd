class_name Jersey
extends Control
## A hockey sweater in team colors with the player's number.

var primary := Color("#3a4a6b")
var secondary := Color.WHITE
var number := ""
var dimmed := false


static func make(team_id: String, num: Variant, px: int = 44) -> Jersey:
	var j := Jersey.new()
	var t = League.get_team(team_id)
	if t != null:
		j.primary = t.primary
		j.secondary = t.secondary
	j.number = "" if num == null or str(num) == "0" else str(num)
	j.custom_minimum_size = Vector2(px, px * 0.9)
	j.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return j


func _draw() -> void:
	var w := size.x
	var h := size.y
	var p := primary if not dimmed else primary.darkened(0.5)
	var s := secondary if not dimmed else secondary.darkened(0.5)
	# Body + sleeves.
	var body := PackedVector2Array([
		Vector2(w * 0.30, 0), Vector2(w * 0.70, 0),            # collar
		Vector2(w * 1.00, h * 0.20), Vector2(w * 0.94, h * 0.52), # right sleeve
		Vector2(w * 0.78, h * 0.46), Vector2(w * 0.80, h * 1.00),
		Vector2(w * 0.20, h * 1.00), Vector2(w * 0.22, h * 0.46),
		Vector2(w * 0.06, h * 0.52), Vector2(0, h * 0.20)])      # left sleeve
	draw_colored_polygon(body, p)
	# Sleeve and hem stripes.
	draw_line(Vector2(w * 0.05, h * 0.38), Vector2(w * 0.20, h * 0.33), s, maxf(2.0, h * 0.06))
	draw_line(Vector2(w * 0.95, h * 0.38), Vector2(w * 0.80, h * 0.33), s, maxf(2.0, h * 0.06))
	draw_line(Vector2(w * 0.21, h * 0.86), Vector2(w * 0.79, h * 0.86), s, maxf(2.0, h * 0.07))
	# Collar.
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.36, 0), Vector2(w * 0.64, 0), Vector2(w * 0.5, h * 0.14)]), s)
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0, 0, 0, 0.35), 1.0, true)
	if number != "":
		var font := get_theme_default_font()
		var fs := int(h * 0.42)
		var col := Color(0.08, 0.08, 0.1) if p.get_luminance() > 0.6 else Color.WHITE
		draw_string(font, Vector2(0, h * 0.70), number, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
