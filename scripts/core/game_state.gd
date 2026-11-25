extends Node
## Autoload "Game": the running save: your team, the calendar, schedule,
## results, standings, stats, lineups, tactics, playoffs and awards.

signal day_advanced
signal season_finished

const SAVE_PATH := "user://save.json"
const SEASON_START := {"year": 2026, "month": 10, "day": 7, "hour": 12}
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const WEEKDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const ROUND_NAMES := ["First Round", "Second Round", "Conference Final", "Stanton Cup Final"]
## Trade deadline: March 6 (day 150 of the calendar that starts October 7).
const DEADLINE_DAY := 150
const PICK_YEARS := [2027, 2028, 2029]
const PICK_ROUNDS := [1, 2, 3]

var active := false
var user_team_id := ""
var world_seed := 0
var day := 0                 ## next day to be played
var phase := "regular"       ## "regular", "playoffs", "done"
var schedule := []           ## {day, home, away, played, hg, ag, ot}
var box_scores := {}         ## key ("12" regular / "p3" playoffs) -> full result (your games only)
var standings := {}          ## team -> record
var skater_stats := {}       ## pid (String) -> regular-season line
var goalie_season := {}      ## pid (String) -> regular-season line
var playoff_skaters := {}    ## pid (String) -> playoff line
var playoff_goalies := {}    ## pid (String) -> playoff line
var playoffs := {}           ## {"series": [], "games": [], "round": 1, "next_day": d, "champion": ""}
var awards := []             ## {name, kind, desc, winner, team, line, finalists}
var lineups := {}            ## team -> Lineup
var tactics := {}            ## team -> Tactics
var inbox := []              ## {day, title, body}
var form := {}               ## pid (String) -> last 5 match ratings
var morale := {}             ## pid (String) -> 0..100
var condition := {}          ## pid (String) -> 0..100 (fitness for the next game)
var rank_history := {}       ## team -> league rank after each game day
var picks := {}              ## "2027-1-TRL" -> {year, round, orig, owner}
var trade_history := []      ## {day, a, b, a_gives: [text], b_gives: [text]}
var offers := []             ## incoming AI offers: {id, trade, from, expires}
var trading_block := {}      ## pid (String) -> true: your players you're shopping
var flags := {}              ## one-time messages already sent
var last_traded := {}        ## pid (String) -> day he was last traded
var last_sim_day := -1


# ------------------------------------------------------------------ setup

func new_game(team_id: String, game_seed: int = 0) -> void:
	if League.teams.is_empty():
		League.load_default()
	user_team_id = team_id
	world_seed = game_seed if game_seed != 0 else int(Time.get_unix_time_from_system())
	day = 0
	phase = "regular"
	for d in [box_scores, skater_stats, goalie_season, playoff_skaters, playoff_goalies, playoffs,
			form, condition, rank_history, morale, standings, lineups, tactics, picks, trading_block, flags,
			last_traded]:
		d.clear()
	awards.clear()
	trade_history.clear()
	offers.clear()
	inbox.clear()
	last_sim_day = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for pid in League.players:
		morale[str(pid)] = rng.randi_range(55, 80)
	schedule = Schedule.generate(League.team_list(), rng)
	for g in schedule:
		g["played"] = false
	for year in PICK_YEARS:
		for rnd in PICK_ROUNDS:
			for id in League.teams:
				picks["%d-%d-%s" % [year, rnd, id]] = {"year": year, "round": rnd, "orig": id, "owner": id}
	for id in League.teams:
		standings[id] = _empty_record()
		lineups[id] = League.default_lineup(id)
		tactics[id] = Tactics.new()
	active = true
	var team := League.get_team(team_id)
	add_message("Welcome to the %s" % team.full_name(),
		"The owner has handed you the keys. Your lines are set the way the team plays them right now.\n\nNHL roster: %d / %d.  Cap space: %s.  Check Squad > Players and Lines, then hit Continue." % [
			League.nhl_roster(team_id).size(), roster_max(), money(League.cap_space(team_id))])


func _empty_record() -> Dictionary:
	return {"gp": 0, "w": 0, "l": 0, "otl": 0, "pts": 0, "rw": 0, "gf": 0, "ga": 0,
		"home_w": 0, "home_l": 0, "home_otl": 0, "away_w": 0, "away_l": 0, "away_otl": 0,
		"streak": "", "last10": []}


func add_message(title: String, body: String) -> void:
	inbox.push_front({"day": day, "title": title, "body": body})


# ------------------------------------------------------------------ calendar

func date_string(d: int = -1) -> String:
	if d < 0:
		d = day
	var unix := Time.get_unix_time_from_datetime_dict(SEASON_START) + d * 86400
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%s, %s %d, %d" % [WEEKDAYS[dt["weekday"]], MONTHS[dt["month"] - 1], dt["day"], dt["year"]]


func short_date(d: int) -> String:
	var unix := Time.get_unix_time_from_datetime_dict(SEASON_START) + d * 86400
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%s %d" % [MONTHS[dt["month"] - 1], dt["day"]]


