class_name MatchSim
extends RefCounted
## Shift-based game simulation.
##
## A game is a series of 40-second segments. In each one, both teams' units on
## the ice are compared: attack ratings vs the opponent's defense ratings
## decide how many shots each side gets (Poisson), and each shot is the
## shooter vs the goalie. All ratings pass through position familiarity and
## side preference. Base rates are normalised against league averages
## (League.norms), so an average vs average game lands near NHL numbers:
## ~30 shots and ~3 goals per team, ~3 power plays each.

const SEGMENT := 40
const OT_SEGMENT := 30
const BASE_SHOTS_PER_SEC := 29.0 / 3600.0
## Calibrated with tools/sim_calibration.py over full seasons: ~6.1 goals/game,
## .900 sv%, ~19% PP, 1-4 100-point players, 40-goal leaders around 45-54,
## starting goalies ~65-72 GP, standings ~60-120 points.
## How strongly unit rating gaps swing shot generation.
const RATING_EXP := 0.6
## How strongly goalie quality swings save percentage.
const GOALIE_EXP := 0.5
## Overall scoring level (scales every shot's goal chance).
const SH_SCALE := 0.87
## Share of a shooter's goal chance taken from his real shooting % (rest from ratings).
const TENDENCY_WEIGHT := 0.6
## Shot and assist shares follow real per-60 rates raised to these powers.
const SHOT_WEIGHT_EXP := 0.85
const ASSIST_EXP := 1.4
const PENALTIES_PER_SEC := 3.2 / 3600.0
const F_LINE_SHARE := [0.31, 0.28, 0.23, 0.18]
const D_PAIR_SHARE := [0.38, 0.34, 0.28]
const PENALTY_TYPES := ["tripping", "hooking", "slashing", "holding", "interference",
	"roughing", "high-sticking", "cross-checking", "delay of game", "too many men"]

var rng: RandomNumberGenerator
var playoff := false
var sides := []          ## [home side, away side] dictionaries
var events := []
var stats := {}          ## pid -> skater line
var goalie_stats := {}   ## pid -> goalie line
var clock := 0           ## seconds elapsed in regulation/OT
var period := 1
var period_scores := []
var game_over := false
var ot_kind := ""


## Plays one game. Returns a result Dictionary (see _result()).
static func play(home_team, away_team, home_lineup, away_lineup, home_tac, away_tac,
		seed: int, is_playoff: bool = false) -> Dictionary:
	var sim := MatchSim.new()
	sim.rng = RandomNumberGenerator.new()
	sim.rng.seed = seed
	sim.playoff = is_playoff
	sim.sides = [sim._make_side(home_team, home_lineup, home_tac),
		sim._make_side(away_team, away_lineup, away_tac)]
	sim._run()
	return sim._result()


# ------------------------------------------------------------------ setup

func _make_side(team, lineup, tac) -> Dictionary:
	var f_lines := []
	for line in lineup.forwards:
		var unit := []
		for s in 3:
			var p = League.get_player(line[s])
			if p != null:
				unit.append({"p": p, "spot": Lineup.FWD_SLOTS[s]})
		f_lines.append(unit)
	var d_pairs := []
	for pair in lineup.defense:
		var unit := []
		for s in 2:
			var p = League.get_player(pair[s])
			if p != null:
				unit.append({"p": p, "spot": Lineup.D_SLOTS[s]})
		d_pairs.append(unit)
	var pp_units := []
	for u in lineup.power_play:
		var unit := []
		for s in 5:
			var p = League.get_player(u[s])
			if p != null:
				unit.append({"p": p, "spot": Lineup.PP_SLOTS[s]})
		pp_units.append(unit)
	var pk_units := []
	for u in lineup.penalty_kill:
		var unit := []
		for s in 4:
			var p = League.get_player(u[s])
			if p != null:
				var spot: String = ["C", "LW", "LD", "RD"][s]
				unit.append({"p": p, "spot": spot})
		pk_units.append(unit)
	var goalie = League.get_player(lineup.goalies[0])
	var all_ids: Array = lineup.dressed_ids()
	for pid in all_ids:
		var p = League.get_player(pid)
		if p == null:
			continue
		if p.is_goalie():
			if p == goalie:
				goalie_stats[pid] = {"team": team.id, "sa": 0, "ga": 0, "toi": 0, "decision": ""}
		else:
			_sl(p, team.id)
	return {
		"team": team, "tac": tac, "mods": tac.modifiers(),
		"f_lines": f_lines, "d_pairs": d_pairs, "pp_units": pp_units, "pk_units": pk_units,
		"goalie": goalie, "goalie_pulled": false,
		"f_used": [0, 0, 0, 0], "d_used": [0, 0, 0],
		"penalties": [],     # expiry clock times of active minors
		"goals": 0, "shots": 0, "pp_goals": 0, "pp_opps": 0,
	}


