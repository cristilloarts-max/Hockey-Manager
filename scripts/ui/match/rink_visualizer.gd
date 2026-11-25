class_name RinkVisualizer
extends Control
## NHL EDGE-style game visualizer: a white rink, players as numbered circles
## (home filled in team color, away white with a colored ring), the puck with
## a short trail, and goalies in their creases. Positions come from a
## formation engine driven by the Choreographer's puck and possession state
## and each team's tactics.

const RINK_W := 200.0
const RINK_H := 85.0
const SKATE_SPEED := 30.0       ## ft per game-second
const ICE := Color("#f5f7fa")
const LINE_RED := Color("#d6343e")
const LINE_BLUE := Color("#2f6fd8")

var chor: Choreographer
var teams := ["", ""]
var _pos := {}                 ## pid -> Vector2 (feet)
var _trail: Array = []
var _state: Dictionary = {}
var _t := 0.0
var _period := 1
var _scorer := 0
var _scorer_until := 0.0


func setup(choreographer: Choreographer, home: String, away: String) -> void:
	chor = choreographer
	teams = [home, away]
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Advance the picture to game time t (dt = game seconds since last frame).
func update(t: float, dt: float) -> void:
	if chor == null:
		return
	_t = t
	_period = chor.period_at(t)
	_state = chor.state_at(t)
	var puck: Vector2 = _state["puck"]
	_trail.push_front(puck)
	if _trail.size() > 7:
		_trail.pop_back()
	if _state["type"] == "goal":
		_scorer = int(_state["target"])
		_scorer_until = t + 2.0
	var max_step := SKATE_SPEED * clampf(dt, 0.0, 3.0)
	var seen := {}
	for side in 2:
		var units: Array = chor.on_ice(side, t)
		var targets := _targets(side, units, puck)
		for pid in targets:
			seen[pid] = true
			var goal: Vector2 = targets[pid]
			if not _pos.has(pid):
				# New shift: skate on from the bench (center of the top boards).
				_pos[pid] = Vector2(-10.0 if side == 0 else 10.0, -RINK_H / 2 + 2)
			var cur: Vector2 = _pos[pid]
			if pid == int(_state.get("carrier", 0)):
				_pos[pid] = puck
			elif dt > 3.0:
				_pos[pid] = goal
			else:
				_pos[pid] = cur.move_toward(goal, max_step)
	for pid in _pos.keys():
		if not seen.has(pid):
			_pos.erase(pid)
	queue_redraw()


# ------------------------------------------------------------------ formations

## Target spot (feet) for every player of `side` on the ice now.
func _targets(side: int, units: Array, puck: Vector2) -> Dictionary:
	var out := {}
	var d := Choreographer.dir_for(side, _period)
	var poss: int = _state.get("side", -1)
	var px := puck.x * d                 # puck in this team's attack frame
	var py := -puck.y * d
	var mine := units.size()
	var theirs: int = chor.on_ice(1 - side, _t).size()
	var tac: Tactics = Game.tactics.get(teams[side])
	var spots := {}
	for e in units:
		var spot: String = e[1]
		var f := Vector2.ZERO
		if _state.get("type", "") == "faceoff" or _state.get("type", "") == "whistle":
			f = _faceoff_spot(spot, px, py)
		elif poss == side:
			if mine > theirs and px > 20:
				f = _pp_spot(spot, tac.get_value("power_play.formation") if tac else 0, py)
			else:
				f = _attack_spot(spot, px, py, tac)
		elif poss == 1 - side:
			if mine < theirs and px < -20:
				f = _pk_spot(spot, tac.get_value("penalty_kill.formation") if tac else 0, py)
			else:
				f = _defend_spot(spot, px, py, tac)
		else:
			f = _faceoff_spot(spot, px, py)
		spots[int(e[0])] = f
	# The nearest defender pressures the puck carrier.
	if poss == 1 - side and _state.get("type", "") in ["carry", "hold"]:
		var best := 0
		var best_d := INF
		for pid in spots:
			var dd: float = spots[pid].distance_to(Vector2(px, py))
			if dd < best_d:
				best_d = dd
				best = pid
		if best != 0:
			spots[best] = Vector2(px - 4.0, py + signf(-py + 0.01) * 2.5)
	for pid in spots:
		var f: Vector2 = spots[pid]
		f.x = clampf(f.x, -94.0, 94.0)
		f.y = clampf(f.y, -38.0, 38.0)
		out[pid] = Vector2(f.x * d, -f.y * d)
	var g := chor.goalie(side)
	if g != 0:
		out[g] = Vector2(-86.0 * d, clampf(puck.y * 0.12, -2.5, 2.5))
	return out


