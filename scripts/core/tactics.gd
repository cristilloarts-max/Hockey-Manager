class_name Tactics
extends RefCounted
## Team tactics. Every setting is defined as data in GROUPS so the UI can build
## itself and the sim can read any of them. Phase 1 wires a subset into the sim
## (see modifiers()); the rest are stored and shown, ready for phase 6.

const GROUPS := [
	{"key": "forecheck", "label": "Forecheck", "settings": [
		{"key": "system", "label": "System", "default": 0,
			"options": ["1-2-2 (balanced)", "2-1-2 (aggressive)", "2-3 / Left-wing lock", "1-3-1 (clog)", "All-out (3 deep)"]},
		{"key": "intensity", "label": "Pressure intensity", "default": 1, "options": ["Contain", "Angle", "Attack"]},
		{"key": "f1_route", "label": "F1 route", "default": 0, "options": ["Steer to strong side", "Steer to weak side", "Take the body"]},
		{"key": "f2_role", "label": "F2 role", "default": 1, "options": ["Take away D-to-D", "Support F1", "Seal the wall"]},
		{"key": "pinch", "label": "D pinch rule", "default": 1, "options": ["Never", "When supported", "Aggressive"]},
		{"key": "when", "label": "When to forecheck", "default": 0, "options": ["Always", "Only on dump-ins", "Only when trailing"]},
	]},
	{"key": "neutral_zone", "label": "Neutral zone", "settings": [
		{"key": "system", "label": "System", "default": 0, "options": ["1-2-2 trap", "1-3-1", "Left-wing lock", "Man pressure"]},
		{"key": "gap", "label": "D gap", "default": 1, "options": ["Tight", "Standard", "Loose"]},
		{"key": "stand_up", "label": "Blue-line stand-up", "default": 1, "options": ["Always", "Skill-dependent", "Never (sag)"]},
		{"key": "backcheck", "label": "Forward backcheck", "default": 1, "options": ["All three", "Two back", "One high"]},
	]},
	{"key": "d_zone", "label": "Defensive zone", "settings": [
		{"key": "system", "label": "Coverage", "default": 0, "options": ["Zone", "Man-to-man", "Hybrid", "Swarm"]},
		{"key": "collapse", "label": "Collapse level", "default": 1, "options": ["Protect the house", "Balanced", "Pressure the points"]},
		{"key": "weak_winger", "label": "Weak-side winger", "default": 0, "options": ["Cover the point", "Sag to the slot"]},
		{"key": "blocking", "label": "Shot blocking", "default": 1, "options": ["Active", "Selective", "Avoid"]},
		{"key": "net_front", "label": "Net-front battle", "default": 0, "options": ["Box out", "Tie up sticks", "Front the shooter"]},
		{"key": "center_low", "label": "Center low support", "default": 0, "options": ["Always", "Read-based"]},
	]},
	{"key": "breakout", "label": "Breakout", "settings": [
		{"key": "type", "label": "Type", "default": 0, "options": ["Standard up the wall", "Reverse", "Wheel (D carries)", "Stretch pass", "D-to-D", "Center swing low"]},
		{"key": "risk", "label": "Risk", "default": 1, "options": ["Safe (glass and out)", "Balanced", "Possession at all costs"]},
		{"key": "winger_depth", "label": "Winger depth", "default": 1, "options": ["Hash marks", "Blue line", "Stretched to red line"]},
		{"key": "retrieval", "label": "Retrieval D", "default": 0, "options": ["Strong-side D", "Closest D"]},
	]},
	{"key": "entry", "label": "Zone entry", "settings": [
		{"key": "style", "label": "Style", "default": 0, "options": ["Carry in", "Dump and chase", "Chip and chase", "Drop pass", "Cross-ice delay"]},
		{"key": "carrier", "label": "Carrier", "default": 0, "options": ["Best puck handler", "Whoever has it"]},
		{"key": "trailer", "label": "Trailer", "default": 1, "options": ["D jumps up", "F3 stays high"]},
		{"key": "dump_target", "label": "Dump target", "default": 0, "options": ["Wide rim", "Hard around", "Soft area"]},
	]},
	{"key": "o_zone", "label": "Offensive zone", "settings": [
		{"key": "structure", "label": "Structure", "default": 0, "options": ["Low cycle", "Point shots + traffic", "Overload", "Umbrella", "Low-to-high", "East-west seam"]},
		{"key": "net_front", "label": "Net-front presence", "default": 1, "options": ["None", "One player", "Crash two"]},
		{"key": "d_activation", "label": "D activation", "default": 1, "options": ["Stay home", "Walk the line", "Activate down the wall", "Rove"]},
		{"key": "shot_selection", "label": "Shot selection", "default": 1, "options": ["Shoot everything", "Quality only", "Tips and rebounds"]},
		{"key": "cycle", "label": "Cycle direction", "default": 0, "options": ["Strong side", "Switch to weak side"]},
	]},
	{"key": "rush", "label": "Rush offense", "settings": [
		{"key": "width", "label": "Width", "default": 0, "options": ["Stretch wide", "Narrow lanes", "Triangle"]},
		{"key": "middle_lane", "label": "Middle lane", "default": 0, "options": ["Drive the net", "Delay for the trailer"]},
		{"key": "odd_man", "label": "Odd-man rushes", "default": 1, "options": ["Shoot first", "Pass first", "Attack the net"]},
	]},
	{"key": "power_play", "label": "Power play", "settings": [
		{"key": "formation", "label": "Formation", "default": 0, "options": ["1-3-1", "Umbrella (1-2-2)", "Overload", "Spread", "2-1-2"]},
		{"key": "entry", "label": "Entry", "default": 0, "options": ["Drop pass", "Slingshot", "Carry with support", "Dump and retrieve"]},
		{"key": "threat", "label": "Primary threat", "default": 0, "options": ["Off-wing one-timer", "Point bomb", "Bumper slot", "Net-front tips"]},
		{"key": "movement", "label": "Puck movement", "default": 1, "options": ["Patient", "Quick strike", "Shoot on sight"]},
		{"key": "usage", "label": "Unit usage", "default": 0, "options": ["PP1 heavy", "Even split"]},
	]},
	{"key": "penalty_kill", "label": "Penalty kill", "settings": [
		{"key": "formation", "label": "Formation", "default": 0, "options": ["Box", "Diamond", "Wedge+1", "Aggressive 1-3"]},
		{"key": "pressure", "label": "Pressure", "default": 0, "options": ["Passive (protect slot)", "Pressure the bumps", "Attack the carrier"]},
		{"key": "sh_offense", "label": "Shorthanded offense", "default": 0, "options": ["Clear and change", "Counter when open"]},
		{"key": "blocking", "label": "Shot blocking", "default": 0, "options": ["Maximum", "Selective"]},
		{"key": "entry_defense", "label": "Entry defense", "default": 1, "options": ["Pressure at red line", "1-3 stack at blue line"]},
	]},
	{"key": "game", "label": "Game management", "settings": [
		{"key": "mentality", "label": "Mentality", "default": 3, "options": ["Shell", "Defensive", "Cautious", "Balanced", "Positive", "Attacking", "All-out"]},
		{"key": "tempo", "label": "Tempo", "default": 1, "options": ["Slow", "Controlled", "Fast"]},
		{"key": "physicality", "label": "Physicality", "default": 1, "options": ["Avoid", "Balanced", "Punishing"]},
		{"key": "discipline", "label": "Discipline", "default": 1, "options": ["Stay clean", "Balanced", "Edge"]},
		{"key": "shift_length", "label": "Shift length", "default": 1, "options": ["Short (35s)", "Standard (45s)", "Long (60s)"]},
	]},
	{"key": "situations", "label": "Game situations", "settings": [
		{"key": "protect_lead", "label": "Leading in the 3rd", "default": 1, "options": ["Go defensive at 10:00", "Go defensive at 5:00", "Keep the system"]},
		{"key": "pull_goalie_1", "label": "Pull goalie, down 1", "default": 1, "options": ["Never", "1:00 left", "1:30 left", "2:00 left", "3:00 left"]},
		{"key": "pull_goalie_2", "label": "Pull goalie, down 2", "default": 3, "options": ["Never", "1:30 left", "2:30 left", "3:30 left", "4:30 left"]},
		{"key": "line_matching", "label": "Line matching", "default": 0, "options": ["None", "Shutdown line vs their top line", "Top line vs their top line"]},
		{"key": "ot_style", "label": "3-on-3 OT", "default": 0, "options": ["Possession and regroup", "Attack", "2 F + 1 D", "1 F + 2 D"]},
	]},
]

