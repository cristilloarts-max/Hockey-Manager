class_name RinkVisualizer
extends Control
## NHL EDGE-style game visualizer: a white rink, players as numbered circles
## (home filled in team color, away white with a colored ring), the puck with
## a short trail, and goalies in their creases. Positions come from a
## formation engine driven by the Choreographer's puck and possession state
## and each team's tactics.

const RINK_W := 200.0
const RINK_H := 85.0
const SKATE_SPEED := 26.0       ## ft per game-second
const ACCEL := 40.0             ## ft per game-second squared
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
var _vel := {}                 ## pid -> Vector2 (ft per game-second)
var _leaving := {}             ## pid -> side, skating to the bench
var _boxed := {}               ## pid -> penalty entry
var _last_units := ["", ""]
## Latest line-change note for the event bar.
var note := ""
var note_until := 0.0


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
	var step := clampf(dt, 0.0, 3.0)
	var snap := dt > 3.0
	# Who's in the penalty box right now.
	_boxed.clear()
	for pen in chor.penalties:
		if t >= float(pen["t0"]) and t < float(pen["t1"]):
			_boxed[int(pen["pid"])] = pen
	var seen := {}
	for side in 2:
		var units: Array = chor.visible_on_ice(side, t).filter(func(e): return not _boxed.has(int(e[0])))
		_note_line_change(side, units)
		var targets := _targets(side, units, puck)
		for pid in targets:
			seen[pid] = true
			_leaving.erase(pid)
			if not _pos.has(pid):
				# Fresh legs jump on from the bench.
				_pos[pid] = _bench(side, pid)
				_vel[pid] = Vector2.ZERO
			_move(pid, targets[pid], step, snap, pid == int(_state.get("carrier", 0)), puck)
	# Players coming off skate to their bench; boxed players sit in the box.
	for pid in _pos.keys():
		if seen.has(pid):
			continue
		if _boxed.has(pid):
			_pos[pid] = _box_spot(int(_boxed[pid]["side"]))
			continue
		var side := _side_of(pid)
		if not _leaving.has(pid):
			_leaving[pid] = side
		var bench := _bench(side, pid)
		_move(pid, bench, step, snap, false, puck)
		if _pos[pid].distance_to(bench) < 2.5 or snap:
			_pos.erase(pid)
			_vel.erase(pid)
			_leaving.erase(pid)
	queue_redraw()


## Smooth skating: accelerate toward the target, glide, never teleport.
func _move(pid: int, target: Vector2, step: float, snap: bool, carrier: bool, puck: Vector2) -> void:
	if snap:
		_pos[pid] = puck if carrier else target
		_vel[pid] = Vector2.ZERO
		return
	if carrier:
		_vel[pid] = (puck - _pos[pid]) / maxf(step, 0.01)
		_pos[pid] = puck
		return
	var cur: Vector2 = _pos[pid]
	var v: Vector2 = _vel.get(pid, Vector2.ZERO)
	var to := target - cur
	var dist := to.length()
	var cap := SKATE_SPEED * (1.25 if _is_hitter(pid) else 1.0)
	var want := to.normalized() * minf(cap, dist * 1.8) if dist > 0.05 else Vector2.ZERO
	v = v.move_toward(want, ACCEL * step)
	_vel[pid] = v
	_pos[pid] = cur + v * step


func _is_hitter(pid: int) -> bool:
	return _state.get("type", "") == "hit" and int(_state.get("target", 0)) == pid


func _side_of(pid: int) -> int:
	var p := League.get_player(pid)
	return 0 if p != null and p.team_id == teams[0] else 1


## Bench doors along the top boards (home left of center, away right).
func _bench(side: int, pid: int) -> Vector2:
	var x := -18.0 + float(pid % 7) * 2.0
	return Vector2(x if side == 0 else -x, -RINK_H / 2 - 5.0)


func _box_spot(side: int) -> Vector2:
	return Vector2(-9.0 if side == 0 else 9.0, RINK_H / 2 + 5.0)