func _faceoff_spot(spot: String, px: float, py: float) -> Vector2:
	var dot := Vector2(px, py)
	match spot:
		"C":
			return dot + Vector2(-2.5, 0)
		"LW":
			return dot + Vector2(-4, 15)
		"RW":
			return dot + Vector2(-4, -15)
		"LD":
			return dot + Vector2(-22, 9)
		"RD":
			return dot + Vector2(-22, -9)
	return dot + Vector2(-10, 0)


func _attack_spot(spot: String, px: float, py: float, tac: Tactics) -> Vector2:
	var structure := tac.get_value("o_zone.structure") if tac else 0
	if px > 25.0:
		# Offensive zone.
		var s := signf(py + 0.01)
		match spot:
			"LD":
				return Vector2(31, 17 if structure != 2 or s > 0 else 8)
			"RD":
				return Vector2(31, -17 if structure != 2 or s < 0 else -8)
			"C":
				return Vector2(84 if structure == 1 else 68, py * 0.3)
			"LW":
				if structure == 0:
					return Vector2(78, 26) if s > 0 else Vector2(70, 6)
				return Vector2(62, 22)
			"RW":
				if structure == 0:
					return Vector2(78, -26) if s < 0 else Vector2(70, -6)
				return Vector2(62, -22)
	elif px > -25.0:
		# Rush through the neutral zone; non-carriers stay onside until the puck is in.
		match spot:
			"LW":
				return Vector2(minf(px + 12, 23), 25)
			"RW":
				return Vector2(minf(px + 12, 23), -25)
			"C":
				return Vector2(px - 4, py * 0.4)
			"LD":
				return Vector2(px - 24, 12)
			"RD":
				return Vector2(px - 24, -12)
	else:
		# Breakout from their own zone.
		match spot:
			"LD":
				return Vector2(-80, 12)
			"RD":
				return Vector2(-80, -12)
			"C":
				return Vector2(-64, 0)
			"LW":
				return Vector2(-52, 32)
			"RW":
				return Vector2(-52, -32)
	return Vector2(px - 10, 0)


## Defending: zone coverage, neutral-zone gaps, or the forecheck system.
func _defend_spot(spot: String, px: float, py: float, tac: Tactics) -> Vector2:
	# px here is the puck in the DEFENDING team's attack frame.
	if px < -25.0:
		match spot:
			"LD":
				return Vector2(-80, 8)
			"RD":
				return Vector2(-80, -8)
			"C":
				return Vector2(-70, py * 0.5)
			"LW":
				return Vector2(-48, 20)
			"RW":
				return Vector2(-48, -20)
	elif px < 25.0:
		var gap := clampf(px - 20, -70, 10)
		match spot:
			"LD":
				return Vector2(gap, 13)
			"RD":
				return Vector2(gap, -13)
			"C":
				return Vector2(px - 8, py)
			"LW":
				return Vector2(px - 14, 22)
			"RW":
				return Vector2(px - 14, -22)
	else:
		# Puck deep in their offensive zone: forecheck.
		var system := tac.get_value("forecheck.system") if tac else 0
		match spot:
			"LD":
				return Vector2(28 if system != 2 else 18, 15)
			"RD":
				return Vector2(28 if system != 2 else 18, -15)
			"C":
				return Vector2(px - 3, py)
			"LW":
				if system == 1 or system == 4:
					return Vector2(px - 6, py + 8)
				if system == 2:
					return Vector2(28, 12)
				if system == 3:
					return Vector2(46, 25)
				return Vector2(55, 18)
			"RW":
				if system == 4:
					return Vector2(px - 6, py - 8)
				if system == 3:
					return Vector2(46, -25)
				return Vector2(55, -18)
	return Vector2(px - 10, 0)


