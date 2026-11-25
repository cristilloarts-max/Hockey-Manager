class_name TradeAI
extends RefCounted
## How AI general managers value players and picks, judge trade offers,
## build offers of their own, and trade with each other.
##
## Values are in "trade points". A player's worth grows steeply with his
## overall (an 85 is worth about five 70s), so piles of depth players can't
## buy a star. Every team has a strategy that shifts what it wants:
##   contender  - wins now: current ability, short-term rentals; picks matter less
##   bubble     - balanced
##   rebuilding - youth, potential and picks; ageing veterans and rentals matter less
## A trade is a Dictionary:
##   {"a": team_id, "b": team_id, "a_gives": [asset], "b_gives": [asset], "retain": {pid: pct}}
## and an asset is {"type": "player", "id": int} or {"type": "pick", "id": "2027-1-TRL"}.

## [current ability weight, future weight, pick multiplier]
const WEIGHTS := {"contender": [1.0, 0.4, 0.8], "bubble": [0.9, 0.6, 1.0], "rebuilding": [0.75, 0.9, 1.25]}
## Each extra piece in a package counts for less (quality over quantity).
const DEPTH_DECAY := [1.0, 0.7, 0.5, 0.4, 0.35, 0.3]
## Each extra body taken on (more players in than out) costs a roster spot.
const ROSTER_SPOT_COST := 4.0
## AI teams want to win a trade by a little.
const AI_MARGIN := 1.05
const MAX_RETAINED := 3

static var _cache_key := ""
static var _cache := {}       ## team -> {"strategy": String, "rank": int}


# ------------------------------------------------------------------ strategies

## "contender", "bubble" or "rebuilding", from roster strength and (as the
## season goes on) the standings.
static func strategy(team_id: String) -> String:
	_refresh_cache()
	return _cache.get(team_id, {}).get("strategy", "bubble")


static func strategy_label(team_id: String) -> String:
	match strategy(team_id):
		"contender":
			return "Contender - buying"
		"rebuilding":
			return "Rebuilding - selling"
	return "Bubble team"


static func strategy_color(team_id: String) -> Color:
	match strategy(team_id):
		"contender":
			return AppTheme.GOLD
		"rebuilding":
			return AppTheme.BLUE
	return AppTheme.YELLOW


## 1 = best team in the league right now.
static func power_rank(team_id: String) -> int:
	_refresh_cache()
	return int(_cache.get(team_id, {}).get("rank", 16))


static func _refresh_cache() -> void:
	var key := "%d-%s" % [Game.day, Game.phase]
	if key == _cache_key and not _cache.is_empty():
		return
	_cache_key = key
	_cache.clear()
	var teams := League.team_list()
	var by_strength := teams.duplicate()
	by_strength.sort_custom(func(a, b): return League.team_strength(a.id) > League.team_strength(b.id))
	var strength_rank := {}
	for i in by_strength.size():
		strength_rank[by_strength[i].id] = i
	var stand_rank := {}
	var i := 0
	for row in Game.standings_sorted():
		stand_rank[row["team"]] = i
		i += 1
	var gp := 0
	if not Game.standings.is_empty():
		gp = Game.standings[teams[0].id]["gp"]
	var w := clampf(gp / 50.0, 0.0, 0.7)
	var scored := []
	for t in teams:
		scored.append([t.id, (1.0 - w) * strength_rank[t.id] + w * stand_rank.get(t.id, 16)])
	scored.sort_custom(func(a, b): return a[1] < b[1])
	for r in scored.size():
		var s := "bubble"
		if r < 10:
			s = "contender"
		elif r >= 22:
			s = "rebuilding"
		_cache[scored[r][0]] = {"strategy": s, "rank": r + 1}


# ------------------------------------------------------------------ values

## What a fair cap hit looks like for this overall (fit to the league's contracts).
static func fair_salary(ovr: int) -> float:
	return 900_000.0 + 16_500_000.0 * pow(clampf((ovr - 48) / 47.0, 0.0, 1.0), 2.2)