## Announce line changes: "on the fly" during play, plain at stoppages.
func _note_line_change(side: int, units: Array) -> void:
	var ids := units.map(func(e): return int(e[0]))
	var key := ",".join(ids.map(func(x): return str(x)))
	if _last_units[side] != "" and key != _last_units[side]:
		var old: Array = Array(_last_units[side].split(",")).map(func(x): return int(x))
		var on := ids.filter(func(x): return not old.has(x))
		var off := old.filter(func(x): return not ids.has(x))
		var stoppage: bool = _state.get("type", "") in ["whistle", "faceoff", "goal"]
		var team = League.get_team(teams[side])
		var parts := []
		for i in on.size():
			var pin := League.get_player(on[i])
			var pout := League.get_player(off[i]) if i < off.size() else null
			parts.append("#%s on%s" % [str(pin.number) if pin else "?", (" for #%s" % pout.number) if pout else ""])
		if not parts.is_empty():
			note = "%s %s: %s" % [team.name if team else "", "change" if stoppage else "change on the fly", ", ".join(parts)]
			note_until = _t + 4.0
	_last_units[side] = key


# ------------------------------------------------------------------ formations

## Target spot (feet) for every player of `side` on the ice now.
func _targets(side: int, units: Array, puck: Vector2) -> Dictionary:
	var out := {}
	var d := Choreographer.dir_for(side, _period)
	var poss: int = _state.get("side", -1)
	var kind: String = _state.get("type", "")
	var px := puck.x * d                 # puck in this team's attack frame
	var py := -puck.y * d
	var mine := units.size()
	var theirs: int = chor.visible_on_ice(1 - side, _t).filter(func(e): return not _boxed.has(int(e[0]))).size()
	var tac: Tactics = Game.tactics.get(teams[side])
	var spots := {}
	var stopped := kind in ["faceoff", "whistle", "goal"]
	for e in units:
		var spot: String = e[1]
		var pid := int(e[0])
		var f := Vector2.ZERO
		if stopped:
			f = _faceoff_spot(spot, px, py)
		elif poss == side:
			if mine > theirs and px > 20:
				f = _pp_spot(spot, tac.get_value("power_play.formation") if tac else 0, py)
				f += _sway(pid, 4.0)
			else:
				f = _attack_spot(spot, px, py, tac, units.find(e), side)
		elif poss == 1 - side:
			if mine < theirs and px < -20:
				f = _pk_spot(spot, tac.get_value("penalty_kill.formation") if tac else 0, py)
				f += _sway(pid, 2.5)
			else:
				if px < -25.0:
					f = _dzone_area(side, spot, pid, px, py, tac, d)
				else:
					f = _defend_spot(spot, px, py, tac)
		else:
			f = _faceoff_spot(spot, px, py)
		if not stopped:
			f += _sway(pid, 3.0)
		spots[pid] = f
	# The nearest defender pressures the puck carrier.
	if poss == 1 - side and kind in ["carry", "hold", "hit"]:
		var best := 0
		var best_d := INF
		for pid in spots:
			var dd: float = spots[pid].distance_to(Vector2(px, py))
			if dd < best_d:
				best_d = dd
				best = pid
		if best != 0:
			spots[best] = Vector2(px - 4.0, py + signf(-py + 0.01) * 2.5)
	# Hitter drives through the carrier.
	if kind == "hit":
		var hitter := int(_state.get("target", 0))
		if spots.has(hitter):
			spots[hitter] = Vector2(px, py)
	for pid in spots:
		var f: Vector2 = spots[pid]
		f.x = clampf(f.x, -94.0, 94.0)
		f.y = clampf(f.y, -38.0, 38.0)
		out[pid] = Vector2(f.x * d, -f.y * d)
	var g := chor.goalie(side)
	if g != 0:
		var net := Vector2(-88.0 * d, 0)
		var gp := net + Vector2(d * 1.5, clampf(puck.y * 0.15, -3.0, 3.0))
		if kind == "save" and int(_state.get("carrier", 0)) == g:
			gp = puck            # dives to smother it
		elif kind == "shot" and absf(puck.x - net.x) < 40.0:
			gp = net + Vector2(d * 4.0, clampf(puck.y * 0.2, -4.0, 4.0))   # challenges the shooter
		out[g] = gp
	return out


