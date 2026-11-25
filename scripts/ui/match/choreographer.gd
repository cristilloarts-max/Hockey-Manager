class_name Choreographer
extends RefCounted
## Turns a simulated game (its shots, goals, penalties and shifts at exact
## times) into continuous on-ice play for the rink visualizer: faceoffs,
## breakouts, zone entries, passing, shots, saves, rebounds, turnovers,
## icings and goals. Every real event lands at its real time; the play in
## between is generated to lead up to it, shaped by each team's tactics.
##
## Coordinates are in feet: x -100..100 (left to right), y -42.5..42.5 (top
## to bottom). Each team has an "attack frame" where +X points at the net it
## shoots at and +Y is its left wing.
##
## Action: {t0, t1, type, from: Vector2, to: Vector2, side (0 home, 1 away,
##          -1 none), carrier: pid, target: pid, label: String}

const NET_X := 89.0
const BLUE_X := 25.0

var actions: Array = []
## Players in the penalty box: {pid, side, t0, t1}.
var penalties: Array = []
var _res: Dictionary
var _teams := ["", ""]
var _shifts: Array = []      ## [t, home units, away units]
var _goalies := [0, 0]
var _period_ends: Array = []
var _rng := RandomNumberGenerator.new()

# Builder state.
var _t := 0.0
var _pos := Vector2.ZERO
var _side := -1
var _carrier := 0
var _period := 1


func build(res: Dictionary, period_ends: Array) -> void:
	_res = res
	_teams = [res["home"], res["away"]]
	_period_ends = period_ends
	_rng.seed = hash([res["home"], res["away"], res["home_goals"], res["away_goals"], res["home_shots"]])
	for gid in res["goalies"]:
		var gl: Dictionary = res["goalies"][gid]
		_goalies[0 if gl["team"] == _teams[0] else 1] = int(gid)
	var keys := []
	for e in res["events"]:
		match e["type"]:
			"shift":
				_shifts.append([float(e["t"]), e["home"], e["away"]])
			"shot", "penalty":
				keys.append(e)
	keys.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	var start := 0.0
	for p in period_ends.size():
		_period = p + 1
		var end := float(period_ends[p])
		_t = maxf(_t, start)   # keep the timeline in order if the last period ran long
		_pos = Vector2.ZERO
		_side = -1
		_faceoff(Vector2.ZERO, "Opening faceoff" if p == 0 else "Start of period %d" % (p + 1))
		for k in keys:
			var kt := float(k["t"])
			if kt <= start or kt > end + 0.01:
				continue
			if k["type"] == "penalty":
				_penalty(k)
			else:
				_play_to_shot(k)
		_filler(end)
		start = end


# ------------------------------------------------------------------ queries

## State at game time t: puck position, possessing side, carrier, action.
func state_at(t: float) -> Dictionary:
	if actions.is_empty():
		return {"puck": Vector2.ZERO, "side": -1, "carrier": 0, "target": 0, "type": "", "label": ""}
	var lo := 0
	var hi := actions.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if float(actions[mid]["t0"]) <= t:
			lo = mid
		else:
			hi = mid - 1
	var a: Dictionary = actions[lo]
	var span := maxf(0.001, float(a["t1"]) - float(a["t0"]))
	var f := clampf((t - float(a["t0"])) / span, 0.0, 1.0)
	var from: Vector2 = a["from"]
	var to: Vector2 = a["to"]
	var puck := from.lerp(to, f)
	if a["type"] in ["dump", "shot", "goal", "pass", "rebound"]:
		# Slight arc for passes and dumps along the boards.
		puck = from.lerp(to, f * f * (3.0 - 2.0 * f))
	var carrier: int = a["carrier"]
	if a["type"] in ["pass", "dump", "shot", "rebound"] and f > 0.05:
		carrier = 0
	if a["type"] == "pass" and f >= 1.0:
		carrier = a["target"]
	return {"puck": puck, "side": a["side"], "carrier": carrier, "target": a["target"], "type": a["type"],
		"label": a["label"], "t0": a["t0"]}


