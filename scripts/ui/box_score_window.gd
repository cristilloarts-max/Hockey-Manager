class_name BoxScoreWindow
extends AcceptDialog
## Box score + play-by-play for one of your games.


static func open(parent: Node, schedule_index: int) -> void:
	var key := str(schedule_index)
	if not Game.box_scores.has(key):
		return
	var w := BoxScoreWindow.new()
	w._build(Game.box_scores[key])
	parent.add_child(w)
	w.popup_centered(Vector2i(980, 720))


func _build(res: Dictionary) -> void:
	var home: String = res["home"]
	var away: String = res["away"]
	var suffix := "" if res["ot"] == "" else " (%s)" % res["ot"]
	title = "%s %d  @  %s %d%s" % [UI.team_name(away), res["away_goals"], UI.team_name(home), res["home_goals"], suffix]
	ok_button_text = "Close"

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(940, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := UI.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	# Score by period.
	var bb := "[table=6][cell][b]Team[/b]   [/cell]"
	var periods: Array = res["periods"]
	for i in periods.size():
		bb += "[cell][b]%s[/b]  [/cell]" % (str(i + 1) if i < 3 else "OT")
	bb += "[cell][b]T[/b]  [/cell][cell][b]SOG[/b]  [/cell][cell][b]PP[/b][/cell]"
	for side in [["away", 1], ["home", 0]]:
		var id: String = res[side[0]]
		bb += "[cell]%s   [/cell]" % id
		for pr in periods:
			bb += "[cell]%d  [/cell]" % int(pr[side[1]])
		bb += "[cell][b]%d[/b]  [/cell][cell]%d  [/cell][cell]%d/%d[/cell]" % [
			res[side[0] + "_goals"], res[side[0] + "_shots"], res[side[0] + "_pp"][0], res[side[0] + "_pp"][1]]
	bb += "[/table]"
	# Columns = team + periods + T + SOG + PP.
	bb = bb.replace("[table=6]", "[table=%d]" % (periods.size() + 4))
	box.add_child(UI.rich(bb))

	# Three stars.
	var stars := []
	for pid in res["stars"]:
		var p = League.get_player(int(pid))
		var line: Dictionary = res["stats"][pid]
		if p != null:
			stars.append("%s (%s) %dG %dA" % [p.full_name(), p.team_id, line["g"], line["a"]])
	if not stars.is_empty():
		box.add_child(UI.label("Three stars: " + "  |  ".join(stars), 15))

	# Skater tables.
	for side in [away, home]:
		box.add_child(UI.label(UI.team_name(side), 18))
		var t := DataTable.new()
		t.custom_minimum_size = Vector2(0, 260)
		t.setup([["Player", 0], ["Pos", 50], ["G", 40], ["A", 40], ["P", 40], ["+/-", 50], ["SOG", 50], ["PIM", 50], ["TOI", 70]])
		var rows := []
		for pid in res["stats"]:
			var line: Dictionary = res["stats"][pid]
			if line["team"] != side:
				continue
			var p = League.get_player(int(pid))
			if p == null:
				continue
			rows.append({"id": p.id, "cells": [p.full_name(), p.position, int(line["g"]), int(line["a"]),
				int(line["g"]) + int(line["a"]), int(line["pm"]), int(line["shots"]), int(line["pim"]), UI.fmt_toi(line["toi"])],
				"keys": [p.full_name(), p.position, int(line["g"]), int(line["a"]), int(line["g"]) + int(line["a"]),
				int(line["pm"]), int(line["shots"]), int(line["pim"]), float(line["toi"])]})
		t.set_rows(rows)
		t.sort_by(8, true)
		box.add_child(t)
		for gid in res["goalies"]:
			var gl: Dictionary = res["goalies"][gid]
			if gl["team"] != side:
				continue
			var g = League.get_player(int(gid))
			var sa := int(gl["sa"])
			var sv := sa - int(gl["ga"])
			box.add_child(UI.label("Goalie: %s  %d saves on %d shots (%.3f)  %s" % [
				g.full_name() if g else str(gid), sv, sa, (float(sv) / sa) if sa > 0 else 0.0, gl["decision"]], 0, UI.MUTED))

	# Play-by-play.
	box.add_child(UI.label("Play-by-play", 18))
	var pbp := ""
	for e in res["events"]:
		var color := "#cccccc"
		match e["type"]:
			"goal":
				color = "#7fe07f" if e["team"] == Game.user_team_id else "#ff8a80"
			"penalty":
				color = "#ffd27f"
			"end":
				color = "#8fb8ff"
			"save":
				color = "#b0b0b0"
		var stamp: String = e["period"]
		if e["time"] != "":
			stamp += " " + e["time"]
		var team_tag: String = (e["team"] + "  ") if e["team"] != "" else ""
		pbp += "[color=%s]%s  %s%s[/color]\n" % [color, stamp, team_tag, e["text"]]
	box.add_child(UI.rich(pbp))