## How much `team_id` values this player. `retained_pct` is salary the other
## team keeps (makes him cheaper to take on).
static func player_value(p, team_id: String, retained_pct: float = 0.0) -> float:
	var strat := strategy(team_id)
	var w: Array = WEIGHTS[strat]
	var now := pow(maxf(0.0, (p.base_overall - 48) / 10.0), 3)
	if p.age > 30:
		var k := 0.03 if strat == "contender" else (0.05 if strat == "bubble" else 0.07)
		now *= maxf(0.4, 1.0 - k * (p.age - 30))
	var youth := 0.0
	if p.age <= 20:
		youth = 0.9
	elif p.age <= 22:
		youth = 0.75
	elif p.age <= 24:
		youth = 0.5
	elif p.age <= 26:
		youth = 0.25
	var future := pow(maxf(0.0, (p.base_potential - 48) / 10.0), 3) * youth
	var v: float = w[0] * now + w[1] * future
	var years: int = p.contract["years"]
	# Rebuilding teams don't want veterans who are about to walk.
	if strat == "rebuilding" and years <= 1 and p.age >= 27:
		v *= 0.5
	# Contract value: bargains add, overpays subtract (over up to 4 seasons).
	var cost: float = p.team_cap_hit() * (1.0 - retained_pct)
	var surplus_m := (fair_salary(p.base_overall) - cost) / 1_000_000.0
	v += surplus_m * mini(years, 4) * 0.8
	return maxf(v, -30.0)


## Draft pick value: early firsts are gold, later rounds are sweeteners.
static func pick_value(pick: Dictionary, team_id: String) -> float:
	var slot := projected_slot(pick["orig"])
	var rnd: int = pick["round"]
	var v: float
	if rnd == 1:
		v = 45.0 * exp(-(slot - 1) / 9.0) + 6.0
	elif rnd == 2:
		v = 3.5
	else:
		v = 1.0
	var years_out: int = maxi(0, int(pick["year"]) - 2027)
	var mid := 17.0 if rnd == 1 else v
	v = mid + (v - mid) * pow(0.6, years_out)
	v *= pow(0.9, years_out)
	return v * float(WEIGHTS[strategy(team_id)][2])


## Where this team's pick is projected to land (1 = first overall).
static func projected_slot(team_id: String) -> int:
	return 33 - power_rank(team_id)


static func asset_value(asset: Dictionary, team_id: String, retain: Dictionary = {}) -> float:
	if asset["type"] == "pick":
		var pick: Dictionary = Game.picks.get(asset["id"], {})
		return pick_value(pick, team_id) if not pick.is_empty() else 0.0
	var p := League.get_player(int(asset["id"]))
	if p == null:
		return 0.0
	return player_value(p, team_id, float(retain.get(str(p.id), 0.0)))


## Value of a package: the best piece counts fully, extra pieces less.
static func package_value(assets: Array, team_id: String, retain: Dictionary = {}, premium: Dictionary = {}) -> float:
	var vals := []
	for a in assets:
		var v := asset_value(a, team_id, retain)
		if a["type"] == "player" and premium.has(int(a["id"])):
			v *= premium[int(a["id"])]
		vals.append(v)
	vals.sort()
	vals.reverse()
	var total := 0.0
	var k := 0
	for v in vals:
		if v <= 0:
			total += v
		else:
			total += v * DEPTH_DECAY[mini(k, DEPTH_DECAY.size() - 1)]
			k += 1
	return total


static func _count_players(assets: Array) -> int:
	return assets.filter(func(x): return x["type"] == "player").size()


## Players their owner acquired in the last 30 days are worth 20% less to
## AI teams (stops buying cheap from sellers and flipping to buyers).
static func _flip_discount(assets: Array) -> Dictionary:
	var out := {}
	for a in assets:
		if a["type"] == "player":
			var when: int = int(Game.last_traded.get(str(a["id"]), -999))
			if Game.day - when <= 30:
				out[int(a["id"])] = 0.8
	return out


## A team's two most valuable young-enough players cost extra to pry loose.
static func franchise_premium(team_id: String) -> Dictionary:
	var core := League.roster(team_id).filter(func(p): return p.age <= 29)
	core.sort_custom(func(a, b): return player_value(a, team_id) > player_value(b, team_id))
	var out := {}
	for p in core.slice(0, 2):
		out[p.id] = 1.35
	return out


# ------------------------------------------------------------------ judging a trade

## The AI side (`trade.b`) judges the trade. Returns
## {"ok": bool, "ratio": float, "mood": String, "message": String, "blocked": bool}
static func evaluate(trade: Dictionary, margin: float = AI_MARGIN) -> Dictionary:
	var problem := legality(trade)
	if problem != "":
		return {"ok": false, "ratio": 0.0, "mood": "Not allowed", "message": problem, "blocked": true}
	var ai: String = trade["b"]
	var retain: Dictionary = trade.get("retain", {})
	var get_v := package_value(trade["a_gives"], ai, retain, _flip_discount(trade["a_gives"]))
	var give_v := package_value(trade["b_gives"], ai, retain, franchise_premium(ai))
	var bodies := _count_players(trade["a_gives"]) - _count_players(trade["b_gives"])
	get_v -= ROSTER_SPOT_COST * maxi(0, bodies)
	var need := give_v * margin + 1.0
	var ratio := get_v / need if need > 0 else 2.0
	var mood := "Not interested"
	var msg := "They aren't interested at all."
	if ratio >= 1.0:
		mood = "Deal"
		msg = "They would accept this trade."
	elif ratio >= 0.85:
		mood = "Close"
		msg = "Close. Add a little more and they'll probably say yes."
	elif ratio >= 0.6:
		mood = "Not enough"
		msg = "They want quite a bit more."
	if trade["b_gives"].is_empty() and get_v <= 0:
		mood = "Not interested"
		msg = "They don't want to take on that contract for nothing."
		ratio = minf(ratio, 0.3)
	return {"ok": ratio >= 1.0, "ratio": ratio, "mood": mood, "message": msg, "blocked": false}


