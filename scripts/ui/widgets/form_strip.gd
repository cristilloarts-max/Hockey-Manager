class_name FormStrip
extends HBoxContainer
## The last five match ratings as colored tiles (grey = no game yet).


static func make(ratings: Array, tile: int = 30) -> FormStrip:
	var f := FormStrip.new()
	f.add_theme_constant_override("separation", 4)
	for i in 5:
		var idx := ratings.size() - 5 + i
		var r: float = float(ratings[idx]) if idx >= 0 else 0.0
		var panel := PanelContainer.new()
		var bg := AppTheme.rating_color(r) if r > 0 else AppTheme.PANEL_3
		panel.add_theme_stylebox_override("panel", AppTheme.box(bg, 4, Color(0, 0, 0, 0), 0, 0, 0))
		panel.custom_minimum_size = Vector2(tile, tile)
		var l := Label.new()
		l.text = ("%.1f" % r) if r > 0 else ""
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(tile * 0.38))
		l.add_theme_color_override("font_color", Color(0.06, 0.08, 0.12))
		panel.add_child(l)
		f.add_child(panel)
	return f