## Who's on the ice for a side at time t: [[pid, spot], ...].
func on_ice(side: int, t: float) -> Array:
	if _shifts.is_empty():
		return []
	var lo := 0
	var hi := _shifts.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if float(_shifts[mid][0]) <= t:
			lo = mid
		else:
			hi = mid - 1
	return _shifts[lo][1 + side]


func goalie(side: int) -> int:
	return _goalies[side]


## +1 if `side` attacks to the right in this period (teams switch ends).
static func dir_for(side: int, period: int) -> float:
	var home_dir := 1.0 if period % 2 == 1 else -1.0
	return home_dir if side == 0 else -home_dir


func period_at(t: float) -> int:
	for i in _period_ends.size():
		if t <= float(_period_ends[i]):
			return i + 1
	return _period_ends.size()


# ------------------------------------------------------------------ frames

func _dir(side: int) -> float:
	return dir_for(side, _period)


## Attack-frame point (X toward their target net, Y = their left) to world.
func _w(side: int, x: float, y: float) -> Vector2:
	var d := _dir(side)
	return Vector2(x * d, -y * d)


func _fx(side: int, world: Vector2) -> float:
	return world.x * _dir(side)


func _fy(side: int, world: Vector2) -> float:
	return -world.y * _dir(side)


func _player(side: int, spots: Array) -> int:
	var units := on_ice(side, _t)
	for s in spots:
		for e in units:
			if e[1] == s:
				return int(e[0])
	return int(units[0][0]) if not units.is_empty() else 0


func _random_mate(side: int, except_pid: int) -> int:
	var units := on_ice(side, _t).filter(func(e): return int(e[0]) != except_pid)
	if units.is_empty():
		return except_pid
	return int(units[_rng.randi_range(0, units.size() - 1)][0])


func _name(pid: int) -> String:
	var p := League.get_player(pid)
	return p.short_name() if p else ""


func _tac(side: int, key: String) -> int:
	var t: Tactics = Game.tactics.get(_teams[side])
	return t.get_value(key) if t else 0


# ------------------------------------------------------------------ emitting

func _emit(type: String, dur: float, to: Vector2, side: int, carrier: int, target: int = 0, label: String = "") -> void:
	dur = maxf(0.05, dur)
	actions.append({"t0": _t, "t1": _t + dur, "type": type, "from": _pos, "to": to, "side": side,
		"carrier": carrier, "target": target, "label": label})
	_t += dur
	_pos = to
	_side = side if side >= 0 else _side
	if type == "pass":
		_carrier = target
	elif type in ["carry", "hold", "faceoff", "hit"]:
		_carrier = carrier
	else:
		_carrier = 0


# ------------------------------------------------------------------ building blocks

## Faceoff at a dot; the better faceoff man (more often) wins it back to a D.
func _faceoff(dot: Vector2, label: String = "Faceoff") -> void:
	_pos = dot
	var c := [_player(0, ["C"]), _player(1, ["C"])]
	var w := []
	for i in 2:
		var p := League.get_player(c[i])
		w.append(pow(float(p.detail("faceoffs")) if p else 10.0, 2))
	var win := 0 if _rng.randf() * (w[0] + w[1]) < w[0] else 1
	_emit("faceoff", 1.2, dot, -1, 0, 0, label)
	var d_pid := _player(win, ["LD", "RD"])
	var back := _w(win, _fx(win, dot) - 16.0, _fy(win, dot) + _rng.randf_range(-10, 10))
	_emit("pass", 0.8, back, win, c[win], d_pid, "%s wins the faceoff" % _name(c[win]))
	_side = win


func _faceoff_in_zone(defending_side: int, y_sign: float, label: String) -> void:
	_faceoff(_w(defending_side, -69.0, 22.0 * y_sign), label)


