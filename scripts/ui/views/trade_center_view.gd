class_name TradeCenterView
extends VBoxContainer
## Build a trade: pick a partner, double-click assets on either side to add
## them, watch the AI's reaction live, then propose.

var arg: Variant = null          ## optional {"team": id, "player": pid, "trade": {...}}
var _partner := ""
var _give: Array = []            ## your assets
var _get: Array = []             ## their assets
var _retain := {}                ## pid (String) -> pct
var _mine: DataTable
var _theirs: DataTable
var _summary: VBoxContainer
var _partner_pill_box: HBoxContainer
var _their_title: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var teams := League.team_list().filter(func(t): return t.id != Game.user_team_id)
	_partner = teams[0].id
	if typeof(arg) == TYPE_DICTIONARY:
		if arg.has("trade"):
			var t: Dictionary = arg["trade"]
			_partner = t["b"]
			_give = t["a_gives"].duplicate(true)
			_get = t["b_gives"].duplicate(true)
			_retain = t.get("retain", {}).duplicate()
		elif arg.has("team"):
			_partner = arg["team"]
			if arg.has("player"):
				_get.append({"type": "player", "id": int(arg["player"])})

	# Header.
	var top := UI.hbox(10)
	add_child(top)
	top.add_child(UI.heading("Trade Center"))
	if Game.trades_open():
		var left := Game.days_to_deadline()
		top.add_child(UI.pill("Deadline: %s (%s)" % [Game.short_date(Game.DEADLINE_DAY),
			"today" if left == 0 else "%d days" % left], AppTheme.ORANGE if left <= 7 else AppTheme.PANEL_3,
			UI.DARK_TEXT if left <= 7 else AppTheme.TEXT))
	else:
		top.add_child(UI.pill("Trading closed until the offseason", AppTheme.RED))
	top.add_child(UI.spacer())
	top.add_child(UI.label("Trade with", 14, AppTheme.MUTED))
	var pick := OptionButton.new()
	for i in teams.size():
		pick.add_item(teams[i].full_name())
		if teams[i].id == _partner:
			pick.select(i)
	pick.item_selected.connect(func(i):
		_partner = teams[i].id
		_get.clear()
		_refresh_all())
	top.add_child(pick)
	_partner_pill_box = UI.hbox(6)
	top.add_child(_partner_pill_box)

	var body := UI.hbox(12)
	UI.expand(body)
	add_child(body)

	var left_card := UI.card("Your assets  -  double-click to add or remove", 10)
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left_card)
	_mine = _asset_table()
	_mine.row_activated.connect(func(key): _toggle(_give, key))
	UI.body(left_card).add_child(_mine)

	var mid := UI.card("", 14)
	mid.custom_minimum_size = Vector2(400, 0)
	body.add_child(mid)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.expand(scroll)
	UI.body(mid).add_child(scroll)
	_summary = UI.vbox(10)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_summary)

	var right_card := UI.card("", 10)
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right_card)
	_their_title = UI.caption("")
	UI.body(right_card).add_child(_their_title)
	_theirs = _asset_table()
	_theirs.row_activated.connect(func(key): _toggle(_get, key))
	UI.body(right_card).add_child(_theirs)
	_refresh_all()


# ------------------------------------------------------------------ tables

func _asset_table() -> DataTable:
	var t := DataTable.new()
	t.setup([["", 10], ["Asset", 0], ["Pos", 46], ["Age", 44], ["OVR", 50], ["Cap Hit", 86], ["Yrs", 40], ["Value", 74]])
	return t


func _rows(team_id: String, chosen: Array, viewer: String) -> Array:
	var rows := []
	var team := League.get_team(team_id)
	for p in League.roster(team_id):
		var key := "p:%d" % p.id
		var v := TradeAI.player_value(p, viewer)
		var row := {"id": key,
			"cells": ["", p.full_name() + ("  [block]" if Game.trading_block.has(str(p.id)) else "") +
				("  [NTC]" if p.contract.get("no_trade_clause", false) else ""),
				p.position, p.age, p.overall, Game.money(p.team_cap_hit()), p.contract["years"], _value_text(v)],
			"keys": [0, p.last_name, p.position, p.age, p.overall, p.team_cap_hit(), p.contract["years"], v],
			"cell_bg": {0: team.primary, 4: AppTheme.ovr_color(p.overall)},
			"cell_colors": {7: _value_color(v)}}
		if not p.on_nhl_roster():
			row["color"] = AppTheme.MUTED
		if _has(chosen, key):
			row["bg"] = Color(AppTheme.ACCENT_2, 0.35)
		rows.append(row)
	for pick_id in Game.team_picks(team_id):
		var key := "k:" + pick_id
		var v := TradeAI.pick_value(Game.picks[pick_id], viewer)
		var row := {"id": key, "cells": ["", Game.pick_label(pick_id), "Pick", "", "", "", "", _value_text(v)],
			"keys": [0, "zz" + pick_id, "Pick", 0, 0, 0, 0, v],
			"cell_bg": {0: AppTheme.GOLD.darkened(0.3)}, "cell_colors": {7: _value_color(v)}}
		if _has(chosen, key):
			row["bg"] = Color(AppTheme.ACCENT_2, 0.35)
		rows.append(row)
	return rows