var settings: Dictionary = {}   ## "group.setting" -> option index


func _init() -> void:
	reset()


func reset() -> void:
	settings.clear()
	for g in GROUPS:
		for s in g["settings"]:
			settings["%s.%s" % [g["key"], s["key"]]] = s["default"]


func get_value(key: String) -> int:
	return int(settings.get(key, 0))


func set_value(key: String, idx: int) -> void:
	settings[key] = idx


## Effects the phase 1 sim reads. Each is a multiplier around 1.0.
##   offense:       your shot generation
##   allow:         opponent's shot generation against you
##   quality_for / quality_against: shot quality (goal chance) multipliers
##   penalties:     how often you take penalties
##   pp_quality / pk_quality: special-teams effectiveness
func modifiers() -> Dictionary:
	var m := {"offense": 1.0, "allow": 1.0, "quality_for": 1.0, "quality_against": 1.0,
		"penalties": 1.0, "pp_quality": 1.0, "pk_quality": 1.0}

	var mentality := get_value("game.mentality") - 3    # -3 .. +3
	_mul(m, "offense", 1.0 + 0.05 * mentality)
	_mul(m, "allow", 1.0 + 0.04 * mentality)

	match get_value("forecheck.system"):
		1:  # 2-1-2 aggressive
			_mul(m, "offense", 1.04)
			_mul(m, "quality_against", 1.05)
		2:  # left-wing lock
			_mul(m, "offense", 0.96)
			_mul(m, "allow", 0.94)
		3:  # 1-3-1
			_mul(m, "offense", 0.97)
			_mul(m, "allow", 0.95)
		4:  # all-out
			_mul(m, "offense", 1.08)
			_mul(m, "quality_against", 1.10)
	var intensity := get_value("forecheck.intensity") - 1
	_mul(m, "offense", 1.0 + 0.02 * intensity)
	_mul(m, "quality_against", 1.0 + 0.02 * intensity)

	match get_value("d_zone.collapse"):
		0:
			_mul(m, "quality_against", 0.95)
			_mul(m, "allow", 1.04)
		2:
			_mul(m, "quality_against", 1.04)
			_mul(m, "allow", 0.96)
	match get_value("d_zone.blocking"):
		0:
			_mul(m, "quality_against", 0.96)
		2:
			_mul(m, "quality_against", 1.04)

	match get_value("o_zone.shot_selection"):
		0:
			_mul(m, "offense", 1.08)
			_mul(m, "quality_for", 0.93)
		1:
			_mul(m, "offense", 0.95)
			_mul(m, "quality_for", 1.05)

	match get_value("game.physicality"):
		0:
			_mul(m, "penalties", 0.85)
			_mul(m, "allow", 1.02)
		2:
			_mul(m, "penalties", 1.30)
			_mul(m, "allow", 0.97)
	match get_value("game.discipline"):
		0:
			_mul(m, "penalties", 0.80)
			_mul(m, "allow", 1.02)
		2:
			_mul(m, "penalties", 1.25)
			_mul(m, "allow", 0.98)

	match get_value("power_play.movement"):
		0:
			_mul(m, "pp_quality", 1.04)
		2:
			_mul(m, "pp_quality", 0.97)
	if get_value("penalty_kill.pressure") == 2:
		_mul(m, "pk_quality", 0.95)   # below 1 = less quality allowed while shorthanded
	return m


static func _mul(m: Dictionary, key: String, v: float) -> void:
	m[key] = m[key] * v


## Seconds left at which the goalie is pulled when trailing by `deficit`, or -1.
func pull_goalie_time(deficit: int) -> int:
	if deficit == 1:
		return [-1, 60, 90, 120, 180][get_value("situations.pull_goalie_1")]
	if deficit == 2:
		return [-1, 90, 150, 210, 270][get_value("situations.pull_goalie_2")]
	return -1


func to_dict() -> Dictionary:
	return settings.duplicate()


static func from_dict(d: Dictionary) -> Tactics:
	var t := Tactics.new()
	for k in d:
		t.settings[k] = int(d[k])
	return t