## The team with the puck loses it to `to_side` (turnover, dump-in or takeaway).
func _lose_puck(to_side: int, budget: float) -> void:
	var p_side := 1 - to_side
	var fx := _fx(p_side, _pos)
	var y := _fy(p_side, _pos)
	var carrier := _carrier if _carrier != 0 else _player(p_side, ["C"])
	if fx < -BLUE_X:
		# Breakout pass picked off.
		var thief := _player(to_side, ["LW", "RW", "C"])
		var spot := _w(p_side, -48.0, signf(y + 0.01) * 26.0)
		_emit("pass", minf(1.0, budget), spot, p_side, carrier, thief, "")
		actions[-1]["target"] = thief
		actions[-1]["label"] = "Turnover! %s picks it off" % _name(thief)
		_side = to_side
		_carrier = thief
	elif fx < BLUE_X:
		# Dumped in; the other team's D retrieves.
		var corner := _w(p_side, 84.0, -signf(y + 0.01) * 30.0)
		_emit("dump", minf(1.4, budget * 0.5), corner, p_side, carrier, 0, "Dump in")
		var d := _player(to_side, ["LD", "RD"])
		_emit("hold", minf(1.4, budget * 0.5), corner, to_side, d, 0, "%s retrieves" % _name(d))
	else:
		var d := _player(to_side, ["LD", "RD", "C"])
		var spot := _pos + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
		_emit("hold", minf(1.0, budget), spot, to_side, d, 0, "Takeaway by %s" % _name(d))


## Generic possession play until `until` (no shots): breakouts, dumps,
## icings, offsides and turnovers.
func _filler(until: float) -> void:
	var guard := 0
	while _t < until - 2.5 and guard < 60:
		guard += 1
		var side := _side if _side >= 0 else 0
		var left := until - _t
		var fx := _fx(side, _pos)
		var y := _fy(side, _pos)
		var carrier := _carrier if _carrier != 0 else _player(side, ["LD", "RD"])
		if fx < -BLUE_X:
			# Breakout up the wall, then carry to the red line.
			var wing_y := 28.0 if _rng.randf() < 0.5 else -28.0
			var wing := _player(side, ["LW"] if wing_y > 0 else ["RW"])
			_emit("pass", minf(1.1, left * 0.25), _w(side, -52.0, wing_y), side, carrier, wing, "Breakout")
			_emit("carry", minf(3.2, left * 0.5), _w(side, 2.0, wing_y * 0.7), side, wing)
			continue
		var roll := _rng.randf()
		if fx < BLUE_X:
			var style := _tac(side, "entry.style")
			if roll < 0.07:
				# Offside: the winger crosses the line ahead of the puck.
				_emit("carry", minf(1.6, left * 0.3), _w(side, 27.0, y * 0.6), side, carrier)
				_emit("whistle", 2.0, _pos, -1, 0, 0, "Whistle: offside")
				_faceoff(_w(side, 20.0, 22.0 if _rng.randf() < 0.5 else -22.0), "Neutral-zone faceoff after offside")
				continue
			if roll < 0.12:
				# Open-ice hit in the neutral zone knocks the puck loose.
				_hit(side, carrier, true)
				continue
			if roll < 0.24:
				# Icing: fired the length of the ice from behind the red line.
				_emit("dump", minf(1.6, left * 0.4), _w(side, NET_X, _rng.randf_range(-12, 12)), side, carrier, 0, "Icing")
				_emit("whistle", 2.0, _pos, -1, 0, 0, "Whistle: icing on the %s" % League.get_team(_teams[side]).name)
				_faceoff_in_zone(side, 1.0 if _rng.randf() < 0.5 else -1.0, "Faceoff after icing")
			elif roll < 0.55 or style in [1, 2]:
				var corner := _w(side, 84.0, -signf(y + 0.01) * 30.0)
				_emit("dump", minf(1.4, left * 0.35), corner, side, carrier, 0,
					"Dump and chase" if style == 1 else ("Chip and chase" if style == 2 else "Dump in"))
				var chase := _rng.randf() < (0.45 if style in [1, 2] else 0.3)
				if not chase and _rng.randf() < 0.18:
					# The goalie comes out to play it behind the net.
					var gk := goalie(1 - side)
					var behind := _w(side, 92.0, _rng.randf_range(-8, 8))
					_emit("hold", 1.0, behind, 1 - side, gk, 0, "%s stops it behind the net" % _name(gk))
					if _rng.randf() < 0.35:
						_emit("whistle", 1.8, behind, -1, 0, 0, "Whistle: %s freezes it" % _name(gk))
						_faceoff_in_zone(1 - side, 1.0 if _rng.randf() < 0.5 else -1.0, "Faceoff after the goalie freeze")
					else:
						var dd := _player(1 - side, ["LD", "RD"])
						_emit("pass", 0.7, _w(1 - side, -80.0, _rng.randf_range(-14, 14)), 1 - side, gk, dd, "%s moves it to %s" % [_name(gk), _name(dd)])
					continue
				if chase:
					var f := _player(side, ["C", "LW", "RW"])
					_emit("hold", minf(1.4, left * 0.35), corner + Vector2(_rng.randf_range(-3, 3), 0), side, f, 0,
						"%s wins the race to the puck" % _name(f))
					_cycle(side, minf(_t + _rng.randf_range(3.0, 6.0), until - 1.0))
					_lose_puck(1 - side, 1.4)
				else:
					var d := _player(1 - side, ["LD", "RD"])
					_emit("hold", minf(1.4, left * 0.35), corner, 1 - side, d,
						0, "%s retrieves%s" % [_name(d), _forecheck_note(side)])
					# Forecheckers finish their checks (more with aggressive systems).
					var fc := _tac(side, "forecheck.system")
					if _rng.randf() < (0.5 if fc in [1, 4] else 0.3):
						_hit(1 - side, d, _rng.randf() < 0.35)
					elif _rng.randf() < 0.1:
						_emit("dump", 1.2, _w(1 - side, 40.0, 41.0 * signf(_rng.randf() - 0.5)), 1 - side, d, 0, "Puck over the glass")
						_emit("whistle", 2.0, _pos, -1, 0, 0, "Whistle: puck out of play")
						_faceoff_in_zone(1 - side, 1.0 if _rng.randf() < 0.5 else -1.0, "Defensive-zone faceoff")
			else:
				_emit("carry", minf(2.2, left * 0.4), _w(side, 40.0, y * 0.8), side, carrier, 0, "Zone entry")
				_cycle(side, minf(_t + _rng.randf_range(2.0, 5.0), until - 1.0))
				_lose_puck(1 - side, 1.2)
		else:
			_cycle(side, minf(_t + _rng.randf_range(2.0, 4.0), until - 1.0))
			_lose_puck(1 - side, 1.2)
	if _t < until:
		var side := _side if _side >= 0 else 0
		_emit("carry", until - _t, _pos + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-4, 4)), side,
			_carrier if _carrier != 0 else _player(side, ["C"]))


