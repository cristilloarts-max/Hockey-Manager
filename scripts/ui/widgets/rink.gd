class_name Rink
extends Control
## A stylised dark rink. Vertical rinks attack upward (lineup screen);
## horizontal ones attack to the right (player profile). Optional dots show a
## player's familiarity at each position.

## Where each position stands on a vertical rink (0..1 coordinates).
const SPOTS := {
	"LW": Vector2(0.22, 0.27), "C": Vector2(0.50, 0.22), "RW": Vector2(0.78, 0.27),
	"LD": Vector2(0.30, 0.58), "RD": Vector2(0.70, 0.58), "G": Vector2(0.50, 0.86),
}
const ICE := Color("#122039")
const BOARDS := Color("#3a4b72")
const RED_LINE := Color("#d04a55")
const BLUE_LINE := Color("#3f7dff")
const CREASE := Color("#2b5ea8")

var vertical := true
## spot -> Color: draws a dot per spot (profile mini-rink).
var dots: Dictionary = {}
var highlight_spot := ""


## Point for a spot in this control's local coordinates.
func spot_point(spot: String) -> Vector2:
	var v: Vector2 = SPOTS.get(spot, Vector2(0.5, 0.5))
	if vertical:
		return Vector2(v.x * size.x, v.y * size.y)
	return Vector2((1.0 - v.y) * size.x, v.x * size.y)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var rink := AppTheme.box(ICE, int(minf(w, h) * 0.18), BOARDS, 3, 0, 0)
	draw_style_box(rink, Rect2(Vector2.ZERO, size))
	# Lines: along the attacking axis, fractions of its length.
	_cross_line(0.5, RED_LINE, 3.0)
	_cross_line(0.36, BLUE_LINE, 4.0)
	_cross_line(0.64, BLUE_LINE, 4.0)
	_cross_line(0.07, Color(RED_LINE, 0.7), 1.5)
	_cross_line(0.93, Color(RED_LINE, 0.7), 1.5)
	var short := minf(w, h)
	# Center circle + faceoff circles.
	draw_arc(_pt(0.5, 0.5), short * 0.15, 0, TAU, 48, Color(BLUE_LINE, 0.7), 1.5, true)
	for along in [0.2, 0.8]:
		for across in [0.28, 0.72]:
			draw_arc(_pt(across, along), short * 0.13, 0, TAU, 40, Color(RED_LINE, 0.55), 1.5, true)
			draw_circle(_pt(across, along), 2.5, Color(RED_LINE, 0.8))
	# Creases.
	for along in [0.07, 0.93]:
		var c := _pt(0.5, along)
		draw_circle(c, short * 0.07, Color(CREASE, 0.55))
	# Familiarity dots.
	for spot in dots:
		var p := spot_point(spot)
		var r := short * (0.075 if spot == highlight_spot else 0.055)
		draw_circle(p, r + 2, Color(0, 0, 0, 0.45))
		draw_circle(p, r, dots[spot])
		if spot == highlight_spot:
			draw_arc(p, r + 4, 0, TAU, 32, Color.WHITE, 2.0, true)
		var font := get_theme_default_font()
		var fs := int(short * 0.07)
		draw_string(font, p + Vector2(-30, r + fs + 4), spot, HORIZONTAL_ALIGNMENT_CENTER, 60, fs, AppTheme.MUTED)


## Point at `across` (0 = left wing side) and `along` (0 = attacking end).
func _pt(across: float, along: float) -> Vector2:
	if vertical:
		return Vector2(across * size.x, along * size.y)
	return Vector2((1.0 - along) * size.x, across * size.y)


func _cross_line(along: float, color: Color, width: float) -> void:
	var inset := minf(size.x, size.y) * 0.03
	if vertical:
		draw_line(Vector2(inset, along * size.y), Vector2(size.x - inset, along * size.y), color, width)
	else:
		draw_line(Vector2((1.0 - along) * size.x, inset), Vector2((1.0 - along) * size.x, size.y - inset), color, width)