func _value_text(v: float) -> String:
	if v >= 60:
		return "Elite"
	if v >= 30:
		return "High"
	if v >= 12:
		return "Good"
	if v >= 4:
		return "Fair"
	if v > 0:
		return "Low"
	return "Negative"


func _value_color(v: float) -> Color:
	if v >= 60:
		return AppTheme.GOLD
	if v >= 30:
		return AppTheme.GREEN
	if v >= 12:
		return AppTheme.LIME
	if v >= 4:
		return AppTheme.YELLOW
	if v > 0:
		return AppTheme.ORANGE
	return AppTheme.RED


static func _asset_from_key(key: String) -> Dictionary:
	if key.begins_with("p:"):
		return {"type": "player", "id": int(key.substr(2))}
	return {"type": "pick", "id": key.substr(2)}


static func _key_of(asset: Dictionary) -> String:
	return ("p:%d" % int(asset["id"])) if asset["type"] == "player" else "k:" + str(asset["id"])


func _has(list: Array, key: String) -> bool:
	for a in list:
		if _key_of(a) == key:
			return true
	return false


func _toggle(list: Array, key: Variant) -> void:
	var k := str(key)
	for a in list:
		if _key_of(a) == k:
			list.erase(a)
			_retain.erase(k.substr(2))
			_refresh_all()
			return
	list.append(_asset_from_key(k))
	_refresh_all()


# ------------------------------------------------------------------ summary

func _trade() -> Dictionary:
	return {"a": Game.user_team_id, "b": _partner, "a_gives": _give, "b_gives": _get, "retain": _retain}


func _refresh_all() -> void:
	_mine.set_rows(_rows(Game.user_team_id, _give, _partner))
	_theirs.set_rows(_rows(_partner, _get, _partner))
	_their_title.text = ("%s assets  -  double-click to add or remove" % League.get_team(_partner).name).to_upper()
	for c in _partner_pill_box.get_children():
		c.queue_free()
	_partner_pill_box.add_child(TeamCrest.make(_partner, 26))
	_partner_pill_box.add_child(UI.pill(TradeAI.strategy_label(_partner), TradeAI.strategy_color(_partner)))
	_build_summary()