## A body check on `victim` (of `victim_side`). If `loose`, the puck squirts
## free and the hitting team takes it; otherwise he absorbs it and keeps it.
func _hit(victim_side: int, victim: int, loose: bool) -> void:
	var hitters := on_ice(1 - victim_side, _t)
	if hitters.is_empty() or victim == 0:
		return
	var weights := []
	for e in hitters:
		var hp := League.get_player(int(e[0]))
		weights.append(pow(float(hp.detail("body_checking")) if hp else 8.0, 2))
	var total := 0.0
	for w in weights:
		total += w
	var r := _rng.randf() * total
	var hitter := int(hitters[0][0])
	for i in weights.size():
		r -= weights[i]
		if r <= 0:
			hitter = int(hitters[i][0])
			break
	var hp2 := League.get_player(hitter)
	var big := hp2 != null and hp2.detail("body_checking") >= 14
	var label := "%s %s %s" % [_name(hitter), "lays out" if big else "finishes his check on", _name(victim)]
	if big:
		label = "BIG HIT! " + label
	_emit("hit", 0.7, _pos, victim_side, victim, hitter, label)
	if loose:
		var spot := _pos + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-5, 5))
		_emit("rebound", 0.5, spot, 1 - victim_side, 0, 0, "Puck knocked loose")
		_emit("hold", 0.6, spot, 1 - victim_side, hitter, 0, "%s comes away with it" % _name(hitter))
	else:
		_emit("carry", 0.5, _pos, victim_side, victim, 0, "%s absorbs the hit and keeps it" % _name(victim))


