class_name DataTable
extends Tree
## A sortable table. Click a column title to sort; double-click a row to open it.
##
## setup([["Name", 0], ["Age", 50], ...])   width 0 = stretch
## set_rows([{"id": 123, "cells": ["Connur McDevid", 29], "keys": [...], "color": Color}])
##   "keys" (optional) are the values used for sorting when the display text differs,
##   e.g. "$9.20M" displayed but 9200000 sorted.
##   Optional per row: "cell_colors" {col: Color} (text), "cell_bg" {col: Color}
##   (cell background: rating tiles, team swatches), "bg" Color (whole row).

signal row_activated(id)
signal row_selected(id)

var _rows: Array = []
var _sort_col := -1
var _sort_desc := true
var row_height := 30
## Columns whose text is drawn dark (they get a bright background tile).
var dark_text_on_bg := true


func _init() -> void:
	hide_root = true
	column_titles_visible = true
	select_mode = Tree.SELECT_ROW
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(200, 160)
	item_activated.connect(_on_item_activated)
	item_selected.connect(_on_item_selected)
	column_title_clicked.connect(_on_column_title_clicked)


func setup(headers: Array) -> void:
	columns = headers.size()
	for i in headers.size():
		var h = headers[i]
		var title: String = h if typeof(h) == TYPE_STRING else h[0]
		var width: int = 0 if typeof(h) == TYPE_STRING else int(h[1])
		set_column_title(i, title)
		set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
		if width > 0:
			set_column_expand(i, false)
			set_column_custom_minimum_width(i, width)
		else:
			set_column_expand(i, true)


func set_rows(rows: Array) -> void:
	_rows = rows
	_render()


func sort_by(col: int, descending: bool = true) -> void:
	_sort_col = col
	_sort_desc = descending
	_render()


func _key(row: Dictionary, col: int) -> Variant:
	if row.has("keys"):
		return row["keys"][col]
	return row["cells"][col]


func _less(a: Variant, b: Variant) -> bool:
	var na := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var nb := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if na and nb:
		return float(a) < float(b)
	if na != nb:
		return na   # numbers before text
	return str(a).naturalnocasecmp_to(str(b)) < 0


func _render() -> void:
	clear()
	var root := create_item()
	var ordered := _rows.duplicate()
	if _sort_col >= 0 and _sort_col < columns:
		var c := _sort_col
		var desc := _sort_desc
		ordered.sort_custom(func(a, b):
			if desc:
				return _less(_key(b, c), _key(a, c))
			return _less(_key(a, c), _key(b, c)))
	var n := 0
	for r in ordered:
		var item := create_item(root)
		item.custom_minimum_height = row_height
		var cells: Array = r["cells"]
		var row_bg: Color = r.get("bg", Color(1, 1, 1, 0.025) if n % 2 == 1 else Color(0, 0, 0, 0))
		for i in mini(cells.size(), columns):
			var v = cells[i]
			item.set_text(i, str(v))
			if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
				item.set_text_alignment(i, HORIZONTAL_ALIGNMENT_CENTER)
			if r.has("color"):
				item.set_custom_color(i, r["color"])
			if row_bg.a > 0:
				item.set_custom_bg_color(i, row_bg)
		if r.has("cell_colors"):
			for col in r["cell_colors"]:
				item.set_custom_color(int(col), r["cell_colors"][col])
		if r.has("cell_bg"):
			for col in r["cell_bg"]:
				var c: int = int(col)
				item.set_custom_bg_color(c, r["cell_bg"][col])
				item.set_text_alignment(c, HORIZONTAL_ALIGNMENT_CENTER)
				if dark_text_on_bg and not (r.has("cell_colors") and r["cell_colors"].has(col)):
					item.set_custom_color(c, Color("#0b1120"))
		item.set_metadata(0, r.get("id"))
		n += 1


func _on_column_title_clicked(column: int, _mouse_button: int) -> void:
	if column == _sort_col:
		_sort_desc = not _sort_desc
	else:
		_sort_col = column
		_sort_desc = true
	_render()


func _on_item_activated() -> void:
	var item := get_selected()
	if item != null:
		row_activated.emit(item.get_metadata(0))


func _on_item_selected() -> void:
	var item := get_selected()
	if item != null:
		row_selected.emit(item.get_metadata(0))