func is_season_over() -> bool:
	return phase == "done"


func regular_season_over() -> bool:
	return schedule.all(func(g): return g["played"])


func team_games(team_id: String) -> Array:
	var out := []
	for i in schedule.size():
		var g: Dictionary = schedule[i]
		if g["home"] == team_id or g["away"] == team_id:
			out.append(i)
	return out


func next_game_index(team_id: String) -> int:
	for i in team_games(team_id):
		if not schedule[i]["played"]:
			return i
	return -1


func last_game_index(team_id: String) -> int:
	var last := -1
	for i in team_games(team_id):
		if schedule[i]["played"]:
			last = i
	return last


## {day, home, away, label} for your next game (regular season or playoffs), or {}.
func next_game_info() -> Dictionary:
	if phase == "regular":
		var i := next_game_index(user_team_id)
		if i >= 0:
			var g: Dictionary = schedule[i]
			return {"day": g["day"], "home": g["home"], "away": g["away"], "label": ""}
	elif phase == "playoffs":
		var s := user_series()
		if not s.is_empty() and s["winner"] == "":
			var n: int = s["w_high"] + s["w_low"] + 1
			var home: String = s["high"] if n in [1, 2, 5, 7] else s["low"]
			return {"day": playoffs["next_day"], "home": home, "away": s["low"] if home == s["high"] else s["high"],
				"label": "%s, game %d" % [ROUND_NAMES[s["round"] - 1], n]}
	return {}


# ------------------------------------------------------------------ roster rules

func roster_max() -> int:
	return int(League.finances.get("roster_max", 23))


func roster_min() -> int:
	return int(League.finances.get("roster_min", 20))


## Reasons your team can't play right now (empty = legal).
func roster_problems(team_id: String) -> Array:
	var out := []
	var nhl := League.nhl_roster(team_id)
	var goalies := nhl.filter(func(p): return p.is_goalie()).size()
	if nhl.size() > roster_max():
		out.append("Too many players on the NHL roster: %d (max %d). Send someone to the reserve list." % [nhl.size(), roster_max()])
	if nhl.size() < roster_min():
		out.append("Not enough players on the NHL roster: %d (min %d). Call someone up." % [nhl.size(), roster_min()])
	if goalies < 2:
		out.append("You need two goalies on the NHL roster (you have %d)." % goalies)
	var space := League.cap_space(team_id)
	if space < 0:
		out.append("Over the salary cap by %s. Send down or move a contract to get under it." % money(-space))
	return out


## Move a player between the NHL roster and the reserve list.
func set_roster_status(pid: int, status: String) -> void:
	var p := League.get_player(pid)
	if p == null:
		return
	p.roster_status = status
	var l: Lineup = lineups[p.team_id]
	l.drop_ineligible(League.nhl_roster(p.team_id))


# ------------------------------------------------------------------ simulation

## Plays the next game day. Returns box-score keys of your games played.
func sim_day() -> Array:
	if phase == "regular":
		return _sim_regular_day()
	if phase == "playoffs":
		return _sim_playoff_day()
	return []


func _sim_regular_day() -> Array:
	var next_day := -1
	for g in schedule:
		if not g["played"]:
			next_day = g["day"]
			break
	if next_day < 0:
		return []
	_recover(next_day)
	var mine := []
	for i in schedule.size():
		var g: Dictionary = schedule[i]
		if g["day"] == next_day and not g["played"]:
			_play_regular(i)
			if g["home"] == user_team_id or g["away"] == user_team_id:
				mine.append(str(i))
	day = next_day + 1
	_record_ranks()
	_trade_activity()
	if regular_season_over():
		_on_regular_season_over()
	day_advanced.emit()
	return mine


## Sims until your next game has been played. In the playoffs, once you're
## out, it sims one round at a time.
func sim_to_next_game() -> Array:
	if phase == "playoffs" and user_out():
		var round_now: int = playoffs["round"]
		while phase == "playoffs" and playoffs["round"] == round_now:
			sim_day()
		return []
	while not is_season_over():
		var mine := sim_day()
		if not mine.is_empty():
			return mine
		if phase == "playoffs" and user_out():
			return []
	return []


## Sims the rest of the regular season and stops when the playoffs begin.
func sim_to_end_of_regular_season() -> void:
	while phase == "regular":
		_sim_regular_day()
	day_advanced.emit()


## Sims until the current playoff round is over.
func sim_playoff_round() -> void:
	if phase != "playoffs":
		return
	var round_now: int = playoffs["round"]
	while phase == "playoffs" and playoffs["round"] == round_now:
		_sim_playoff_day()
	day_advanced.emit()


## Sims the rest of the playoffs.
func sim_to_end_of_playoffs() -> void:
	while phase == "playoffs":
		_sim_playoff_day()
	day_advanced.emit()