# ------------------------------------------------------------------ main loop

func _run() -> void:
	for p in 3:
		period = p + 1
		var start_goals := [sides[0]["goals"], sides[1]["goals"]]
		_play_period(1200, false)
		period_scores.append([sides[0]["goals"] - start_goals[0], sides[1]["goals"] - start_goals[1]])
		_log(-1, "end", "End of period %d. %s %d, %s %d." % [period,
			sides[0]["team"].id, sides[0]["goals"], sides[1]["team"].id, sides[1]["goals"]])

	if sides[0]["goals"] != sides[1]["goals"]:
		_finish("")
		return

	if playoff:
		# Playoff overtime: full 20-minute 5-on-5 periods until someone scores.
		while not game_over:
			period += 1
			var before := [sides[0]["goals"], sides[1]["goals"]]
			_play_period(1200, true)
			period_scores.append([sides[0]["goals"] - before[0], sides[1]["goals"] - before[1]])
		_finish("OT")
		return

	# Regular season: 5 minutes of 3-on-3, then a shootout.
	period = 4
	for s in sides:
		s["penalties"].clear()
		s["goalie_pulled"] = false
	var before := [sides[0]["goals"], sides[1]["goals"]]
	_play_overtime()
	period_scores.append([sides[0]["goals"] - before[0], sides[1]["goals"] - before[1]])
	if game_over:
		_finish("OT")
	else:
		_shootout()
		_finish("SO")


func _play_period(length: int, sudden_death: bool) -> void:
	var period_start := clock
	var t := 0
	while t < length and not game_over:
		var seg := mini(SEGMENT, length - t)
		var time_left := length - t
		_update_goalie_pull(time_left)
		_play_segment(seg, t, period_start, sudden_death, false)
		t += seg
		clock = period_start + t
	clock = period_start + length


func _play_overtime() -> void:
	var t := 0
	var line_idx := 0
	while t < 300 and not game_over:
		var units := []
		for s in sides:
			var f: Array = s["f_lines"][line_idx % 3]
			var d: Array = s["d_pairs"][line_idx % 3]
			var unit := f.slice(0, 2)
			if d.size() > 0:
				unit.append(d[0])
			units.append(unit)
		_resolve(units, [3, 3], OT_SEGMENT, t, clock, true, true)
		t += OT_SEGMENT
		line_idx += 1
	clock += 300


# ------------------------------------------------------------------ segments

func _play_segment(seg: int, t_in_period: int, period_start: int, sudden_death: bool, ot: bool) -> void:
	var now := period_start + t_in_period
	for s in sides:
		s["penalties"] = s["penalties"].filter(func(expiry): return expiry > now)
	var skaters := []
	for i in 2:
		var n: int = 5 - mini(2, sides[i]["penalties"].size())
		if sides[i]["goalie_pulled"]:
			n += 1
		skaters.append(n)
	var units := [_pick_unit(0, skaters, t_in_period, seg), _pick_unit(1, skaters, t_in_period, seg)]
	_resolve(units, skaters, seg, t_in_period, period_start, sudden_death, ot)