func units_pid_hash(spot: String, side: int) -> int:
	return hash(spot) + side * 7


## A target inside a player's area: his area's center, pulled toward what he
## should be doing (`attract`, weight w), plus a slow personal wander. Kept in
## the area (with a little give so he can cross over when the play needs it).
func _in_area(area: Rect2, attract: Vector2, w: float, seed_val: int) -> Vector2:
	var ph := float(seed_val % 997) * 0.53
	var c := area.get_center()
	var wander := Vector2(sin(_t * 0.45 + ph) * area.size.x * 0.32, cos(_t * 0.38 + ph * 1.3) * area.size.y * 0.32)
	var p := (c + wander).lerp(attract, w)
	var give := 5.0
	return Vector2(clampf(p.x, area.position.x - give, area.end.x + give), clampf(p.y, area.position.y - give, area.end.y + give))


## Offensive zone: wingers own their wing, the center the middle, the D the
## points. The puck-side winger battles low, the weak-side winger slides to
## the back door, D slide along the line toward the puck. Now and then the
## center and the strong-side winger swap areas.
func _ozone_area(spot: String, px: float, py: float, tac: Tactics, side: int, seed_val: int) -> Vector2:
	var structure := tac.get_value("o_zone.structure") if tac else 0
	var activate := tac.get_value("o_zone.d_activation") if tac else 1
	var s := signf(py + 0.01)
	var puck := Vector2(px, py)
	var areas := {
		"LW": Rect2(55, 6, 34, 30), "RW": Rect2(55, -36, 34, 30), "C": Rect2(60, -14, 26, 28),
		"LD": Rect2(27, 4, 12, 30), "RD": Rect2(27, -34, 12, 30),
	}
	if activate >= 2:
		var strong_d := "LD" if s > 0 else "RD"
		areas[strong_d] = Rect2(27, 6 * s if s > 0 else -36, 34, 30)
	# Occasional C <-> strong-side winger swap (a few seconds at a time).
	var strong_w := "LW" if s > 0 else "RW"
	var swap := hash([int((_t + float(side)) / 6.0), side]) % 4 == 0
	var my := spot
	if swap and spot == "C":
		my = strong_w
	elif swap and spot == strong_w:
		my = "C"
	var area: Rect2 = areas.get(my, areas["C"])
	var attract := area.get_center()
	var w := 0.35
	match my:
		"LW", "RW":
			var mine_side := 1.0 if my == "LW" else -1.0
			if signf(py + 0.01) == mine_side:
				attract = puck + Vector2(-6, -mine_side * 4)       # battle for it / support low
				w = 0.55
			else:
				attract = Vector2(82, mine_side * 5)              # back door
				if structure == 2:
					attract = Vector2(68, -mine_side * 10)         # overload: drift to the strong side
				w = 0.45
		"C":
			attract = Vector2(86, 0) if structure == 1 else Vector2(72, py * 0.3)
			w = 0.6 if structure == 1 else 0.4
		"LD", "RD":
			attract = Vector2(33, py * 0.7)
			w = 0.4
	return _in_area(area, attract, w, seed_val + int(_t / 30.0))


