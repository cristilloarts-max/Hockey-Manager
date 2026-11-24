class_name TeamCrest
extends Control
## A shield in the team's colors with its abbreviation (no real logos).

var team_id := ""


static func make(id: String, px: int = 40) -> TeamCrest:
	var c := TeamCrest.new()
	c.team_id = id
	c.custom_minimum_size = Vector2(px, px * 1.15)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _draw() -> void:
	var t = League.get_team(team_id)
	if t == null:
		return
	var w := size.x
	var h := size.y
	var outer := _shield(Vector2.ZERO, w, h)
	draw_colored_polygon(outer, t.secondary)
	var inset := maxf(2.0, w * 0.07)
	var inner := _shield(Vector2(inset, inset), w - inset * 2, h - inset * 2)
	draw_colored_polygon(inner, t.primary)
	# Diagonal sash in the secondary color.
	var sash := PackedVector2Array([
		Vector2(inset, h * 0.52), Vector2(w - inset, h * 0.30),
		Vector2(w - inset, h * 0.40), Vector2(inset, h * 0.62)])
	draw_colored_polygon(sash, Color(t.secondary, 0.35))
	var font := get_theme_default_font()
	var fs := int(w * 0.30)
	var text_pos := Vector2(0, h * 0.50 + fs * 0.35)
	draw_string(font, text_pos + Vector2(1, 1), team_id, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0, 0, 0, 0.5))
	draw_string(font, text_pos, team_id, HORIZONTAL_ALIGNMENT_CENTER, w, fs, t.on_primary())


static func _shield(o: Vector2, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(o + Vector2(0, 0))
	pts.append(o + Vector2(w, 0))
	pts.append(o + Vector2(w, h * 0.55))
	# Curved bottom to the point.
	for i in range(1, 8):
		var f := i / 8.0
		pts.append(o + Vector2(w - w * 0.5 * f, h * 0.55 + h * 0.45 * sin(f * PI / 2)))
	pts.append(o + Vector2(w * 0.5, h))
	for i in range(7, 0, -1):
		var f := i / 8.0
		pts.append(o + Vector2(w * 0.5 * f, h * 0.55 + h * 0.45 * sin(f * PI / 2)))
	pts.append(o + Vector2(0, h * 0.55))
	return pts