## Chooses who is on the ice for side i given the skater counts.
func _pick_unit(i: int, skaters: Array, t_in_period: int, seg: int) -> Array:
	var s: Dictionary = sides[i]
	var mine: int = skaters[i]
	var theirs: int = skaters[1 - i]
	var shorthanded: bool = s["penalties"].size() > 0
	var opp_shorthanded: bool = sides[1 - i]["penalties"].size() > 0

	if opp_shorthanded and not shorthanded:
		# Power play. PP1 heavy: unit 1 for the first 80 seconds of each minor.
		var heavy: bool = s["tac"].get_value("power_play.usage") == 0
		var unit_idx := 0
		if heavy:
			var expiry: int = sides[1 - i]["penalties"].min()
			var elapsed: int = 120 - (expiry - clock)
			unit_idx = 0 if elapsed < 80 else 1
		else:
			unit_idx = (t_in_period / SEGMENT) % 2
		var unit: Array = s["pp_units"][unit_idx].duplicate()
		return _fit_unit(i, unit, mine)
	if shorthanded and not opp_shorthanded:
		var unit: Array = s["pk_units"][(t_in_period / SEGMENT) % 2].duplicate()
		return _fit_unit(i, unit, mine)

	# Even strength: rotate lines by ice-time share.
	var fi := _next_line(s["f_used"], F_LINE_SHARE)
	var di := _next_line(s["d_used"], D_PAIR_SHARE)
	s["f_used"][fi] += seg
	s["d_used"][di] += seg
	var unit: Array = s["f_lines"][fi].duplicate()
	unit.append_array(s["d_pairs"][di])
	return _fit_unit(i, unit, mine)


## Trim or pad a unit to exactly `count` skaters (4-on-4, 6 attackers...).
func _fit_unit(i: int, unit: Array, count: int) -> Array:
	while unit.size() > count:
		# Drop the weakest forward first.
		var drop := 0
		var worst := 999.0
		for k in unit.size():
			var e = unit[k]
			var v: float = e["p"].overall + (50.0 if e["spot"] in ["LD", "RD"] else 0.0)
			if v < worst:
				worst = v
				drop = k
		unit.remove_at(drop)
	if unit.size() < count:
		var on := {}
		for e in unit:
			on[e["p"].id] = true
		for line in sides[i]["f_lines"]:
			for e in line:
				if unit.size() >= count:
					break
				if not on.has(e["p"].id):
					unit.append(e)
					on[e["p"].id] = true
	return unit


func _next_line(used: Array, shares: Array) -> int:
	var total := 0
	for u in used:
		total += u
	var best := 0
	var best_gap := -INF
	for k in shares.size():
		var gap: float = shares[k] * (total + 1) - used[k]
		if gap > best_gap:
			best_gap = gap
			best = k
	return best


func _update_goalie_pull(time_left: int) -> void:
	if period != 3:
		return
	for i in 2:
		var s: Dictionary = sides[i]
		var deficit: int = sides[1 - i]["goals"] - s["goals"]
		var pull_at: int = s["tac"].pull_goalie_time(deficit)
		var should_pull: bool = pull_at > 0 and time_left <= pull_at and s["penalties"].is_empty()
		if should_pull and not s["goalie_pulled"]:
			_log(i, "info", "%s pulls the goalie for an extra attacker." % s["team"].name)
		s["goalie_pulled"] = should_pull


# ------------------------------------------------------------------ resolution

