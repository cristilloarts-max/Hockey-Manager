class_name Lineup
extends RefCounted
## Who dresses and where: 4 forward lines, 3 D pairs, 2 goalies,
## plus special-teams units. Slots hold player ids (0 = empty).

const FWD_SLOTS := ["LW", "C", "RW"]
const D_SLOTS := ["LD", "RD"]
const PP_SLOTS := ["LW", "C", "RW", "LD", "RD"]
const PK_SLOTS := ["F1", "F2", "LD", "RD"]

var forwards: Array = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]]
var defense: Array = [[0, 0], [0, 0], [0, 0]]
var goalies: Array = [0, 0]                   ## starter, backup
var power_play: Array = [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]
var penalty_kill: Array = [[0, 0, 0, 0], [0, 0, 0, 0]]
## Share of games the starting goalie plays (the backup gets the rest).
var starter_share := 0.72


func dressed_ids() -> Array:
	var ids := []
	for line in forwards:
		ids.append_array(line)
	for pair in defense:
		ids.append_array(pair)
	ids.append_array(goalies)
	return ids.filter(func(i): return i != 0)


func clear() -> void:
	forwards = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]]
	defense = [[0, 0], [0, 0], [0, 0]]
	goalies = [0, 0]
	power_play = [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]
	penalty_kill = [[0, 0, 0, 0], [0, 0, 0, 0]]


## Fill every empty slot with the best available player for that spot.
## Pass keep_existing = false to rebuild from scratch.
func auto_fill(players: Array, keep_existing: bool = true) -> void:
	if not keep_existing:
		clear()
	var used := {}
	for i in dressed_ids():
		used[i] = true
	var skaters := players.filter(func(p): return not p.is_goalie())
	var netminders := players.filter(func(p): return p.is_goalie())

	# Fill in order of importance so top lines get the best players.
	for line_idx in 4:
		for s in 3:
			if forwards[line_idx][s] == 0:
				forwards[line_idx][s] = _pick_best(skaters, FWD_SLOTS[s], used)
		if line_idx < 3:
			for s in 2:
				if defense[line_idx][s] == 0:
					defense[line_idx][s] = _pick_best(skaters, D_SLOTS[s], used)

	netminders.sort_custom(func(a, b): return a.overall > b.overall)
	for g in netminders:
		if used.has(g.id):
			continue
		if goalies[0] == 0:
			goalies[0] = g.id
		elif goalies[1] == 0:
			goalies[1] = g.id
		used[g.id] = true

	_auto_special_teams(players)


func _pick_best(pool: Array, spot: String, used: Dictionary) -> int:
	var best = null
	var best_score := -1.0
	for p in pool:
		if used.has(p.id):
			continue
		var score: float = p.lineup_score(spot)
		if p.on_preferred_side(spot):
			score += 1.0
		if score > best_score:
			best_score = score
			best = p
	if best == null:
		return 0
	used[best.id] = true
	return best.id


## Builds PP and PK units from whoever is dressed.
func _auto_special_teams(players: Array) -> void:
	var by_id := {}
	for p in players:
		by_id[p.id] = p
	var dressed_f := []
	var dressed_d := []
	for line in forwards:
		for i in line:
			if by_id.has(i):
				dressed_f.append(by_id[i])
	for pair in defense:
		for i in pair:
			if by_id.has(i):
				dressed_d.append(by_id[i])

	var off := func(p): return p.attr("shooting") + p.attr("passing") + p.attr("offense_iq") + p.attr("puck_handling")
	var def := func(p): return p.attr("defense") * 2 + p.attr("offense_iq") + p.attr("skating")

	var f_off := dressed_f.duplicate()
	f_off.sort_custom(func(a, b): return off.call(a) > off.call(b))
	var d_off := dressed_d.duplicate()
	d_off.sort_custom(func(a, b): return off.call(a) > off.call(b))
	var f_def := dressed_f.duplicate()
	f_def.sort_custom(func(a, b): return def.call(a) > def.call(b))
	var d_def := dressed_d.duplicate()
	d_def.sort_custom(func(a, b): return def.call(a) > def.call(b))

	for u in 2:
		var fs := f_off.slice(u * 3, u * 3 + 3)
		var ds := d_off.slice(u * 2, u * 2 + 2)
		var unit := [0, 0, 0, 0, 0]
		for k in fs.size():
			unit[k] = fs[k].id
		for k in ds.size():
			unit[3 + k] = ds[k].id
		power_play[u] = unit
		var pk := [0, 0, 0, 0]
		var pf := f_def.slice(u * 2, u * 2 + 2)
		var pd := d_def.slice(u * 2, u * 2 + 2)
		for k in pf.size():
			pk[k] = pf[k].id
		for k in pd.size():
			pk[2 + k] = pd[k].id
		penalty_kill[u] = pk


## Human-readable problems: empty slots, players dressed twice, a missing goalie.
func problems() -> Array:
	var out := []
	var seen := {}
	for i in dressed_ids():
		if seen.has(i):
			var p = League.get_player(i)
			out.append("%s is in the lineup twice" % (p.full_name() if p else str(i)))
		seen[i] = true
	for l in 4:
		if forwards[l].has(0):
			out.append("Forward line %d has an empty spot" % (l + 1))
	for d in 3:
		if defense[d].has(0):
			out.append("D pair %d has an empty spot" % (d + 1))
	if goalies[0] == 0:
		out.append("No starting goalie")
	return out


func to_dict() -> Dictionary:
	return {"forwards": forwards, "defense": defense, "goalies": goalies,
		"power_play": power_play, "penalty_kill": penalty_kill, "starter_share": starter_share}


static func from_dict(d: Dictionary) -> Lineup:
	var l := Lineup.new()
	l.forwards = _ints2(d["forwards"])
	l.defense = _ints2(d["defense"])
	l.goalies = d["goalies"].map(func(x): return int(x))
	l.power_play = _ints2(d.get("power_play", l.power_play))
	l.penalty_kill = _ints2(d.get("penalty_kill", l.penalty_kill))
	l.starter_share = float(d.get("starter_share", 0.72))
	return l


## Removes players who are no longer eligible (traded, sent to the reserve list).
func drop_ineligible(players: Array) -> void:
	var ok := {}
	for p in players:
		ok[p.id] = true
	for group in [forwards, defense, power_play, penalty_kill]:
		for unit in group:
			for k in unit.size():
				if unit[k] != 0 and not ok.has(unit[k]):
					unit[k] = 0
	for k in goalies.size():
		if goalies[k] != 0 and not ok.has(goalies[k]):
			goalies[k] = 0


static func _ints2(a: Array) -> Array:
	return a.map(func(row): return row.map(func(x): return int(x)))
