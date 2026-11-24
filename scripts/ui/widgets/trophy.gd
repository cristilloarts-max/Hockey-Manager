class_name Trophy
extends Control
## A drawn trophy: a cup for the big team prizes, a plaque-style trophy otherwise.

var color := AppTheme.GOLD
var cup := false


static func make(px: int = 48, is_cup: bool = false, col: Color = AppTheme.GOLD) -> Trophy:
	var t := Trophy.new()
	t.cup = is_cup
	t.color = col
	t.custom_minimum_size = Vector2(px, px * 1.15)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _draw() -> void:
	var w := size.x
	var h := size.y
	var dark := color.darkened(0.35)
	if cup:
		# Tall stacked cup.
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.18, h * 0.05), Vector2(w * 0.82, h * 0.05),
			Vector2(w * 0.70, h * 0.32), Vector2(w * 0.30, h * 0.32)]), color)
		draw_rect(Rect2(w * 0.42, h * 0.32, w * 0.16, h * 0.14), dark)
		for i in 4:
			var y := h * (0.46 + i * 0.12)
			var inset := w * (0.28 - i * 0.04)
			draw_rect(Rect2(inset, y, w - inset * 2, h * 0.11), color if i % 2 == 0 else dark)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.15, h * 0.05), Vector2(w * 0.85, h * 0.05),
			Vector2(w * 0.78, h * 0.35), Vector2(w * 0.6, h * 0.5), Vector2(w * 0.4, h * 0.5),
			Vector2(w * 0.22, h * 0.35)]), color)
		draw_arc(Vector2(w * 0.15, h * 0.2), w * 0.12, PI * 0.5, PI * 1.5, 12, color, 3.0, true)
		draw_arc(Vector2(w * 0.85, h * 0.2), w * 0.12, -PI * 0.5, PI * 0.5, 12, color, 3.0, true)
		draw_rect(Rect2(w * 0.44, h * 0.5, w * 0.12, h * 0.22), dark)
		draw_rect(Rect2(w * 0.22, h * 0.72, w * 0.56, h * 0.1), color)
		draw_rect(Rect2(w * 0.16, h * 0.82, w * 0.68, h * 0.14), dark)
	# Shine.
	draw_line(Vector2(w * 0.3, h * 0.1), Vector2(w * 0.36, h * 0.28), Color(1, 1, 1, 0.45), 2.0)