func _resolve(units: Array, skaters: Array, seg: int, t_in_period: int, period_start: int,
		sudden_death: bool, ot: bool) -> void:
	var late := period >= 3
	var shot_events := []   # [time_in_seg, side]
	for i in 2:
		var s: Dictionary = sides[i]
		var opp: Dictionary = sides[1 - i]
		var att := _unit_rating(units[i], "attack", late)
		var dfn := _unit_rating(units[1 - i], "defense", late)
		var ratio: float = (att / League.norms["attack"]) / (dfn / League.norms["defense"])
		var lam: float = BASE_SHOTS_PER_SEC * seg * pow(ratio, RATING_EXP)
		lam *= s["mods"]["offense"] * opp["mods"]["allow"]
		lam *= _strength_factor(skaters[i], skaters[1 - i], ot)
		lam *= _protect_lead_factor(i, period_start + t_in_period)
		for k in _poisson(lam):
			shot_events.append([rng.randi_range(0, seg - 1), i])
		# Penalties (none in 3-on-3 overtime).
		if not ot:
			var pen_lam: float = PENALTIES_PER_SEC * seg * s["mods"]["penalties"]
			if rng.randf() < pen_lam:
				_take_penalty(i, units[i], period_start + t_in_period + rng.randi_range(0, seg - 1), t_in_period)

	for i in 2:
		for e in units[i]:
			_sl(e["p"], sides[i]["team"].id)["toi"] += seg
	for g in goalie_stats:
		goalie_stats[g]["toi"] += seg

	shot_events.sort_custom(func(a, b): return a[0] < b[0])
	for ev in shot_events:
		if game_over:
			return
		_shot(ev[1], units, skaters, t_in_period + ev[0], ot)
		if (sudden_death or ot) and sides[0]["goals"] != sides[1]["goals"]:
			game_over = true


func _strength_factor(mine: int, theirs: int, ot: bool) -> float:
	if ot:
		return 1.7
	var diff := mine - theirs
	if diff >= 2:
		return 2.8
	if diff == 1:
		return 2.0
	if diff == -1:
		return 0.32
	if diff <= -2:
		return 0.2
	if mine == 4:
		return 1.15   # 4-on-4 opens up
	return 1.0


func _protect_lead_factor(i: int, now: int) -> float:
	if period != 3:
		return 1.0
	var lead: int = sides[i]["goals"] - sides[1 - i]["goals"]
	if lead <= 0:
		return 1.0
	var opt: int = sides[i]["tac"].get_value("situations.protect_lead")
	var threshold: int = [600, 300, -1][opt]
	var time_left: int = 3600 - now
	if threshold > 0 and time_left <= threshold:
		return 0.85
	return 1.0


## Average rating of a unit, after position familiarity and side preference.
func _unit_rating(unit: Array, kind: String, late: bool) -> float:
	if unit.is_empty():
		return 1.0
	var total := 0.0
	for e in unit:
		var p = e["p"]
		var spot: String = e["spot"]
		var v: float = skater_attack(p, spot) if kind == "attack" else skater_defense(p, spot)
		# Strong-side preference on his strong side: cleaner breakouts and wall play.
		if Player.spot_side(spot) != "" and not p.prefers_off_side and not p.is_off_side_at(spot):
			v *= 1.02
		if late:
			v *= 0.96 + 0.04 * p.attr("endurance") / 20.0
		# Tired legs: a player at 70% condition plays ~2% below his ratings.
		v *= 0.94 + 0.06 * Game.condition_of(p.id) / 100.0
		total += v
	return total / unit.size()


func _shot(i: int, units: Array, skaters: Array, t_in_period: int, ot: bool) -> void:
	var s: Dictionary = sides[i]
	var opp: Dictionary = sides[1 - i]
	var unit: Array = units[i]
	if unit.is_empty():
		return
	var pp: bool = skaters[i] > skaters[1 - i] and not s["goalie_pulled"]
	var sh: bool = skaters[i] < skaters[1 - i] and not opp["goalie_pulled"]

	# Pick the shooter.
	var weights := []
	var pp_threat: int = s["tac"].get_value("power_play.threat")
	for e in unit:
		var p = e["p"]
		var w: float = pow(p.shots60(), SHOT_WEIGHT_EXP)
		if pp and pp_threat == 0 and _one_timer_bonus(e):
			w *= 1.25
		elif pp and pp_threat == 1 and e["spot"] in ["LD", "RD"]:
			w *= 1.5
		elif pp and pp_threat == 3 and e["spot"] == "C":
			w *= 1.3
		weights.append(w)
	var shooter_e = unit[_weighted_index(weights)]
	var shooter = shooter_e["p"]
	s["shots"] += 1
	_sl(shooter, s["team"].id)["shots"] += 1

	var empty_net: bool = opp["goalie_pulled"]
	var goalie = opp["goalie"]
	var prob: float
	var one_timer := _one_timer_bonus(shooter_e)
	if empty_net or goalie == null:
		prob = 0.55
	else:
		prob = goal_chance(shooter, shooter_e["spot"], goalie)
		if one_timer:
			prob *= 1.04
		prob *= s["mods"]["quality_for"] * opp["mods"]["quality_against"]
		if pp:
			prob *= 1.2 * s["mods"]["pp_quality"] * opp["mods"]["pk_quality"]
		elif sh:
			prob *= 1.1
		if ot:
			prob *= 1.2
		prob = clampf(prob, 0.01, 0.45)
		goalie_stats[goalie.id]["sa"] += 1

	var shot_type := _shot_type(shooter_e, one_timer)
	if rng.randf() < prob:
		_goal(i, unit, units[1 - i], shooter_e, shot_type, pp, sh, empty_net, t_in_period)
	elif not empty_net and goalie != null and prob > 0.16 and rng.randf() < 0.35:
		_log(1 - i, "save", "Big save by %s on %s's %s!" % [goalie.short_name(), shooter.short_name(), shot_type], t_in_period)


