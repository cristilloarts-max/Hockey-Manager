class_name CapView
extends VBoxContainer
## Payroll today and committed money over the next five seasons.

const YEARS := 5


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var team_id := Game.user_team_id
	var cap: int = League.finances.get("salary_cap", 0)
	var floor_amt: int = League.finances.get("cap_floor", 0)
	var payroll := League.payroll(team_id)
	add_child(UI.heading("Contracts & Cap"))

	var summary := UI.hbox(32)
	add_child(summary)
	summary.add_child(UI.label("Cap  %s" % Game.money(cap), 16))
	summary.add_child(UI.label("Floor  %s" % Game.money(floor_amt), 16))
	summary.add_child(UI.label("Payroll  %s" % Game.money(payroll), 16))
	var space := cap - payroll
	summary.add_child(UI.label("Cap space  %s" % Game.money(space), 16,
		Color(0.4, 0.9, 0.5) if space >= 0 else Color(1, 0.4, 0.4)))

	var bar := ProgressBar.new()
	bar.max_value = cap
	bar.value = mini(payroll, cap)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	add_child(bar)

	var start_year := int(League.season_label.substr(0, 4)) if League.season_label.length() >= 4 else 2026
	var headers := [["Player", 0], ["Pos", 50], ["Age", 50], ["Status", 110]]
	for y in YEARS:
		headers.append(["%d-%02d" % [start_year + y, (start_year + y + 1) % 100], 105])
	var table := DataTable.new()
	table.setup(headers)
	table.row_activated.connect(func(id): PlayerWindow.open(self, int(id)))
	add_child(table)

	var totals := []
	for y in YEARS:
		totals.append(0)
	var rows := []
	for p in League.roster(team_id):
		var c: Dictionary = p.contract
		var status: String = c["expiry_status"]
		if c["elc"]:
			status = "ELC, " + status
		if c["no_trade_clause"]:
			status += ", NTC"
		var cells := [p.full_name(), p.position, p.age, status]
		var keys := [p.last_name, p.position, p.age, status]
		for y in YEARS:
			if y < c["years"]:
				cells.append(Game.money(c["cap_hit"]))
				keys.append(c["cap_hit"])
				totals[y] += c["cap_hit"]
			elif y == c["years"]:
				cells.append(c["expiry_status"])
				keys.append(0)
			else:
				cells.append("")
				keys.append(0)
		rows.append({"id": p.id, "cells": cells, "keys": keys})
	table.set_rows(rows)
	table.sort_by(4, true)

	var commit := UI.hbox(16)
	add_child(commit)
	commit.add_child(UI.label("Committed:", 15, UI.MUTED))
	for y in YEARS:
		commit.add_child(UI.label("%d-%02d  %s" % [start_year + y, (start_year + y + 1) % 100, Game.money(totals[y])], 15))
	add_child(UI.label("Re-signing, extensions, buyouts and free agency arrive in phase 4.", 0, UI.MUTED))