## Hard rules every trade must pass. Returns "" when legal, else the reason.
static func legality(trade: Dictionary) -> String:
	if not Game.trades_open():
		return "Trading is closed: the trade deadline has passed."
	var a: String = trade["a"]
	var b: String = trade["b"]
	if trade["a_gives"].is_empty() and trade["b_gives"].is_empty():
		return "Add players or picks to the trade."
	var retain: Dictionary = trade.get("retain", {})
	for side in [["a_gives", a, b], ["b_gives", b, a]]:
		var new_retained := 0
		for asset in trade[side[0]]:
			if asset["type"] == "pick":
				var pick: Dictionary = Game.picks.get(asset["id"], {})
				if pick.is_empty() or pick["owner"] != side[1]:
					return "That pick doesn't belong to the %s." % League.get_team(side[1]).name
				continue
			var p := League.get_player(int(asset["id"]))
			if p == null or p.team_id != side[1]:
				return "A player in the trade isn't on the right team."
			if p.contract.get("no_trade_clause", false) and strategy(side[2]) != "contender":
				return "%s won't waive his no-trade clause to join the %s (he'll only go to a contender)." % [
					p.full_name(), League.get_team(side[2]).name]
			var pct: float = float(retain.get(str(p.id), 0.0))
			if pct > 0.0:
				if pct > 0.5:
					return "A team can retain at most 50% of a salary."
				if p.contract.get("retained", 0) > 0:
					return "%s's salary has already been retained once." % p.full_name()
				new_retained += 1
		if new_retained > 0 and League.retained_contracts(side[1]).size() + new_retained > MAX_RETAINED:
			return "The %s can't retain salary on more than %d contracts." % [League.get_team(side[1]).name, MAX_RETAINED]
	for team in [a, b]:
		var before := League.payroll(team)
		var after := payroll_after(trade, team)
		var cap: int = League.finances.get("salary_cap", 0)
		if after > cap and after > before:
			return "This would put the %s over the salary cap (%s over)." % [League.get_team(team).name, Game.money(after - cap)]
		if goalies_after(trade, team) < 2:
			return "The %s need to keep at least two goalies." % League.get_team(team).name
	return ""


## Payroll after the trade (incoming players count in full, minus retention).
static func payroll_after(trade: Dictionary, team: String) -> int:
	var retain: Dictionary = trade.get("retain", {})
	var total := League.payroll(team)
	var out_key := "a_gives" if team == trade["a"] else "b_gives"
	var in_key := "b_gives" if team == trade["a"] else "a_gives"
	var bury: int = League.finances.get("bury_allowance", 1_150_000)
	for asset in trade[out_key]:
		if asset["type"] != "player":
			continue
		var p := League.get_player(int(asset["id"]))
		var counted := p.team_cap_hit() if p.on_nhl_roster() else maxi(0, p.team_cap_hit() - bury)
		var kept := int(p.cap_hit() * float(retain.get(str(p.id), 0.0)))
		total += kept - counted
	for asset in trade[in_key]:
		if asset["type"] != "player":
			continue
		var p := League.get_player(int(asset["id"]))
		total += int(p.team_cap_hit() - p.cap_hit() * float(retain.get(str(p.id), 0.0)))
	return total


static func goalies_after(trade: Dictionary, team: String) -> int:
	var count := League.roster(team).filter(func(p): return p.is_goalie()).size()
	var out_key := "a_gives" if team == trade["a"] else "b_gives"
	var in_key := "b_gives" if team == trade["a"] else "a_gives"
	for asset in trade[out_key]:
		if asset["type"] == "player" and League.get_player(int(asset["id"])).is_goalie():
			count -= 1
	for asset in trade[in_key]:
		if asset["type"] == "player" and League.get_player(int(asset["id"])).is_goalie():
			count += 1
	return count


static func players_after(trade: Dictionary, team: String) -> int:
	var count := League.nhl_roster(team).size()
	var out_key := "a_gives" if team == trade["a"] else "b_gives"
	var in_key := "b_gives" if team == trade["a"] else "a_gives"
	for asset in trade[out_key]:
		if asset["type"] == "player" and League.get_player(int(asset["id"])).on_nhl_roster():
			count -= 1
	for asset in trade[in_key]:
		if asset["type"] == "player":
			count += 1
	return count