func _pp_spot(spot: String, formation: int, py: float) -> Vector2:
	var s := 1.0 if py >= 0 else -1.0
	var shapes := {
		0: {"LD": Vector2(32, 0), "LW": Vector2(58, 24), "RW": Vector2(58, -24), "C": Vector2(68, 0), "RD": Vector2(84, 2)},
		1: {"LD": Vector2(32, 10), "RD": Vector2(32, -10), "LW": Vector2(55, 24), "RW": Vector2(55, -24), "C": Vector2(84, 0)},
		2: {"LD": Vector2(32, 12 * s), "LW": Vector2(58, 26 * s), "C": Vector2(80, 22 * s), "RW": Vector2(72, -6 * s), "RD": Vector2(84, 0)},
	}
	var shape: Dictionary = shapes.get(formation, shapes[1])
	return shape.get(spot, Vector2(60, 0))


func _pk_spot(spot: String, formation: int, py: float) -> Vector2:
	if formation == 1:
		var dia := {"LD": Vector2(-82, 0), "RD": Vector2(-70, -14), "C": Vector2(-52, 0), "LW": Vector2(-70, 14), "RW": Vector2(-60, 0)}
		return dia.get(spot, Vector2(-65, 0))
	var box := {"LD": Vector2(-78, 9), "RD": Vector2(-78, -9), "C": Vector2(-60, 14), "LW": Vector2(-60, -14), "RW": Vector2(-60, 0)}
	var v: Vector2 = box.get(spot, Vector2(-65, 0))
	return v + Vector2(0, py * 0.15)


# ------------------------------------------------------------------ drawing

func _scale() -> float:
	return minf((size.x - 20) / RINK_W, (size.y - 20) / RINK_H)


func _to_px(p: Vector2) -> Vector2:
	var s := _scale()
	return size / 2 + Vector2(p.x * s, p.y * s)