## Defensive zone: D take the low corners and the net front, the center the
## low slot, wingers their side's point. Each shadows the attacker in his area
## (tighter with man-to-man), and whoever is closest goes after the puck.
func _dzone_area(side: int, spot: String, pid: int, px: float, py: float, tac: Tactics, d: float) -> Vector2:
	var areas := {
		"LD": Rect2(-89, 0, 25, 24), "RD": Rect2(-89, -24, 25, 24), "C": Rect2(-82, -14, 24, 28),
		"LW": Rect2(-62, 6, 24, 30), "RW": Rect2(-62, -36, 24, 30),
	}
	var area: Rect2 = areas.get(spot, areas["C"])
	var system := tac.get_value("d_zone.system") if tac else 0
	var w: float = [0.5, 0.85, 0.65, 0.55][clampi(system, 0, 3)]
	# The attacker inside (or nearest to) this area.
	var best := Vector2.INF
	var best_d := INF
	for e in chor.visible_on_ice(1 - side, _t):
		var mid := int(e[0])
		if not _pos.has(mid):
			continue
		var mp: Vector2 = _pos[mid]
		var mf := Vector2(mp.x * d, -mp.y * d)
		var dd := mf.distance_to(area.get_center())
		if dd < best_d:
			best_d = dd
			best = mf
	var attract := Vector2(-80, 0)
	if best != Vector2.INF:
		attract = best + (Vector2(-89, 0) - best).normalized() * 5.0   # goal side of his man
	if area.grow(4).has_point(Vector2(px, py)):
		attract = Vector2(px, py)                                      # puck in my area: go get it
		w = 0.7
	if system == 3:
		attract = attract.lerp(Vector2(-78, 0), 0.3)                   # swarm collapses
	return _in_area(area, attract, w, pid)


## Small personal drift so nobody ever stands still.
func _sway(pid: int, amp: float) -> Vector2:
	var ph := float(pid % 997) * 0.37
	return Vector2(sin(_t * 0.8 + ph) * amp, cos(_t * 0.6 + ph * 1.7) * amp * 0.8)


## Defenders cover their man (goal-side), blended with zone positions per the
## coverage tactic: zone, man-to-man, hybrid or swarm.
func _cover(side: int, spot: String, zone_spot: Vector2, tac: Tactics, d: float) -> Vector2:
	var assign := {"LD": "RW", "RD": "LW", "C": "C", "LW": "RD", "RW": "LD"}
	var want: String = assign.get(spot, "C")
	var man := 0
	for e in chor.visible_on_ice(1 - side, _t):
		if e[1] == want:
			man = int(e[0])
	if man == 0 or not _pos.has(man):
		return zone_spot
	var mp: Vector2 = _pos[man]
	var mf := Vector2(mp.x * d, -mp.y * d)
	var goal_side := mf + (Vector2(-89, 0) - mf).normalized() * 5.0
	var system := tac.get_value("d_zone.system") if tac else 0
	var w: float = [0.45, 0.85, 0.65, 0.5][clampi(system, 0, 3)]
	if system == 3:
		zone_spot = zone_spot.lerp(Vector2(-78, 0), 0.4)
	return zone_spot.lerp(goal_side, w)


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