func _one_timer_bonus(e: Dictionary) -> bool:
	var p = e["p"]
	return p.prefers_off_side and p.is_off_side_at(e["spot"])


# Rating formulas, shared with League.compute_norms().

static func skater_attack(p, spot: String) -> float:
	return (0.25 * p.attr("shooting") + 0.25 * p.attr("passing") + 0.2 * p.attr("puck_handling") \
		+ 0.2 * p.attr("offense_iq") + 0.1 * p.attr("skating")) * p.position_factor(spot)


static func skater_defense(p, spot: String) -> float:
	return (0.45 * p.attr("defense") + 0.2 * p.attr("skating") + 0.15 * p.attr("physical") \
		+ 0.2 * p.attr("offense_iq")) * p.position_factor(spot)


static func shooting_value(p, spot: String) -> float:
	return (0.6 * p.attr("shooting") + 0.2 * p.attr("offense_iq") + 0.2 * p.attr("puck_handling")) \
		* p.position_factor(spot)


## Goal chance for a shot at even strength before situation and tactics:
## mostly the shooter's real (regressed) shooting %, partly his ratings,
## against this goalie.
static func goal_chance(p, spot: String, goalie) -> float:
	var pos_avg := 0.05 if spot in ["LD", "RD"] else 0.115
	var rating_pct := pos_avg * pow(shooting_value(p, spot) / League.norms["shooting"], RATING_EXP)
	var base: float = TENDENCY_WEIGHT * p.sh_pct() + (1.0 - TENDENCY_WEIGHT) * rating_pct
	return SH_SCALE * base * pow(League.norms["goalie"] / goalie_rating(goalie), GOALIE_EXP)


static func goalie_rating(g) -> float:
	return 0.3 * g.attr("reflexes") + 0.3 * g.attr("positioning") + 0.15 * g.attr("rebound_control") \
		+ 0.15 * g.attr("glove") + 0.1 * g.attr("consistency")


func _shot_type(e: Dictionary, one_timer: bool) -> String:
	if one_timer:
		return "one-timer"
	var options := ["wrist shot", "snap shot", "backhand", "rebound", "deflection"]
	if e["spot"] in ["LD", "RD"]:
		options = ["slap shot", "wrist shot from the point", "point shot"]
	return options[rng.randi_range(0, options.size() - 1)]


