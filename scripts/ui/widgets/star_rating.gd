class_name StarRating
extends Control
## 0-5 stars in half steps.

var value := 0.0
var color := AppTheme.GOLD
var star_px := 14.0


static func make(stars: float, px: float = 14.0, col: Color = AppTheme.GOLD) -> StarRating:
	var s := StarRating.new()
	s.value = stars
	s.star_px = px
	s.color = col
	s.custom_minimum_size = Vector2(px * 5 + 8, px)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	for i in 5:
		var center := Vector2(i * (star_px + 2) + star_px / 2, star_px / 2)
		var pts := _star(center, star_px / 2, star_px / 4.6)
		draw_colored_polygon(pts, Color(AppTheme.FAINT, 0.45))
		var fill := clampf(value - i, 0.0, 1.0)
		if fill >= 1.0:
			draw_colored_polygon(pts, color)
		elif fill >= 0.5:
			# Left half of the star.
			var left := PackedVector2Array([center + Vector2(-star_px, -star_px), center + Vector2(0, -star_px),
				center + Vector2(0, star_px), center + Vector2(-star_px, star_px)])
			for poly in Geometry2D.intersect_polygons(pts, left):
				draw_colored_polygon(poly, color)


static func _star(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var r := r_out if k % 2 == 0 else r_in
		var a := -PI / 2 + k * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
