class_name SegmentBar
extends Control
## A 1-20 rating as a row of segments: filled ones in the rating's color.

var value := 0
var segments := 20
var color := AppTheme.GREEN


static func make(v: int, col: Color, height: int = 7) -> SegmentBar:
	var b := SegmentBar.new()
	b.value = v
	b.color = col
	b.custom_minimum_size = Vector2(60, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _draw() -> void:
	var gap := 2.0
	var w := (size.x - gap * (segments - 1)) / segments
	for i in segments:
		var r := Rect2(i * (w + gap), 0, w, size.y)
		draw_rect(r, color if i < value else Color(1, 1, 1, 0.07))