func _forecheck_note(attacking_side: int) -> String:
	match _tac(attacking_side, "forecheck.system"):
		1:
			return "  (2-1-2 forecheck pressure)"
		2:
			return "  (left-wing lock)"
		3:
			return "  (1-3-1)"
		4:
			return "  (all-out forecheck)"
	return ""


## Passing around the offensive zone until `until`.
func _cycle(side: int, until: float) -> void:
	var guard := 0
	while _t < until - 0.6 and guard < 12:
		guard += 1
		var holder := _carrier if _carrier != 0 else _player(side, ["C"])
		var mate := _random_mate(side, holder)
		var p := League.get_player(mate)
		var spot := _zone_spot(side, p, mate)
		_emit("pass", 0.7, spot, side, holder, mate)
		if _rng.randf() < 0.18 and until - _t > 1.5:
			_hit(side, mate, false)
		var hold := minf(_rng.randf_range(0.5, 1.6), maxf(0.1, until - _t))
		_emit("carry", hold, spot + _w(side, _rng.randf_range(-3, 3), _rng.randf_range(-3, 3)) - _w(side, 0, 0), side, mate)


## Where a player stands in the offensive zone (by spot and tactics).
func _zone_spot(side: int, p: Player, pid: int) -> Vector2:
	var spot := "C"
	for e in on_ice(side, _t):
		if int(e[0]) == pid:
			spot = e[1]
	var structure := _tac(side, "o_zone.structure")
	match spot:
		"LD":
			return _w(side, 31.0, 17.0)
		"RD":
			return _w(side, 31.0, -17.0)
		"LW":
			return _w(side, 78.0 if structure == 0 else 62.0, 26.0)
		"RW":
			return _w(side, 78.0 if structure == 0 else 62.0, -26.0)
	return _w(side, 70.0 if structure != 1 else 82.0, _rng.randf_range(-8, 8))


## Where this shooter shoots from.
func _shot_spot(side: int, pid: int, spot: String, pp: bool) -> Vector2:
	var p := League.get_player(pid)
	match spot:
		"LD":
			return _w(side, 33.0, 15.0)
		"RD":
			return _w(side, 33.0, -15.0)
		"LW", "RW":
			var y := 18.0 if spot == "LW" else -18.0
			if p != null and p.prefers_off_side and pp:
				return _w(side, 60.0, y * 1.2)   # off-wing one-timer spot
			return _w(side, _rng.randf_range(60.0, 72.0), y * _rng.randf_range(0.5, 1.0))
	return _w(side, _rng.randf_range(68.0, 80.0), _rng.randf_range(-7, 7))


