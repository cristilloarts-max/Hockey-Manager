class_name TacticsView
extends VBoxContainer
## Built straight from Tactics.GROUPS: one tab per area, a dropdown per setting.

## Settings the phase 1 sim already uses (the rest are stored for phase 6).
const WIRED := ["forecheck.system", "forecheck.intensity", "d_zone.collapse", "d_zone.blocking",
	"o_zone.shot_selection", "power_play.threat", "power_play.movement", "power_play.usage",
	"penalty_kill.pressure", "game.mentality", "game.physicality", "game.discipline",
	"situations.protect_lead", "situations.pull_goalie_1", "situations.pull_goalie_2"]


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var tac: Tactics = Game.tactics[Game.user_team_id]
	var pickers := {}
	var top := UI.hbox(12)
	add_child(top)
	top.add_child(UI.heading("Tactics"))
	top.add_child(UI.button("Reset to defaults", func():
		tac.reset()
		for k in pickers:
			pickers[k].select(tac.get_value(k))))
	add_child(UI.label("Settings marked with a dot already affect games. The rest are saved now and come into play when the full tactics engine arrives.", 0, UI.MUTED))

	var tabs := TabContainer.new()
	UI.expand(tabs)
	add_child(tabs)
	for g in Tactics.GROUPS:
		var grid := GridContainer.new()
		grid.name = g["label"]
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 10)
		for s in g["settings"]:
			var key := "%s.%s" % [g["key"], s["key"]]
			var lbl := UI.label(("●  " if key in WIRED else "    ") + s["label"], 15)
			lbl.custom_minimum_size = Vector2(240, 0)
			grid.add_child(lbl)
			var opt := OptionButton.new()
			opt.custom_minimum_size = Vector2(280, 0)
			for o in s["options"]:
				opt.add_item(o)
			opt.select(tac.get_value(key))
			opt.item_selected.connect(func(i): tac.set_value(key, i))
			pickers[key] = opt
			grid.add_child(opt)
		tabs.add_child(UI.margin(grid, 16))
		tabs.set_tab_title(tabs.get_tab_count() - 1, g["label"])