func _goal(i: int, unit: Array, opp_unit: Array, shooter_e: Dictionary, shot_type: String,
		pp: bool, sh: bool, empty_net: bool, t_in_period: int) -> void:
	var s: Dictionary = sides[i]
	var opp: Dictionary = sides[1 - i]
	var shooter = shooter_e["p"]
	s["goals"] += 1
	var line := _sl(shooter, s["team"].id)
	line["g"] += 1
	if pp:
		line["ppg"] += 1
		s["pp_goals"] += 1
	if sh:
		line["shg"] += 1
	if not empty_net and opp["goalie"] != null:
		goalie_stats[opp["goalie"].id]["ga"] += 1

	# Assists, weighted by passing.
	var helpers := []
	var weights := []
	for e in unit:
		if e["p"] != shooter:
			helpers.append(e["p"])
			weights.append(pow(e["p"].a60(), ASSIST_EXP))
	var assists := []
	if not helpers.is_empty() and rng.randf() < 0.93:
		var k := _weighted_index(weights)
		assists.append(helpers[k])
		helpers.remove_at(k)
		weights.remove_at(k)
		if not helpers.is_empty() and rng.randf() < 0.72:
			assists.append(helpers[_weighted_index(weights)])
	for a in assists:
		_sl(a, s["team"].id)["a"] += 1

	# Plus/minus: not on power-play goals.
	if not pp:
		for e in unit:
			if stats.has(e["p"].id):
				stats[e["p"].id]["pm"] += 1
		for e in opp_unit:
			if stats.has(e["p"].id):
				stats[e["p"].id]["pm"] -= 1

	# A power-play goal ends the earliest minor.
	if pp and not opp["penalties"].is_empty():
		opp["penalties"].sort()
		opp["penalties"].remove_at(0)

	var tag := ""
	if pp:
		tag = " (PP)"
	elif sh:
		tag = " (SH)"
	elif empty_net:
		tag = " (EN)"
	var helpers_txt := "unassisted"
	if not assists.is_empty():
		helpers_txt = ", ".join(assists.map(func(p): return p.short_name()))
	var text := "GOAL%s! %s scores on a %s. Assists: %s. %s %d, %s %d." % [tag, shooter.short_name(),
		shot_type, helpers_txt, sides[0]["team"].id, sides[0]["goals"], sides[1]["team"].id, sides[1]["goals"]]
	_log(i, "goal", text, t_in_period)


func _take_penalty(i: int, unit: Array, when: int, t_in_period: int) -> void:
	var s: Dictionary = sides[i]
	if s["penalties"].size() >= 2 or unit.is_empty():
		return
	var weights := []
	for e in unit:
		weights.append(pow(e["p"].attr("physical"), 1.5))
	var offender = unit[_weighted_index(weights)]["p"]
	s["penalties"].append(when + 120)
	sides[1 - i]["pp_opps"] += 1
	_sl(offender, s["team"].id)["pim"] += 2
	var kind: String = PENALTY_TYPES[rng.randi_range(0, PENALTY_TYPES.size() - 1)]
	_log(i, "penalty", "Penalty: %s, 2 minutes for %s." % [offender.short_name(), kind], t_in_period)
	# A pulled goalie goes back in when his team goes shorthanded.
	s["goalie_pulled"] = false


func _shootout() -> void:
	var shooters := []
	for i in 2:
		var pool := []
		for line in sides[i]["f_lines"]:
			for e in line:
				pool.append(e["p"])
		for pair in sides[i]["d_pairs"]:
			for e in pair:
				pool.append(e["p"])
		pool.sort_custom(func(a, b):
			return a.attr("shooting") + a.attr("puck_handling") > b.attr("shooting") + b.attr("puck_handling"))
		shooters.append(pool)
	var made := [0, 0]
	var rnd := 0
	while true:
		for i in 2:
			var pool: Array = shooters[i]
			if pool.is_empty():
				continue
			var p = pool[rnd % pool.size()]
			var g = sides[1 - i]["goalie"]
			var skill: float = 0.5 * p.attr("shooting") + 0.5 * p.attr("puck_handling")
			var prob := 0.32 * pow(skill / League.norms["shooting"], 1.2)
			if g != null:
				prob *= pow(League.norms["goalie"] / goalie_rating(g), 1.5)
			var scored := rng.randf() < clampf(prob, 0.1, 0.6)
			if scored:
				made[i] += 1
			_log(i, "shootout", "Shootout: %s %s." % [p.short_name(), "SCORES" if scored else "is stopped"])
		rnd += 1
		if rnd >= 3:
			if made[0] != made[1]:
				break
		else:
			# Stop early once one side can't catch up.
			var left := 3 - rnd
			if made[0] > made[1] + left or made[1] > made[0] + left:
				break
		if rnd > 20:
			made[rng.randi_range(0, 1)] += 1
			break
	var winner := 0 if made[0] > made[1] else 1
	sides[winner]["goals"] += 1