func _build_summary() -> void:
	for c in _summary.get_children():
		c.queue_free()
	var user := Game.user_team_id
	_summary.add_child(UI.caption("You give"))
	if _give.is_empty():
		_summary.add_child(UI.label("Nothing yet", 13, AppTheme.FAINT))
	for a in _give.duplicate():
		_summary.add_child(_asset_line(a, _give, true))
	_summary.add_child(HSeparator.new())
	_summary.add_child(UI.caption("You get"))
	if _get.is_empty():
		_summary.add_child(UI.label("Nothing yet", 13, AppTheme.FAINT))
	for a in _get.duplicate():
		_summary.add_child(_asset_line(a, _get, false))
	_summary.add_child(HSeparator.new())

	var trade := _trade()
	if _give.is_empty() and _get.is_empty():
		_summary.add_child(UI.label("Double-click players or picks on either side to build a trade.", 13, AppTheme.MUTED))
		return

	# Cap and roster impact.
	var cap: int = League.finances.get("salary_cap", 0)
	for team in [user, _partner]:
		var before := League.payroll(team)
		var after := TradeAI.payroll_after(trade, team)
		var col := AppTheme.GREEN if after <= cap else AppTheme.RED
		var row := UI.hbox(6)
		row.add_child(UI.label("%s payroll" % ("Your" if team == user else League.get_team(team).name), 13, AppTheme.MUTED))
		row.add_child(UI.spacer())
		row.add_child(UI.label("%s -> %s" % [Game.money(before), Game.money(after)], 13, col))
		_summary.add_child(row)
	var nhl_after := TradeAI.players_after(trade, user)
	var rrow := UI.hbox(6)
	rrow.add_child(UI.label("Your NHL roster", 13, AppTheme.MUTED))
	rrow.add_child(UI.spacer())
	rrow.add_child(UI.label("%d -> %d / %d" % [League.nhl_roster(user).size(), nhl_after, Game.roster_max()], 13,
		AppTheme.GREEN if nhl_after <= Game.roster_max() else AppTheme.ORANGE))
	_summary.add_child(rrow)
	if nhl_after > Game.roster_max():
		_summary.add_child(UI.label("You'll need to send someone to the reserve list after this trade.", 12, AppTheme.ORANGE))
	_summary.add_child(HSeparator.new())

	# AI reaction.
	var e := TradeAI.evaluate(trade)
	var mood_col := AppTheme.RED
	match e["mood"]:
		"Deal":
			mood_col = AppTheme.GREEN
		"Close":
			mood_col = AppTheme.YELLOW
		"Not enough":
			mood_col = AppTheme.ORANGE
	_summary.add_child(UI.caption("%s response" % League.get_team(_partner).name))
	_summary.add_child(UI.label(e["mood"], 24, mood_col))
	if not e["blocked"]:
		_summary.add_child(UI.meter(clampf(e["ratio"] * 100.0, 2.0, 100.0), mood_col, 340, 12))
	var msg := UI.label(e["message"], 13, AppTheme.TEXT)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_child(msg)

	var buttons := UI.hbox(8)
	_summary.add_child(buttons)
	buttons.add_child(UI.button("Ask what they want", _ask))
	buttons.add_child(UI.button("Clear", func():
		_give.clear()
		_get.clear()
		_retain.clear()
		_refresh_all()))
	var propose := Button.new()
	propose.text = "Propose Trade"
	propose.custom_minimum_size = Vector2(0, 44)
	propose.add_theme_stylebox_override("normal", AppTheme.box(AppTheme.ACCENT, 6))
	propose.add_theme_stylebox_override("hover", AppTheme.box(AppTheme.ACCENT.lightened(0.1), 6))
	propose.add_theme_stylebox_override("disabled", AppTheme.box(AppTheme.PANEL_2, 6))
	propose.disabled = e["blocked"]
	propose.pressed.connect(_propose)
	_summary.add_child(propose)


func _asset_line(asset: Dictionary, list: Array, mine: bool) -> Control:
	var row := UI.hbox(6)
	var name_l := UI.label(TradeAI.describe(asset), 14, Color.WHITE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	row.add_child(name_l)
	if mine and asset["type"] == "player":
		var p := League.get_player(int(asset["id"]))
		var keep := OptionButton.new()
		keep.tooltip_text = "Salary you keep paying (max 50%, max 3 contracts)."
		var opts := [0.0, 0.25, 0.5]
		for o in opts:
			keep.add_item("Keep %d%%" % int(o * 100))
		var cur: float = float(_retain.get(str(p.id), 0.0))
		keep.select(opts.find(cur) if opts.has(cur) else 0)
		keep.item_selected.connect(func(i):
			if opts[i] > 0.0:
				_retain[str(p.id)] = opts[i]
			else:
				_retain.erase(str(p.id))
			_build_summary())
		row.add_child(keep)
	var x := UI.button("x", func():
		list.erase(asset)
		if asset["type"] == "player":
			_retain.erase(str(asset["id"]))
		_refresh_all())
	x.tooltip_text = "Remove"
	row.add_child(x)
	return row


func _ask() -> void:
	if _get.is_empty():
		_popup("Pick what you want", "Add at least one of their players or picks first, then ask what they'd want for it.")
		return
	var t := TradeAI.ask_what_they_want(_trade())
	if t.is_empty():
		_popup("No deal", "The %s can't find a package from your assets that works for them." % League.get_team(_partner).name)
		return
	_give = t["a_gives"]
	_refresh_all()


func _propose() -> void:
	var trade := _trade()
	var e := TradeAI.evaluate(trade)
	if not e["ok"]:
		_popup("Offer rejected", "The %s say no. %s" % [League.get_team(_partner).name, e["message"]])
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "Confirm trade"
	dlg.dialog_text = "The %s accept!\n\nYou get: %s\nYou give: %s\n\nMake the trade?" % [League.get_team(_partner).name,
		", ".join(_get.map(func(x): return TradeAI.describe(x))), ", ".join(_give.map(func(x): return TradeAI.describe(x)))]
	dlg.ok_button_text = "Make the trade"
	dlg.confirmed.connect(func():
		Game.execute_trade(trade)
		if Hub.current != null:
			Hub.current.refresh_bar()
		Hub.go("Trade Center", {"team": _partner}))
	add_child(dlg)
	dlg.popup_centered()


func _popup(title: String, text: String) -> void:
	var d := AcceptDialog.new()
	d.title = title
	d.dialog_text = text
	add_child(d)
	d.popup_centered()