## Build the play that ends in this shot at its exact time.
func _play_to_shot(e: Dictionary) -> void:
	var ts := float(e["t"])
	var side := 0 if e["team"] == _teams[0] else 1
	var shooter := int(e.get("pid", 0))
	var spot: String = e.get("spot", "C")
	var pp: bool = e.get("pp", false)
	if ts - _t > 26.0:
		_filler(ts - 18.0)
	if _side != side:
		var budget := clampf((ts - _t) * 0.25, 0.3, 2.4)
		_lose_puck(side, budget)
	var target := _shot_spot(side, shooter, spot, pp)
	var avail := ts - _t
	if avail > 9.0:
		var fx := _fx(side, _pos)
		var carrier := _carrier if _carrier != 0 else _player(side, ["LD", "RD"])
		if fx < -BLUE_X:
			var wing_y := 28.0 if _rng.randf() < 0.5 else -28.0
			var wing := _player(side, ["LW"] if wing_y > 0 else ["RW"])
			_emit("pass", 1.0, _w(side, -52.0, wing_y), side, carrier, wing, "Breakout")
			_emit("carry", minf(3.0, avail * 0.2), _w(side, 8.0, wing_y * 0.6), side, wing)
			carrier = wing
		if _fx(side, _pos) < BLUE_X and ts - _t > 5.0:
			var style := _tac(side, "entry.style")
			if pp:
				_emit("carry", 2.0, _w(side, 40.0, _fy(side, _pos) * 0.5), side, carrier, 0, _pp_label(side))
			elif style in [1, 2] and ts - _t > 7.0:
				var corner := _w(side, 84.0, 30.0 if _rng.randf() < 0.5 else -30.0)
				_emit("dump", 1.3, corner, side, carrier, 0, "Dump and chase" if style == 1 else "Chip and chase")
				var f := _player(side, ["C", "LW", "RW"])
				_emit("hold", 1.3, corner, side, f, 0, "%s wins the race to the puck" % _name(f))
			elif style == 3:
				var c := _player(side, ["C"])
				_emit("pass", 0.6, _pos + _w(side, -6, 0) - _w(side, 0, 0), side, carrier, c, "Drop pass")
				_emit("carry", 1.8, _w(side, 40.0, 0.0), side, c, 0, "Zone entry")
			else:
				_emit("carry", 2.0, _w(side, 40.0, _fy(side, _pos) * 0.7), side, carrier, 0, "Zone entry")
		_cycle(side, ts - 1.4)
	# Set up the shooter and shoot.
	var holder := _carrier if _carrier != 0 else _player(side, ["C"])
	var setup := maxf(0.1, ts - _t - 0.1)
	if holder != shooter and shooter != 0:
		var one_timer: bool = e.get("shot", "") == "one-timer"
		_emit("pass", minf(0.8, setup), target, side, holder, shooter, "Pass to %s" % _name(shooter) if not one_timer else "Feed for the one-timer")
	elif _pos.distance_to(target) > 1.0:
		_emit("carry", setup, target, side, shooter)
	_t = maxf(_t, ts)
	var net := _w(side, NET_X, _rng.randf_range(-2.5, 2.5))
	var shot_label := "%s %s" % [_name(shooter), e.get("shot", "shot")]
	if e.get("goal", false):
		_emit("shot", 0.3, net, side, shooter, 0, shot_label)
		_emit("goal", 2.4, net + _w(side, 1.5, 0) - _w(side, 0, 0), side, 0, shooter, "GOAL!")
		_faceoff(Vector2.ZERO, "Center-ice faceoff")
	else:
		var g := goalie(1 - side)
		var gpos := _w(side, NET_X - 3.0, _fy(side, net) * 0.5)
		_emit("shot", 0.3, gpos, side, shooter, 0, shot_label)
		if _rng.randf() < 0.45:
			_emit("save", 0.8, gpos, 1 - side, g, 0, "%s smothers the puck" % _name(g))
			_emit("whistle", 1.8, gpos, -1, 0, 0, "Whistle: %s covers it up" % _name(g))
			_faceoff_in_zone(1 - side, signf(_fy(1 - side, target) + 0.01), "Faceoff after the save")
		else:
			var reb := _w(side, NET_X - 12.0, _rng.randf_range(-14, 14))
			_emit("rebound", 0.5, reb, 1 - side, 0, 0, "Save by %s" % _name(g))
			var d := _player(1 - side, ["LD", "RD"])
			_emit("hold", 0.8, reb, 1 - side, d, 0, "%s clears the rebound" % _name(d))


func _pp_label(side: int) -> String:
	var names := ["1-3-1 power play", "Umbrella power play", "Overload power play", "Spread power play", "2-1-2 power play"]
	return "%s sets up the %s" % [League.get_team(_teams[side]).name, names[clampi(_tac(side, "power_play.formation"), 0, 4)]]


func _penalty(e: Dictionary) -> void:
	var pt := float(e["t"])
	var pen_side := 0 if e["team"] == _teams[0] else 1
	var t_end := pt + 120.0
	for g in _res["events"]:
		if g["type"] == "goal" and g["team"] != e["team"] and float(g["t"]) > pt and float(g["t"]) < t_end:
			t_end = float(g["t"])
			break
	penalties.append({"pid": int(e.get("pid", 0)), "side": pen_side, "t0": pt, "t1": t_end})
	if pt - _t > 1.5:
		_filler(pt)
	_t = maxf(_t, pt)
	var side := 0 if e["team"] == _teams[0] else 1
	_emit("whistle", 2.5, _pos, -1, 0, 0, "Whistle: " + str(e.get("text", "Penalty")))
	_faceoff_in_zone(side, 1.0 if _rng.randf() < 0.5 else -1.0, "Faceoff, %s short-handed" % League.get_team(_teams[side]).name)
