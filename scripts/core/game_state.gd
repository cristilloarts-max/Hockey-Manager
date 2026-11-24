extends Node
## Autoload "Game": the running save: your team, the calendar, schedule,
## results, standings, stats, lineups and tactics.

signal day_advanced
signal season_finished

const SAVE_PATH := "user://save.json"
const SEASON_START := {"year": 2026, "month": 10, "day": 7, "hour": 12}
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const WEEKDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

var active := false
var user_team_id := ""
var world_seed := 0
var day := 0                 ## next day to be played
var schedule := []           ## {day, home, away, played, hg, ag, ot}
var box_scores := {}         ## schedule index (String) -> full result (your games only)
var standings := {}          ## team -> record
var skater_stats := {}       ## pid (String) -> season line
var goalie_season := {}      ## pid (String) -> season line
var lineups := {}            ## team -> Lineup
var tactics := {}            ## team -> Tactics
var inbox := []              ## {day, title, body}
var form := {}               ## pid (String) -> last 5 match ratings
var morale := {}             ## pid (String) -> 0..100
var condition := {}          ## pid (String) -> 0..100 (fitness for the next game)
var rank_history := {}       ## team -> league rank after each game day
var last_sim_day := -1


# ------------------------------------------------------------------ setup

func new_game(team_id: String, game_seed: int = 0) -> void:
	if League.teams.is_empty():
		League.load_default()
	user_team_id = team_id
	world_seed = game_seed if game_seed != 0 else int(Time.get_unix_time_from_system())
	day = 0
	box_scores.clear()
	skater_stats.clear()
	goalie_season.clear()
	inbox.clear()
	form.clear()
	condition.clear()
	rank_history.clear()
	last_sim_day = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	morale.clear()
	for pid in League.players:
		morale[str(pid)] = rng.randi_range(55, 80)
	schedule = Schedule.generate(League.team_list(), rng)
	for g in schedule:
		g["played"] = false
	standings.clear()
	lineups.clear()
	tactics.clear()
	for id in League.teams:
		standings[id] = _empty_record()
		var l := Lineup.new()
		l.auto_fill(League.roster(id))
		lineups[id] = l
		tactics[id] = Tactics.new()
	active = true
	var team := League.get_team(team_id)
	add_message("Welcome to the %s" % team.full_name(),
		"The owner has handed you the keys. Check your roster and lines, then hit Continue to start the season.\n\nCap space: %s." % money(League.cap_space(team_id)))


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


# ------------------------------------------------------------------ simulation

## Plays the next day that has games. Returns schedule indexes of your games played.
func sim_day() -> Array:
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
			_play_game(i)
			if g["home"] == user_team_id or g["away"] == user_team_id:
				mine.append(i)
	day = next_day + 1
	_record_ranks()
	day_advanced.emit()
	if is_season_over():
		_on_season_over()
	return mine


## Sims day by day until your next game has been played.
func sim_to_next_game() -> Array:
	while not is_season_over():
		var mine := sim_day()
		if not mine.is_empty():
			return mine
	return []


func sim_to_end() -> void:
	while not is_season_over():
		for i in schedule.size():
			if not schedule[i]["played"]:
				var d: int = schedule[i]["day"]
				_recover(d)
				for j in range(i, schedule.size()):
					if schedule[j]["day"] != d:
						break
					if not schedule[j]["played"]:
						_play_game(j)
				day = d + 1
				_record_ranks()
				break
	day_advanced.emit()
	_on_season_over()


func _play_game(index: int) -> void:
	var g: Dictionary = schedule[index]
	var teams := [g["home"], g["away"]]
	for t in teams:
		var l: Lineup = lineups[t]
		if t == user_team_id:
			if not l.problems().is_empty():
				l.auto_fill(League.roster(t), true)
		else:
			l.auto_fill(League.roster(t), false)
	var res := MatchSim.play(League.get_team(g["home"]), League.get_team(g["away"]),
		lineups[g["home"]], lineups[g["away"]], tactics[g["home"]], tactics[g["away"]],
		hash([world_seed, index]))
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

	for pid in res["stats"]:
		var line: Dictionary = res["stats"][pid]
		var key := str(pid)
		if not skater_stats.has(key):
			skater_stats[key] = {"gp": 0, "g": 0, "a": 0, "pts": 0, "shots": 0, "pim": 0, "pm": 0,
				"toi": 0, "ppg": 0, "shg": 0}
		var s: Dictionary = skater_stats[key]
		s["gp"] += 1
		for k in ["g", "a", "shots", "pim", "pm", "toi", "ppg", "shg"]:
			s[k] += line[k]
		s["pts"] = s["g"] + s["a"]

	for pid in res["goalies"]:
		var line: Dictionary = res["goalies"][pid]
		var key := str(pid)
		if not goalie_season.has(key):
			goalie_season[key] = {"gp": 0, "w": 0, "l": 0, "otl": 0, "sa": 0, "ga": 0, "so": 0, "toi": 0}
		var s: Dictionary = goalie_season[key]
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

	_update_players(res, winner)

	if home == user_team_id or away == user_team_id:
		var mine_won := winner == user_team_id
		var opp := away if home == user_team_id else home
		var my_goals := hg if home == user_team_id else ag
		var their_goals := ag if home == user_team_id else hg
		var suffix := "" if ot == "" else " (%s)" % ot
		add_message("%s %d-%d vs %s%s" % ["Win" if mine_won else "Loss", my_goals, their_goals,
			League.get_team(opp).full_name(), suffix],
			"Record: %s. Open Schedule to see the box score." % record_string(user_team_id))


## Form, condition and morale after a game.
func _update_players(res: Dictionary, winner: String) -> void:
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
			var season_line: Dictionary = skater_stats.get(key, goalie_season.get(key, {}))
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
		var r := League.roster(t)
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


func _streak(current: String, outcome: String) -> String:
	var letter := outcome if outcome != "O" else "OT"
	if current.begins_with(letter) and (letter != "L" or not current.begins_with("OT")):
		var n := int(current.substr(letter.length()))
		return "%s%d" % [letter, n + 1]
	return "%s1" % letter


func _on_season_over() -> void:
	var conf: String = League.get_team(user_team_id).conference
	var rank := 1
	for r in standings_sorted(func(t): return t.conference == conf):
		if r["team"] == user_team_id:
			break
		rank += 1
	add_message("Regular season complete",
		"You finished %s with %d points, %s in the %s Conference. Playoffs arrive in phase 2." % [
			record_string(user_team_id), standings[user_team_id]["pts"], ordinal(rank), conf])
	season_finished.emit()


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


# ------------------------------------------------------------------ save / load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"version": 1,
		"league": League.to_dict(),
		"user_team_id": user_team_id, "seed": world_seed, "day": day,
		"schedule": schedule, "box_scores": box_scores, "standings": standings,
		"skater_stats": skater_stats, "goalie_season": goalie_season, "inbox": inbox,
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
	schedule = _intify(data["schedule"])
	box_scores = _intify(data["box_scores"])
	standings = _intify(data["standings"])
	skater_stats = _intify(data["skater_stats"])
	goalie_season = _intify(data["goalie_season"])
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