## Attacking positions. In the offensive zone the forwards rotate through the
## structure's three spots every few seconds (cycling, swapping, getting open)
## and the D walk the line; on the rush they fill lanes; in their own zone
## they set up the breakout.
func _attack_spot(spot: String, px: float, py: float, tac: Tactics, idx: int, side: int) -> Vector2:
	var structure := tac.get_value("o_zone.structure") if tac else 0
	if px > 25.0:
		return _ozone_area(spot, px, py, tac, side, int(units_pid_hash(spot, side)))
	elif px > -25.0:
		# Rush through the neutral zone; non-carriers stay onside until the puck is in.
		var lane := sin(_t * 0.5 + float(side)) * 4.0
		match spot:
			"LW":
				return Vector2(minf(px + 12, 23), 25 + lane)
			"RW":
				return Vector2(minf(px + 12, 23), -25 + lane)
			"C":
				return Vector2(px - 4, py * 0.4 + lane)
			"LD":
				return Vector2(px - 24, 12)
			"RD":
				return Vector2(px - 24, -12)
	else:
		# Breakout from their own zone: wingers on the wall, center swinging low.
		var swing := sin(_t * 0.9 + float(side)) * 8.0
		match spot:
			"LD":
				return Vector2(-80, 12)
			"RD":
				return Vector2(-80, -12)
			"C":
				return Vector2(-66 + swing * 0.5, swing)
			"LW":
				return Vector2(-52 + swing * 0.3, 32)
			"RW":
				return Vector2(-52 - swing * 0.3, -32)
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
	return minf((size.x - 20) / RINK_W, (size.y - 20) / (RINK_H + 18.0))


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
	# Benches (top) and penalty boxes (bottom), outside the boards.
	var small := AppTheme.font("caption")
	for side in 2:
		var tb = League.get_team(teams[side])
		var bx := -30.0 if side == 0 else 6.0
		var bench := Rect2(_to_px(Vector2(bx, -RINK_H / 2 - 8.5)), Vector2(24.0 * s, 6.5 * s))
		draw_rect(bench, Color(tb.primary if tb else Color.GRAY, 0.18))
		var changing := _leaving.values().has(side)
		draw_string(small, bench.position + Vector2(4, -4), ("LINE CHANGE" if changing else "BENCH") + "  " + (tb.id if tb else ""),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AppTheme.ACCENT if changing else Color("#7b8798"))
		var box := Rect2(_to_px(Vector2(-14.0 if side == 0 else 3.0, RINK_H / 2 + 2.0)), Vector2(11.0 * s, 6.5 * s))
		draw_rect(box, Color(AppTheme.RED, 0.12))
		draw_string(small, box.position + Vector2(2, box.size.y + 12), "PENALTY BOX", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#7b8798"))
	for pid in _boxed:
		var pen: Dictionary = _boxed[pid]
		var left := maxf(0.0, float(pen["t1"]) - _t)
		draw_string(small, _to_px(_box_spot(int(pen["side"]))) + Vector2(16, 5), "%d:%02d" % [int(left) / 60, int(left) % 60],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AppTheme.RED)
	# Players.
	var r := maxf(9.0, 2.6 * s)
	var font := AppTheme.font("display_bold")
	var carrier: int = int(_state.get("carrier", 0))
	for side in 2:
		var t = League.get_team(teams[side])
		var ring: Color = t.primary if t.primary.get_luminance() < 0.75 else t.secondary
		for pid in _pos:
			if _side_of(pid) != side:
				continue
			var c := _to_px(_pos[pid])
			var p := League.get_player(pid)
			var faded := _leaving.has(pid) or _boxed.has(pid)
			if faded:
				draw_circle(c, r * 0.8, Color(t.primary if side == 0 else Color.WHITE, 0.55))
				draw_arc(c, r * 0.8, 0, TAU, 24, Color(ring, 0.6), 1.5, true)
				draw_string(font, c + Vector2(-r, r * 0.3), str(p.number) if p else "", HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 0.85),
					Color(t.on_primary() if side == 0 else ring, 0.8))
				continue
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
	# Impact burst on a body check.
	if _state.get("type", "") == "hit":
		var victim := int(_state.get("carrier", 0))
		if _pos.has(victim):
			var c := _to_px(_pos[victim])
			for k in 8:
				var a := TAU * k / 8.0 + _t * 3.0
				draw_line(c + Vector2(cos(a), sin(a)) * (r + 3), c + Vector2(cos(a), sin(a)) * (r + 10), Color("#ffb020"), 2.5, true)
	# Whistle banner.
	if _state.get("type", "") == "whistle":
		var txt: String = str(_state.get("label", "Whistle")).replace("Whistle: ", "")
		var bw := 360.0
		var bpos := Vector2(size.x / 2 - bw / 2, _to_px(Vector2(0, -RINK_H / 2)).y + 10)
		draw_style_box(AppTheme.box(Color(0.05, 0.07, 0.12, 0.85), 10), Rect2(bpos, Vector2(bw, 30)))
		draw_string(AppTheme.font("semibold"), bpos + Vector2(0, 20), "WHISTLE  -  " + txt.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, bw, 13, Color.WHITE)
	# Puck and trail.
	for i in range(_trail.size() - 1, 0, -1):
		draw_circle(_to_px(_trail[i]), maxf(2.0, 0.8 * s) * (1.0 - i / 8.0), Color(0, 0, 0, 0.12 * (8 - i) / 8.0))
	if not _trail.is_empty():
		draw_circle(_to_px(_trail[0]), maxf(3.5, 1.0 * s), Color("#111111"))


func _belongs(pid: int, side: int) -> bool:
	if pid == chor.goalie(side):
		return true
	for e in chor.visible_on_ice(side, _t):
		if int(e[0]) == pid:
			return true
	return false