## Sets up lineups (goalie rotation, gaps) and plays one game.
func _simulate(home: String, away: String, seed_value: int, is_playoff: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var game_lineups := []
	for t in [home, away]:
		var l: Lineup = lineups[t]
		var eligible := League.nhl_roster(t)
		if t != user_team_id or not l.problems().is_empty():
			l.drop_ineligible(eligible)
			l.auto_fill(eligible, true)
		var gl := l
		if l.goalies[1] != 0:
			var starter_tired := condition_of(l.goalies[0]) < (70.0 if is_playoff else 82.0)
			var rest_day := not is_playoff and rng.randf() > l.starter_share
			if starter_tired or rest_day:
				gl = Lineup.from_dict(l.to_dict())
				gl.goalies = [l.goalies[1], l.goalies[0]]
		game_lineups.append(gl)
	return MatchSim.play(League.get_team(home), League.get_team(away), game_lineups[0], game_lineups[1],
		tactics[home], tactics[away], seed_value, is_playoff)


func _play_regular(index: int) -> void:
	var g: Dictionary = schedule[index]
	var res := _simulate(g["home"], g["away"], hash([world_seed, index]), false)
	g["played"] = true
	g["hg"] = res["home_goals"]
	g["ag"] = res["away_goals"]
	g["ot"] = res["ot"]
	_apply_result(res)
	if g["home"] == user_team_id or g["away"] == user_team_id:
		box_scores[str(index)] = res


func _apply_result(res: Dictionary) -> void:
	var home: String = res["home"]
	var away: String = res["away"]
	var hg: int = res["home_goals"]
	var ag: int = res["away_goals"]
	var ot: String = res["ot"]
	var winner := home if hg > ag else away
	for t in [home, away]:
		var r: Dictionary = standings[t]
		r["gp"] += 1
		r["gf"] += hg if t == home else ag
		r["ga"] += ag if t == home else hg
		var side := "home_" if t == home else "away_"
		var outcome := ""
		if t == winner:
			r["w"] += 1
			r["pts"] += 2
			r[side + "w"] += 1
			if ot != "SO":
				r["rw"] += 1
			outcome = "W"
		elif ot != "":
			r["otl"] += 1
			r["pts"] += 1
			r[side + "otl"] += 1
			outcome = "O"
		else:
			r["l"] += 1
			r[side + "l"] += 1
			outcome = "L"
		r["last10"].append(outcome)
		if r["last10"].size() > 10:
			r["last10"].pop_front()
		r["streak"] = _streak(r["streak"], outcome)

	_add_stats(res, skater_stats, goalie_season)
	_update_players(res, winner, skater_stats, goalie_season)

	if home == user_team_id or away == user_team_id:
		var mine_won := winner == user_team_id
		var opp := away if home == user_team_id else home
		var my_goals := hg if home == user_team_id else ag
		var their_goals := ag if home == user_team_id else hg
		var suffix := "" if ot == "" else " (%s)" % ot
		add_message("%s %d-%d vs %s%s" % ["Win" if mine_won else "Loss", my_goals, their_goals,
			League.get_team(opp).full_name(), suffix],
			"Record: %s. Open Schedule to see the box score." % record_string(user_team_id))


func _add_stats(res: Dictionary, skaters: Dictionary, goalies: Dictionary) -> void:
	for pid in res["stats"]:
		var line: Dictionary = res["stats"][pid]
		var key := str(pid)
		if not skaters.has(key):
			skaters[key] = {"gp": 0, "g": 0, "a": 0, "pts": 0, "shots": 0, "pim": 0, "pm": 0,
				"toi": 0, "ppg": 0, "shg": 0}
		var s: Dictionary = skaters[key]
		s["gp"] += 1
		for k in ["g", "a", "shots", "pim", "pm", "toi", "ppg", "shg"]:
			s[k] += line[k]
		s["pts"] = s["g"] + s["a"]
	for pid in res["goalies"]:
		var line: Dictionary = res["goalies"][pid]
		var key := str(pid)
		if not goalies.has(key):
			goalies[key] = {"gp": 0, "w": 0, "l": 0, "otl": 0, "sa": 0, "ga": 0, "so": 0, "toi": 0}
		var s: Dictionary = goalies[key]
		s["gp"] += 1
		s["sa"] += line["sa"]
		s["ga"] += line["ga"]
		s["toi"] += line["toi"]
		match line["decision"]:
			"W":
				s["w"] += 1
			"L":
				s["l"] += 1
			"OTL":
				s["otl"] += 1
		if line["ga"] == 0 and line["decision"] == "W":
			s["so"] += 1


## Form, condition and morale after a game.
func _update_players(res: Dictionary, winner: String, skaters: Dictionary, goalies: Dictionary) -> void:
	var played := {}
	for group in ["stats", "goalies"]:
		for pid in res[group]:
			var line: Dictionary = res[group][pid]
			var key := str(pid)
			played[key] = true
			var rating: float = line.get("rating", 6.5)
			var f: Array = form.get(key, [])
			f.append(rating)
			if f.size() > 5:
				f.pop_front()
			form[key] = f
			var season_line: Dictionary = skaters.get(key, goalies.get(key, {}))
			season_line["rsum"] = season_line.get("rsum", 0.0) + rating
			season_line["rn"] = season_line.get("rn", 0) + 1
			var drain: float = 9.0 if group == "goalies" else float(line["toi"]) / 60.0 * 0.55
			condition[key] = maxf(40.0, condition_of(int(pid)) - drain)
			var m := morale_of(int(pid))
			var team_won: bool = line["team"] == winner
			m += 3 if team_won else -2
			if rating >= 7.3:
				m += 2
			elif rating < 6.2:
				m -= 2
			morale[key] = clampi(m, 5, 100)
	# Regulars left out of the lineup get frustrated.
	for t in [res["home"], res["away"]]:
		var r := League.nhl_roster(t)
		for idx in mini(18, r.size()):
			var key := str(r[idx].id)
			if not played.has(key) and not r[idx].is_goalie():
				morale[key] = clampi(morale_of(r[idx].id) - 1, 5, 100)


## Players recover 6% condition per day since the last game day.
func _recover(to_day: int) -> void:
	var days := 1 if last_sim_day < 0 else maxi(0, to_day - last_sim_day)
	last_sim_day = to_day
	if days == 0:
		return
	for key in condition.keys():
		condition[key] = minf(100.0, condition[key] + 6.0 * days)


func _record_ranks() -> void:
	var rank := 1
	for row in standings_sorted():
		if not rank_history.has(row["team"]):
			rank_history[row["team"]] = []
		rank_history[row["team"]].append(rank)
		rank += 1


func _streak(current: String, outcome: String) -> String:
	var letter := outcome if outcome != "O" else "OT"
	if current.begins_with(letter) and (letter != "L" or not current.begins_with("OT")):
		var n := int(current.substr(letter.length()))
		return "%s%d" % [letter, n + 1]
	return "%s1" % letter


func _on_regular_season_over() -> void:
	var conf: String = League.get_team(user_team_id).conference
	var rank := 1
	for r in standings_sorted(func(t): return t.conference == conf):
		if r["team"] == user_team_id:
			break
		rank += 1
	awards = Awards.regular_season(self)
	_start_playoffs()
	var made_it := not user_series().is_empty()
	add_message("Regular season complete",
		"You finished %s with %d points, %s in the %s Conference. %s" % [
			record_string(user_team_id), standings[user_team_id]["pts"], ordinal(rank), conf,
			"You're in the playoffs! Check League > Playoffs for the bracket." if made_it
			else "You missed the playoffs. Continue to follow the race for the Stanton Cup."])
	season_finished.emit()


# ------------------------------------------------------------------ trades

func trades_open() -> bool:
	return phase == "regular" and day <= DEADLINE_DAY


func days_to_deadline() -> int:
	return DEADLINE_DAY - day


func pick_label(pick_id: String) -> String:
	var pk: Dictionary = picks.get(pick_id, {})
	if pk.is_empty():
		return pick_id
	var rnd: int = pk["round"]
	var nth: String = ["1st", "2nd", "3rd"][rnd - 1]
	var label := "%d %s round" % [pk["year"], nth]
	if pk["orig"] != pk["owner"]:
		label += " (from %s)" % League.get_team(pk["orig"]).name
	return label


func team_picks(team_id: String) -> Array:
	var out := []
	for pid in picks:
		if picks[pid]["owner"] == team_id:
			out.append(pid)
	out.sort()
	return out


## Moves players and picks, applies retained salary, fixes AI rosters and
## lines, and records the trade.
func execute_trade(trade: Dictionary) -> void:
	var a: String = trade["a"]
	var b: String = trade["b"]
	var retain: Dictionary = trade.get("retain", {})
	var record := {"day": day, "a": a, "b": b,
		"a_gives": trade["a_gives"].map(func(x): return TradeAI.describe(x)),
		"b_gives": trade["b_gives"].map(func(x): return TradeAI.describe(x))}
	for side in [["a_gives", a, b], ["b_gives", b, a]]:
		for asset in trade[side[0]]:
			if asset["type"] == "pick":
				picks[asset["id"]]["owner"] = side[2]
				continue
			var p := League.get_player(int(asset["id"]))
			var pct := float(retain.get(str(p.id), 0.0))
			if pct > 0.0:
				p.contract["retained"] = int(p.cap_hit() * pct)
				p.contract["retained_by"] = side[1]
			p.team_id = side[2]
			p.roster_status = "NHL"
			last_traded[str(p.id)] = day
			morale[str(p.id)] = 60
			trading_block.erase(str(p.id))
	for t in [a, b]:
		if t != user_team_id:
			_ai_fix_roster(t)
		var l: Lineup = lineups[t]
		l.drop_ineligible(League.nhl_roster(t))
		if t != user_team_id:
			l.auto_fill(League.nhl_roster(t), true)
	trade_history.append(record)
	TradeAI._cache_key = ""
	# Offers involving players who just moved are void.
	offers = offers.filter(func(o): return TradeAI.legality(o["trade"]) == "")
	if a == user_team_id or b == user_team_id:
		var other := b if a == user_team_id else a
		var got: Array = record["b_gives"] if a == user_team_id else record["a_gives"]
		var gave: Array = record["a_gives"] if a == user_team_id else record["b_gives"]
		var extra := ""
		if not roster_problems(user_team_id).is_empty():
			extra = "\n\nYour roster needs attention before the next game: " + roster_problems(user_team_id)[0]
		add_message("Trade completed with the %s" % League.get_team(other).name,
			"You get: %s\nYou give: %s\n\nNew arrivals start on the NHL roster; check your lines.%s" % [
				", ".join(got), ", ".join(gave), extra])
	else:
		add_message("League trade: %s and %s" % [League.get_team(a).name, League.get_team(b).name],
			"The %s get %s.\nThe %s get %s." % [League.get_team(b).name, ", ".join(record["a_gives"]),
				League.get_team(a).name, ", ".join(record["b_gives"])])


## AI teams keep a legal roster: at most 23 up, two goalies.
func _ai_fix_roster(team_id: String) -> void:
	var nhl := League.nhl_roster(team_id)
	var goalies := nhl.filter(func(p): return p.is_goalie())
	if goalies.size() < 2:
		for p in League.roster(team_id):
			if p.is_goalie() and not p.on_nhl_roster():
				p.roster_status = "NHL"
				break
	nhl = League.nhl_roster(team_id)
	var skaters := nhl.filter(func(p): return not p.is_goalie())
	skaters.sort_custom(func(x, y): return x.overall < y.overall)
	var i := 0
	while League.nhl_roster(team_id).size() > roster_max() and i < skaters.size():
		skaters[i].roster_status = "Reserve"
		i += 1


func accept_offer(offer_id: int) -> String:
	for o in offers:
		if o["id"] == offer_id:
			var e := TradeAI.evaluate(o["trade"], 1.0)
			if e["blocked"]:
				offers.erase(o)
				return e["message"]
			execute_trade(o["trade"])
			offers.erase(o)
			return ""
	return "That offer is no longer available."


func decline_offer(offer_id: int) -> void:
	offers = offers.filter(func(o): return o["id"] != offer_id)


## Daily trade market: AI-to-AI deals and offers for your players, busier as
## the deadline nears; announcements before and at the deadline.
func _trade_activity() -> void:
	offers = offers.filter(func(o): return o["expires"] >= day)
	var left := days_to_deadline()
	if left <= 14 and left > 0 and not flags.has("deadline_warning"):
		flags["deadline_warning"] = true
		add_message("Trade deadline in %d days" % left,
			"The deadline is %s. Contenders are buying and rebuilding teams are selling. Use Trades > Trade Center." % date_string(DEADLINE_DAY))
	if not trades_open():
		if not flags.has("deadline_passed") and phase == "regular":
			flags["deadline_passed"] = true
			add_message("The trade deadline has passed", "Rosters are set for the stretch run and playoffs.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, day, "trades"])
	var ai_ai_chance := 0.05 if left > 10 else (0.3 if left > 0 else 0.9)
	var tries := 1 if left > 0 else 3
	for _t in tries:
		if rng.randf() < ai_ai_chance:
			_try_ai_ai_trade(rng)
	var offer_chance := 0.05 + (0.1 if not trading_block.is_empty() else 0.0) + (0.15 if left <= 7 else 0.0)
	if offers.size() < 4 and rng.randf() < offer_chance:
		_try_ai_offer(rng)


func _try_ai_ai_trade(rng: RandomNumberGenerator) -> void:
	var sellers := []
	var buyers := []
	for t in League.teams:
		if t == user_team_id:
			continue
		match TradeAI.strategy(t):
			"rebuilding":
				sellers.append(t)
			"contender":
				buyers.append(t)
	if sellers.is_empty() or buyers.is_empty():
		return
	var seller: String = sellers[rng.randi_range(0, sellers.size() - 1)]
	var buyer: String = buyers[rng.randi_range(0, buyers.size() - 1)]
	var vets := League.nhl_roster(seller).filter(func(p): return p.age >= 26 and p.overall >= 70 and p.contract["years"] <= 2 and not p.is_goalie())
	if vets.is_empty():
		return
	vets.sort_custom(func(x, y): return x.overall > y.overall)
	var target = vets[rng.randi_range(0, mini(2, vets.size() - 1))]
	var trade := TradeAI.build_offer(buyer, seller, target.id)
	if trade.is_empty() or TradeAI.fair_for(trade, seller) < 0.95:
		return
	execute_trade(trade)


func _try_ai_offer(rng: RandomNumberGenerator) -> void:
	var mine := League.roster(user_team_id)
	if mine.is_empty():
		return
	var teams := League.teams.keys().filter(func(t): return t != user_team_id)
	var ai: String = teams[rng.randi_range(0, teams.size() - 1)]
	var targets := []
	for key in trading_block:
		var bp := League.get_player(int(key))
		if bp != null and bp.team_id == user_team_id:
			targets.append(bp)
	if targets.is_empty() or rng.randf() < 0.4:
		match TradeAI.strategy(ai):
			"contender":
				targets = mine.filter(func(p): return p.overall >= 74 and p.age >= 24 and p != mine[0])
			"rebuilding":
				targets = mine.filter(func(p): return p.age <= 23 and p.potential >= 70)
			_:
				targets = mine.filter(func(p): return p.overall >= 66 and p.overall <= 82)
	if targets.is_empty():
		return
	var target = targets[rng.randi_range(0, targets.size() - 1)]
	var trade := TradeAI.build_offer(ai, user_team_id, target.id)
	if trade.is_empty() or TradeAI.fair_for(trade, user_team_id) < 0.75:
		return
	var oid: int = int(flags.get("next_offer_id", 1))
	flags["next_offer_id"] = oid + 1
	offers.append({"id": oid, "trade": trade, "from": ai, "expires": day + 5})
	add_message("Trade offer from the %s" % League.get_team(ai).name,
		"They want %s and offer %s. Open Trades > Offers to respond (expires in 5 days)." % [
			target.full_name(), ", ".join(trade["b_gives"].map(func(x): return TradeAI.describe(x)))])


# ------------------------------------------------------------------ playoffs

## Top 3 in each division + 2 wild cards per conference.
func playoff_teams() -> Dictionary:
	var spots := {}
	for conf in ["Eastern", "Western"]:
		var taken := {}
		var divs := []
		for t in League.teams.values():
			if t.conference == conf and not divs.has(t.division):
				divs.append(t.division)
		for d in divs:
			var rows: Array = standings_sorted(func(t): return t.division == d)
			for r in rows.slice(0, 3):
				taken[r["team"]] = true
		var wild := 0
		for r in standings_sorted(func(t): return t.conference == conf):
			if wild >= 2:
				break
			if not taken.has(r["team"]):
				taken[r["team"]] = true
				wild += 1
		spots.merge(taken)
	return spots


func _league_rank() -> Dictionary:
	var rank := {}
	var i := 1
	for r in standings_sorted():
		rank[r["team"]] = i
		i += 1
	return rank


func _start_playoffs() -> void:
	phase = "playoffs"
	playoffs = {"series": [], "games": [], "round": 1, "next_day": day + 3, "champion": "", "finalist": ""}
	for conf in ["Eastern", "Western"]:
		var divs := []
		for t in League.team_list():
			if t.conference == conf and not divs.has(t.division):
				divs.append(t.division)
		var tops := {}
		var taken := {}
		for d in divs:
			var rows: Array = standings_sorted(func(t): return t.division == d)
			tops[d] = rows.slice(0, 3).map(func(r): return r["team"])
			for team in tops[d]:
				taken[team] = true
		var wild := []
		for r in standings_sorted(func(t): return t.conference == conf):
			if wild.size() >= 2:
				break
			if not taken.has(r["team"]):
				wild.append(r["team"])
		# The better division winner plays the second wild card.
		var rank := _league_rank()
		divs.sort_custom(func(a, b): return rank[tops[a][0]] < rank[tops[b][0]])
		var slot := 0
		for k in divs.size():
			var d: String = divs[k]
			var wc: String = wild[1] if k == 0 else wild[0]
			_add_series(1, conf, slot, tops[d][0], wc)
			_add_series(1, conf, slot + 1, tops[d][1], tops[d][2])
			slot += 2
	var mine := user_series()
	if not mine.is_empty():
		var opp: String = mine["low"] if mine["high"] == user_team_id else mine["high"]
		add_message("Playoffs: First Round vs %s" % UI.team_name(opp),
			"Best of seven. %s have home ice." % League.get_team(mine["high"]).name)


func _add_series(rnd: int, conf: String, slot: int, a: String, b: String) -> void:
	var rank := _league_rank()
	var high := a if rank[a] < rank[b] else b
	var low := b if high == a else a
	playoffs["series"].append({"id": playoffs["series"].size(), "round": rnd, "conf": conf, "slot": slot,
		"high": high, "low": low, "w_high": 0, "w_low": 0, "winner": "", "games": []})


func series_in_round(rnd: int) -> Array:
	return playoffs.get("series", []).filter(func(s): return s["round"] == rnd)


## True when you missed the playoffs or have been eliminated.
func user_out() -> bool:
	var s := user_series()
	return s.is_empty() or (s["winner"] != "" and s["winner"] != user_team_id)


## Your current (or last) series, or {} if you missed the playoffs.
func user_series() -> Dictionary:
	var found := {}
	for s in playoffs.get("series", []):
		if s["high"] == user_team_id or s["low"] == user_team_id:
			found = s
	return found


func _sim_playoff_day() -> Array:
	var game_day: int = playoffs["next_day"]
	_recover(game_day)
	var mine := []
	for s in series_in_round(playoffs["round"]):
		if s["winner"] != "":
			continue
		var n: int = s["w_high"] + s["w_low"] + 1
		var home: String = s["high"] if n in [1, 2, 5, 7] else s["low"]
		var away: String = s["low"] if home == s["high"] else s["high"]
		var idx: int = playoffs["games"].size()
		var res := _simulate(home, away, hash([world_seed, "playoffs", idx]), true)
		var hg: int = res["home_goals"]
		var ag: int = res["away_goals"]
		var winner := home if hg > ag else away
		playoffs["games"].append({"day": game_day, "home": home, "away": away, "hg": hg, "ag": ag,
			"ot": res["ot"], "series": s["id"], "game": n})
		s["games"].append(idx)
		if winner == s["high"]:
			s["w_high"] += 1
		else:
			s["w_low"] += 1
		_add_stats(res, playoff_skaters, playoff_goalies)
		_update_players(res, winner, playoff_skaters, playoff_goalies)
		var involved: bool = home == user_team_id or away == user_team_id
		if involved:
			var key := "p%d" % idx
			box_scores[key] = res
			mine.append(key)
		if s["w_high"] == 4 or s["w_low"] == 4:
			s["winner"] = s["high"] if s["w_high"] == 4 else s["low"]
			_on_series_won(s)
	day = game_day + 1
	playoffs["next_day"] = game_day + 2
	# Round over?
	var open := series_in_round(playoffs["round"]).filter(func(x): return x["winner"] == "")
	if open.is_empty():
		_next_round()
	day_advanced.emit()
	return mine


func _on_series_won(s: Dictionary) -> void:
	var loser: String = s["low"] if s["winner"] == s["high"] else s["high"]
	var score := "%d-%d" % [maxi(s["w_high"], s["w_low"]), mini(s["w_high"], s["w_low"])]
	var rname: String = ROUND_NAMES[s["round"] - 1]
	if s["winner"] == user_team_id:
		add_message("Series won! %s %s" % [rname, score],
			"You beat the %s %s. On to the next round." % [League.get_team(loser).full_name(), score])
	elif loser == user_team_id:
		add_message("Eliminated in the %s" % rname,
			"The %s beat you %s. Continue to follow the rest of the playoffs." % [League.get_team(s["winner"]).full_name(), score])


func _next_round() -> void:
	var rnd: int = playoffs["round"]
	var done := series_in_round(rnd)
	if rnd == 4:
		var final: Dictionary = done[0]
		playoffs["champion"] = final["winner"]
		playoffs["finalist"] = final["low"] if final["winner"] == final["high"] else final["high"]
		_finish_season()
		return
	playoffs["round"] = rnd + 1
	playoffs["next_day"] = playoffs["next_day"] + 1
	if rnd < 3:
		for conf in ["Eastern", "Western"]:
			var prev := done.filter(func(s): return s["conf"] == conf)
			prev.sort_custom(func(a, b): return a["slot"] < b["slot"])
			for k in range(0, prev.size(), 2):
				_add_series(rnd + 1, conf, k / 2, prev[k]["winner"], prev[k + 1]["winner"])
	else:
		var east: Dictionary = done.filter(func(s): return s["conf"] == "Eastern")[0]
		var west: Dictionary = done.filter(func(s): return s["conf"] == "Western")[0]
		_add_series(4, "Final", 0, east["winner"], west["winner"])
	var mine := user_series()
	if not mine.is_empty() and mine["round"] == rnd + 1:
		var opp: String = mine["low"] if mine["high"] == user_team_id else mine["high"]
		add_message("%s vs %s" % [ROUND_NAMES[rnd], UI.team_name(opp)], "Best of seven. Good luck.")


func _finish_season() -> void:
	phase = "done"
	awards.append_array(Awards.postseason(self))
	var champ: String = playoffs["champion"]
	if champ == user_team_id:
		add_message("STANTON CUP CHAMPIONS!",
			"The %s are champions! You took over the club and won it all. Check League > Awards for the season's honors." % League.get_team(champ).full_name())
	else:
		add_message("The %s win the Stanton Cup" % League.get_team(champ).full_name(),
			"They beat the %s in the final. Check League > Awards for the season's honors." % League.get_team(playoffs["finalist"]).full_name())
	for a in awards:
		if a.get("team", "") == user_team_id:
			add_message("%s: %s" % [a["name"], a.get("winner_name", "")], a["desc"])


# ------------------------------------------------------------------ queries

func record_string(team_id: String) -> String:
	var r: Dictionary = standings[team_id]
	return "%d-%d-%d" % [r["w"], r["l"], r["otl"]]


## Standings rows ({team, ...record}) for teams passing `filter`, sorted NHL-style:
## points, then fewer games played, then regulation wins, then goal differential.
func standings_sorted(filter: Callable = Callable()) -> Array:
	var rows := []
	for id in standings:
		if filter.is_valid() and not filter.call(League.get_team(id)):
			continue
		var row: Dictionary = standings[id].duplicate()
		row["team"] = id
		rows.append(row)
	rows.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		if a["gp"] != b["gp"]:
			return a["gp"] < b["gp"]
		if a["rw"] != b["rw"]:
			return a["rw"] > b["rw"]
		return (a["gf"] - a["ga"]) > (b["gf"] - b["ga"]))
	return rows


func player_line(pid: int) -> Dictionary:
	var key := str(pid)
	if skater_stats.has(key):
		return skater_stats[key]
	if goalie_season.has(key):
		return goalie_season[key]
	return {}


func condition_of(pid: int) -> float:
	return float(condition.get(str(pid), 100.0))


func morale_of(pid: int) -> int:
	return int(morale.get(str(pid), 65))


func form_of(pid: int) -> Array:
	return form.get(str(pid), [])


## Season average match rating, or 0 if he hasn't played.
func avg_rating(pid: int) -> float:
	var line := player_line(pid)
	var n: int = line.get("rn", 0)
	return float(line.get("rsum", 0.0)) / n if n > 0 else 0.0


## Key Player / Important Player / Regular / Rotation / Depth / Prospect.
func squad_status(p) -> String:
	if not p.on_nhl_roster():
		return "Reserve"
	var r := League.roster(p.team_id)
	var rank := r.find(p)
	if p.age <= 21 and rank >= 9:
		return "Prospect"
	if rank < 3:
		return "Key Player"
	if rank < 8:
		return "Important Player"
	if rank < 15:
		return "Regular Starter"
	if rank < 20:
		return "Rotation"
	return "Depth"


# ------------------------------------------------------------------ save / load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"version": 2,
		"league": League.to_dict(),
		"user_team_id": user_team_id, "seed": world_seed, "day": day, "phase": phase,
		"schedule": schedule, "box_scores": box_scores, "standings": standings,
		"skater_stats": skater_stats, "goalie_season": goalie_season,
		"playoff_skaters": playoff_skaters, "playoff_goalies": playoff_goalies,
		"playoffs": playoffs, "awards": awards, "inbox": inbox,
		"picks": picks, "trade_history": trade_history, "offers": offers,
		"trading_block": trading_block, "flags": flags, "last_traded": last_traded,
		"form": form, "morale": morale, "condition": condition, "rank_history": rank_history,
		"last_sim_day": last_sim_day,
		"lineups": _map_values(lineups, func(l): return l.to_dict()),
		"tactics": _map_values(tactics, func(t): return t.to_dict()),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func load_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	League.load_from_dict(data["league"])
	user_team_id = data["user_team_id"]
	world_seed = int(data["seed"])
	day = int(data["day"])
	phase = data.get("phase", "regular")
	schedule = _intify(data["schedule"])
	box_scores = _intify(data["box_scores"])
	standings = _intify(data["standings"])
	skater_stats = _intify(data["skater_stats"])
	goalie_season = _intify(data["goalie_season"])
	playoff_skaters = _intify(data.get("playoff_skaters", {}))
	playoff_goalies = _intify(data.get("playoff_goalies", {}))
	playoffs = _intify(data.get("playoffs", {}))
	awards = _intify(data.get("awards", []))
	picks = _intify(data.get("picks", {}))
	trade_history = _intify(data.get("trade_history", []))
	offers = _intify(data.get("offers", []))
	trading_block = data.get("trading_block", {})
	flags = _intify(data.get("flags", {}))
	last_traded = _intify(data.get("last_traded", {}))
	inbox = _intify(data["inbox"])
	form = data.get("form", {})
	morale = _intify(data.get("morale", {}))
	condition = data.get("condition", {})
	rank_history = _intify(data.get("rank_history", {}))
	last_sim_day = int(data.get("last_sim_day", -1))
	lineups.clear()
	for t in data["lineups"]:
		lineups[t] = Lineup.from_dict(data["lineups"][t])
	tactics.clear()
	for t in data["tactics"]:
		tactics[t] = Tactics.from_dict(data["tactics"][t])
	active = true
	return true


## JSON turns every number into a float; turn whole numbers back into ints
## (recursively, through dictionaries and arrays).
func _intify(d: Variant) -> Variant:
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			d[k] = _intify(d[k])
	elif typeof(d) == TYPE_ARRAY:
		for i in d.size():
			d[i] = _intify(d[i])
	elif typeof(d) == TYPE_FLOAT and d == floorf(d):
		return int(d)
	return d


func _map_values(d: Dictionary, f: Callable) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = f.call(d[k])
	return out


# ------------------------------------------------------------------ formatting

static func money(amount: int) -> String:
	var neg := "-" if amount < 0 else ""
	var m := absf(amount) / 1_000_000.0
	if m >= 1.0:
		return "%s$%.2fM" % [neg, m]
	return "%s$%dK" % [neg, int(absf(amount) / 1000.0)]


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
	return "%d%s" % [n, suffix]