func _draw() -> void:
	var s := _scale()
	var rect := Rect2(_to_px(Vector2(-RINK_W / 2, -RINK_H / 2)), Vector2(RINK_W * s, RINK_H * s))
	var ice := AppTheme.box(ICE, int(28 * s), Color("#c9d1dc"), 2, 0, 0)
	draw_style_box(ice, rect)
	# Goal lines, blue lines, red line.
	for x in [-89.0, 89.0]:
		draw_line(_to_px(Vector2(x, -RINK_H / 2 + 4)), _to_px(Vector2(x, RINK_H / 2 - 4)), Color(LINE_RED, 0.7), 1.5)
	for x in [-25.0, 25.0]:
		draw_line(_to_px(Vector2(x, -RINK_H / 2)), _to_px(Vector2(x, RINK_H / 2)), LINE_BLUE, maxf(3.0, s * 1.0))
	var y := -RINK_H / 2
	while y < RINK_H / 2:
		draw_line(_to_px(Vector2(0, y)), _to_px(Vector2(0, minf(y + 2.2, RINK_H / 2))), LINE_RED, maxf(3.0, s * 0.9))
		y += 3.2
	# Circles and dots.
	draw_arc(_to_px(Vector2.ZERO), 15 * s, 0, TAU, 64, Color(LINE_BLUE, 0.8), 1.5, true)
	for cx in [-69.0, 69.0]:
		for cy in [-22.0, 22.0]:
			draw_arc(_to_px(Vector2(cx, cy)), 15 * s, 0, TAU, 64, Color(LINE_RED, 0.75), 1.2, true)
			draw_circle(_to_px(Vector2(cx, cy)), 1.0 * s, LINE_RED)
			for hx in [-1.0, 1.0]:
				var a := _to_px(Vector2(cx + 2 * hx, cy - 3))
				draw_line(a, a + Vector2(0, 6 * s), Color(LINE_RED, 0.6), 1.0)
	for cx in [-20.0, 20.0]:
		for cy in [-22.0, 22.0]:
			draw_circle(_to_px(Vector2(cx, cy)), 1.0 * s, LINE_RED)
	# Creases and nets.
	for gx in [-89.0, 89.0]:
		var inward := 1.0 if gx < 0 else -1.0
		var pts := PackedVector2Array()
		for i in 13:
			var ang := -PI / 2 + PI * i / 12.0
			pts.append(_to_px(Vector2(gx + inward * cos(ang) * 6.0, sin(ang) * 4.0)))
		draw_colored_polygon(pts, Color("#9cc7f0", 0.6))
		var net := Rect2(_to_px(Vector2(gx - (3.5 if gx > 0 else -3.5) * 0 + (0.0 if gx > 0 else -3.5), -3)), Vector2(3.5 * s, 6 * s))
		draw_rect(net, Color("#c9d1dc"), false, 1.5)
	# Center logo: home crest.
	var home = League.get_team(teams[0])
	if home != null:
		var cw := 18.0 * s
		var shield := TeamCrest._shield(_to_px(Vector2.ZERO) - Vector2(cw / 2, cw * 0.58), cw, cw * 1.15)
		draw_colored_polygon(shield, Color(home.secondary, 0.9))
		var inner := TeamCrest._shield(_to_px(Vector2.ZERO) - Vector2(cw / 2 - 2, cw * 0.58 - 2), cw - 4, cw * 1.15 - 4)
		draw_colored_polygon(inner, Color(home.primary, 0.9))
		var fnt := AppTheme.font("display_bold")
		draw_string(fnt, _to_px(Vector2.ZERO) + Vector2(-cw / 2, cw * 0.18), home.id, HORIZONTAL_ALIGNMENT_CENTER, cw, int(cw * 0.32), home.on_primary())
	# Team names at the ends they defend.
	var fnt2 := AppTheme.font("display_bold")
	for side in 2:
		var t = League.get_team(teams[side])
		if t == null:
			continue
		var d := Choreographer.dir_for(side, _period)
		var end := _to_px(Vector2(-d * 96.5, 0))
		draw_set_transform(end, -PI / 2 * d, Vector2.ONE)
		draw_string(fnt2, Vector2(-40, 8 * s * 0.4 + 6), t.id, HORIZONTAL_ALIGNMENT_CENTER, 80, int(5.5 * s), t.accent())
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Players.
	var r := maxf(9.0, 2.6 * s)
	var font := AppTheme.font("display_bold")
	var carrier: int = int(_state.get("carrier", 0))
	for side in 2:
		var t = League.get_team(teams[side])
		var ring: Color = t.primary if t.primary.get_luminance() < 0.75 else t.secondary
		for pid in _pos:
			if not _belongs(pid, side):
				continue
			var c := _to_px(_pos[pid])
			var p := League.get_player(pid)
			var num := str(p.number) if p else ""
			if pid == carrier or (pid == _scorer and _t < _scorer_until):
				draw_arc(c, r + 4, 0, TAU, 32, ring, 2.5, true)
			draw_circle(c + Vector2(0, 1.5), r, Color(0, 0, 0, 0.18))
			if side == 0:
				draw_circle(c, r, t.primary)
				draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.9), 1.5, true)
				draw_string(font, c + Vector2(-r, r * 0.38), num, HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 1.05), t.on_primary())
			else:
				draw_circle(c, r, Color.WHITE)
				draw_arc(c, r - 1, 0, TAU, 32, ring, 2.5, true)
				draw_string(font, c + Vector2(-r, r * 0.38), num, HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 1.05), ring)
	# Puck and trail.
	for i in range(_trail.size() - 1, 0, -1):
		draw_circle(_to_px(_trail[i]), maxf(2.0, 0.8 * s) * (1.0 - i / 8.0), Color(0, 0, 0, 0.12 * (8 - i) / 8.0))
	if not _trail.is_empty():
		draw_circle(_to_px(_trail[0]), maxf(3.5, 1.0 * s), Color("#111111"))


func _belongs(pid: int, side: int) -> bool:
	if pid == chor.goalie(side):
		return true
	for e in chor.on_ice(side, _t):
		if int(e[0]) == pid:
			return true
	return false