func _finish(kind: String) -> void:
	game_over = true
	var winner := 0 if sides[0]["goals"] > sides[1]["goals"] else 1
	for i in 2:
		var g = sides[i]["goalie"]
		if g == null:
			continue
		if i == winner:
			goalie_stats[g.id]["decision"] = "W"
		else:
			goalie_stats[g.id]["decision"] = "L" if kind == "" else "OTL"
	ot_kind = kind


# ------------------------------------------------------------------ helpers

## The game stat line for a skater, created on first use (e.g. a PP specialist
## who isn't on one of the four lines).
func _sl(p, team_id: String) -> Dictionary:
	if not stats.has(p.id):
		stats[p.id] = {"team": team_id, "g": 0, "a": 0, "shots": 0, "pim": 0, "pm": 0, "toi": 0,
			"ppg": 0, "shg": 0}
	return stats[p.id]

func _poisson(lam: float) -> int:
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l:
			return k
		k += 1
		if k > 20:
			return k
	return k


func _weighted_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for k in weights.size():
		r -= weights[k]
		if r <= 0.0:
			return k
	return weights.size() - 1


func _log(side: int, kind: String, text: String, t_in_period: int = -1) -> void:
	var stamp := ""
	if t_in_period >= 0:
		stamp = "%d:%02d" % [t_in_period / 60, t_in_period % 60]
	var team_id := ""
	if side >= 0:
		team_id = sides[side]["team"].id
	var label := "OT" if period > 3 and not playoff else ("OT%d" % (period - 3) if period > 3 else "P%d" % period)
	if kind == "shootout":
		label = "SO"
	events.append({"period": label, "time": stamp, "team": team_id, "type": kind, "text": text})


## Football Manager-style match ratings (about 6.0-9.5; 6.8 is a solid night).
func _rate_players() -> void:
	for pid in stats:
		var l: Dictionary = stats[pid]
		var r: float = 6.3 + l["g"] * 0.85 + l["a"] * 0.5 + l["pm"] * 0.22 + l["shots"] * 0.07 \
			- l["pim"] * 0.06 + (l["toi"] - 900.0) / 1800.0 * 0.3 + rng.randf_range(-0.25, 0.25)
		l["rating"] = snappedf(clampf(r, 4.8, 10.0), 0.1)
	for gid in goalie_stats:
		var l: Dictionary = goalie_stats[gid]
		var sa: int = l["sa"]
		var sv := (float(sa - l["ga"]) / sa) if sa > 0 else 0.9
		var r: float = 6.6 + (sv - 0.905) * 22.0 + (0.3 if l["decision"] == "W" else 0.0) \
			+ (0.8 if l["ga"] == 0 and sa > 10 else 0.0) + sa * 0.01 + rng.randf_range(-0.2, 0.2)
		l["rating"] = snappedf(clampf(r, 4.5, 10.0), 0.1)


func _result() -> Dictionary:
	_rate_players()
	var stars := stats.keys()
	stars.sort_custom(func(a, b):
		var sa: Dictionary = stats[a]
		var sb: Dictionary = stats[b]
		return sa["rating"] > sb["rating"])
	return {
		"home": sides[0]["team"].id, "away": sides[1]["team"].id,
		"home_goals": sides[0]["goals"], "away_goals": sides[1]["goals"],
		"home_shots": sides[0]["shots"], "away_shots": sides[1]["shots"],
		"home_pp": [sides[0]["pp_goals"], sides[0]["pp_opps"]],
		"away_pp": [sides[1]["pp_goals"], sides[1]["pp_opps"]],
		"ot": ot_kind,
		"periods": period_scores,
		"events": events,
		"stats": stats,
		"goalies": goalie_stats,
		"stars": stars.slice(0, 3),
	}