# ------------------------------------------------------------------ building trades

## Every asset a team could trade: players then picks.
static func assets_of(team_id: String) -> Array:
	var out := []
	for p in League.roster(team_id):
		out.append({"type": "player", "id": p.id})
	for pick_id in Game.picks:
		if Game.picks[pick_id]["owner"] == team_id:
			out.append({"type": "pick", "id": pick_id})
	return out


static func _contains(assets: Array, asset: Dictionary) -> bool:
	for a in assets:
		if a["type"] == asset["type"] and str(a["id"]) == str(asset["id"]):
			return true
	return false


## The AI (trade.b) adds pieces from trade.a's assets until it would say yes.
## Returns the completed trade, or {} if nothing reasonable works.
static func ask_what_they_want(trade: Dictionary) -> Dictionary:
	var t := trade.duplicate(true)
	var ai: String = t["b"]
	for _step in 5:
		var e := evaluate(t)
		if e["blocked"]:
			return {}
		if e["ok"]:
			return t
		var need := package_value(t["b_gives"], ai, t.get("retain", {}), franchise_premium(ai)) * AI_MARGIN + 1.0
		var have := package_value(t["a_gives"], ai, t.get("retain", {})) \
			- ROSTER_SPOT_COST * maxi(0, _count_players(t["a_gives"]) - _count_players(t["b_gives"]))
		var deficit := need - have
		var best = null
		var best_score := INF
		var biggest = null
		var biggest_v := 0.0
		for asset in assets_of(t["a"]):
			if _contains(t["a_gives"], asset):
				continue
			var trial: Array = t["a_gives"].duplicate()
			trial.append(asset)
			var trial_have := package_value(trial, ai, t.get("retain", {})) \
				- ROSTER_SPOT_COST * maxi(0, _count_players(trial) - _count_players(t["b_gives"]))
			var gain := trial_have - have
			if gain <= 0.5:
				continue
			if gain >= deficit and gain - deficit < best_score:
				best_score = gain - deficit
				best = asset
			if gain > biggest_v:
				biggest_v = gain
				biggest = asset
		var pick_asset = best if best != null else biggest
		if pick_asset == null:
			return {}
		t["a_gives"].append(pick_asset)
	return t if evaluate(t)["ok"] else {}


## AI team `ai` builds an offer for one of `target_team`'s players.
## Returns a trade with a = target_team (they give the player), b = ai.
static func build_offer(ai: String, target_team: String, target_pid: int) -> Dictionary:
	var trade := {"a": target_team, "b": ai, "a_gives": [{"type": "player", "id": target_pid}], "b_gives": [], "retain": {}}
	var want := package_value(trade["a_gives"], ai)
	if want <= 2.0:
		return {}
	# Leave room for the margin and the roster spot the incoming player takes.
	var budget := (want - 1.0 - ROSTER_SPOT_COST) / AI_MARGIN
	# Offer what the AI values least relative to what others would pay.
	var cands := []
	var premium := franchise_premium(ai)
	for asset in assets_of(ai):
		if asset["type"] == "player" and premium.has(int(asset["id"])):
			continue
		var mine := asset_value(asset, ai)
		var market := asset_value(asset, target_team)
		if market <= 1.0:
			continue
		cands.append([asset, mine, market / maxf(0.5, mine)])
	cands.sort_custom(func(x, y): return x[2] > y[2])
	for c in cands:
		var trial: Array = trade["b_gives"].duplicate()
		trial.append(c[0])
		if package_value(trial, ai, {}, premium) <= budget:
			trade["b_gives"] = trial
		if trade["b_gives"].size() >= 3:
			break
	if trade["b_gives"].is_empty():
		return {}
	return trade if evaluate(trade)["ok"] else {}


## The other side's view: is this offer fair to `team` (used for AI-to-AI deals
## and to make sure offers to you aren't insulting)?
static func fair_for(trade: Dictionary, team: String) -> float:
	var gets_key := "b_gives" if team == trade["a"] else "a_gives"
	var gives_key := "a_gives" if team == trade["a"] else "b_gives"
	var gets := package_value(trade[gets_key], team, trade.get("retain", {}))
	var gives := package_value(trade[gives_key], team, trade.get("retain", {}), franchise_premium(team))
	return gets / maxf(1.0, gives)


static func describe(asset: Dictionary) -> String:
	if asset["type"] == "pick":
		return Game.pick_label(asset["id"])
	var p := League.get_player(int(asset["id"]))
	return "%s (%s, %d)" % [p.full_name(), p.position, p.overall] if p else "?"
