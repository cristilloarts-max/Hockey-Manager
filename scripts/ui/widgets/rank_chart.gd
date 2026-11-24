class_name RankChart
extends Control
## League position over the season (1st at the top). Green points mark days
## the team climbed, red the days it fell.

var ranks: Array = []
var teams_count := 32
var line_color := AppTheme.TEXT


func _draw() -> void:
	var font := get_theme_default_font()
	var left := 40.0
	var top := 10.0
	var w := size.x - left - 10
	var h := size.y - top - 24
	# Grid: 1st, 8th, 16th, 24th, 32nd.
	for r: int in [1, 8, 16, 24, 32]:
		var y := top + (r - 1) / float(teams_count - 1) * h
		draw_line(Vector2(left, y), Vector2(left + w, y), Color(AppTheme.BORDER, 0.8), 1.0)
		draw_string(font, Vector2(0, y + 5), Game.ordinal(r), HORIZONTAL_ALIGNMENT_RIGHT, left - 6, 12, AppTheme.MUTED)
	# Playoff line (roughly 16th in the league).
	var py := top + 15.5 / float(teams_count - 1) * h
	draw_dashed_line(Vector2(left, py), Vector2(left + w, py), Color(AppTheme.GREEN, 0.35), 1.0, 6.0)
	if ranks.size() < 2:
		draw_string(font, Vector2(left, top + h / 2), "Play some games to see the chart.", HORIZONTAL_ALIGNMENT_CENTER, w, 14, AppTheme.MUTED)
		return
	var pts := PackedVector2Array()
	for i in ranks.size():
		var x := left + i / float(ranks.size() - 1) * w
		var y := top + (int(ranks[i]) - 1) / float(teams_count - 1) * h
		pts.append(Vector2(x, y))
	draw_polyline(pts, line_color, 2.0, true)
	var step := maxi(1, ranks.size() / 30)
	for i in range(0, ranks.size(), step):
		var col := AppTheme.MUTED
		if i > 0:
			if int(ranks[i]) < int(ranks[i - step]):
				col = AppTheme.GREEN
			elif int(ranks[i]) > int(ranks[i - step]):
				col = AppTheme.RED
		draw_circle(pts[i], 3.0, col)
	draw_circle(pts[-1], 5.0, AppTheme.ACCENT)
	draw_string(font, Vector2(left, size.y - 4), "Season start", HORIZONTAL_ALIGNMENT_LEFT, 120, 12, AppTheme.MUTED)
	draw_string(font, Vector2(left + w - 120, size.y - 4), "Today", HORIZONTAL_ALIGNMENT_RIGHT, 120, 12, AppTheme.MUTED)
