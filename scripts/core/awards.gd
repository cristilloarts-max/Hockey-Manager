class_name Awards
extends RefCounted
## End-of-season honors (spoofed trophy names). Each award is a Dictionary:
## {name, kind ("player"/"team"), desc, winner (pid or team id), winner_name,
##  team, line (stat summary), finalists: [{name, team, line}]}


static func regular_season(game) -> Array:
	var out := []
	var sk: Dictionary = game.skater_stats
	var gl: Dictionary = game.goalie_season
	var skaters := _players(sk, func(p, s): return not p.is_goalie() and s["gp"] >= 20)
	var goalies := _players(gl, func(p, s): return p.is_goalie() and s["gp"] >= 30)

	var team_pts := func(p): return float(game.standings[p.team_id]["pts"])
	var sv := func(s): return float(s["sa"] - s["ga"]) / s["sa"] if s["sa"] > 0 else 0.0

	# Hartwell Trophy: MVP.
	var mvp := []
	for e in skaters:
		var s: Dictionary = e[1]
		mvp.append([e[0], s, s["pts"] + 0.5 * s["g"] + game.avg_rating(e[0].id) * 8 + team_pts.call(e[0]) * 0.3,
			"%d G, %d A, %d PTS" % [s["g"], s["a"], s["pts"]]])
	for e in goalies:
		var s: Dictionary = e[1]
		if s["gp"] >= 45:
			mvp.append([e[0], s, (sv.call(s) - 0.9) * 3000 + s["w"] * 1.2 + team_pts.call(e[0]) * 0.3,
				"%d W, %.3f SV%%" % [s["w"], sv.call(s)]])
	out.append(_player_award("Hartwell Trophy", "Most valuable player", mvp))

	out.append(_player_award("Art Rose Trophy", "Most points in the regular season",
		skaters.map(func(e): return [e[0], e[1], e[1]["pts"] + e[1]["g"] * 0.001, "%d points (%d G, %d A)" % [e[1]["pts"], e[1]["g"], e[1]["a"]]])))

	out.append(_player_award("Rocket Richter Trophy", "Most goals in the regular season",
		skaters.map(func(e): return [e[0], e[1], e[1]["g"] + e[1]["shots"] * -0.0001, "%d goals" % e[1]["g"]])))

	var dmen := skaters.filter(func(e): return e[0].is_defense() and e[1]["gp"] >= 50)
	out.append(_player_award("Norrison Trophy", "Best defenseman",
		dmen.map(func(e): return [e[0], e[1], e[1]["pts"] + e[1]["pm"] * 0.5 + game.avg_rating(e[0].id) * 15
			+ float(e[1]["toi"]) / e[1]["gp"] / 60.0 * 1.5,
			"%d PTS, %+d, %s TOI" % [e[1]["pts"], e[1]["pm"], UI.fmt_toi(float(e[1]["toi"]) / e[1]["gp"])]])))

	var starters := goalies.filter(func(e): return e[1]["gp"] >= 40)
	out.append(_player_award("Vezino Trophy", "Best goaltender",
		starters.map(func(e): return [e[0], e[1], (sv.call(e[1]) - 0.9) * 2500 + e[1]["w"] * 0.8 + e[1]["so"] * 2,
			"%d W, %.3f SV%%, %d SO" % [e[1]["w"], sv.call(e[1]), e[1]["so"]]])))

	var rookies := []
	for e in skaters:
		if e[0].nhl_games - e[0].season_gp <= 25 and e[0].age <= 25:
			rookies.append([e[0], e[1], e[1]["pts"] + game.avg_rating(e[0].id) * 5, "%d G, %d A, %d PTS" % [e[1]["g"], e[1]["a"], e[1]["pts"]]])
	for e in goalies:
		if e[0].nhl_games - e[0].season_gp <= 25 and e[0].age <= 26:
			rookies.append([e[0], e[1], (sv.call(e[1]) - 0.9) * 2000 + e[1]["w"], "%d W, %.3f SV%%" % [e[1]["w"], sv.call(e[1])]])
	out.append(_player_award("Caldor Trophy", "Rookie of the year", rookies))

	var fwds := skaters.filter(func(e): return not e[0].is_defense() and e[1]["gp"] >= 60)
	out.append(_player_award("Selkirk Trophy", "Best defensive forward",
		fwds.map(func(e): return [e[0], e[1], e[0].detail("defensive_awareness") * 2.0 + e[1]["pm"] * 0.6
			+ game.avg_rating(e[0].id) * 6 + e[1]["pts"] * 0.15,
			"%+d, %d PTS" % [e[1]["pm"], e[1]["pts"]]])))

	# Team awards.
	var table: Array = game.standings_sorted()
	var best: Dictionary = table[0]
	out.append(_team_award("Presidents' Shield", "Best regular-season record", best["team"],
		"%d points (%s)" % [best["pts"], game.record_string(best["team"])]))
	var fewest := table.duplicate()
	fewest.sort_custom(func(a, b): return a["ga"] < b["ga"])
	out.append(_team_award("Jenning Trophy", "Fewest goals allowed", fewest[0]["team"], "%d goals against" % fewest[0]["ga"]))

	# Jack Addams Award: the coach whose team beat expectations by the most.
	var by_strength := League.team_list()
	by_strength.sort_custom(func(a, b): return League.team_strength(a.id) > League.team_strength(b.id))
	var expected := {}
	for i in by_strength.size():
		expected[by_strength[i].id] = i
	var coach := ""
	var best_jump := -999
	for i in table.size():
		var jump: int = expected[table[i]["team"]] - i
		if jump > best_jump:
			best_jump = jump
			coach = table[i]["team"]
	var coach_award := _team_award("Jack Addams Award", "Coach of the year", coach,
		"Predicted %s, finished %s" % [Game.ordinal(expected[coach] + 1), Game.ordinal(expected[coach] + 1 - best_jump)])
	coach_award["winner_name"] = "You" if coach == game.user_team_id else "Head coach, %s" % League.get_team(coach).name
	out.append(coach_award)
	return out


static func postseason(game) -> Array:
	var out := []
	var champ: String = game.playoffs["champion"]
	out.append(_team_award("Stanton Cup", "League champion", champ, "Beat the %s in the final" % League.get_team(game.playoffs["finalist"]).name))
	for s in game.series_in_round(3):
		var east: bool = s["conf"] == "Eastern"
		out.append(_team_award("Wallace Trophy" if east else "Campton Bowl",
			"%s Conference champion" % s["conf"], s["winner"], "%s Conference final winner" % s["conf"]))

	# Conn Smith Trophy: playoff MVP, mostly from the two finalists.
	var finalists := [champ, game.playoffs["finalist"]]
	var cands := []
	for key in game.playoff_skaters:
		var p := League.get_player(int(key))
		var s: Dictionary = game.playoff_skaters[key]
		if p == null or not finalists.has(p.team_id):
			continue
		var bonus := 1.25 if p.team_id == champ else 1.0
		var avg: float = float(s.get("rsum", 0.0)) / maxf(1.0, s.get("rn", 0))
		cands.append([p, s, (s["pts"] + 0.5 * s["g"] + avg * 3) * bonus, "%d G, %d A in %d GP" % [s["g"], s["a"], s["gp"]]])
	for key in game.playoff_goalies:
		var p := League.get_player(int(key))
		var s: Dictionary = game.playoff_goalies[key]
		if p == null or not finalists.has(p.team_id) or s["sa"] == 0:
			continue
		var svp: float = float(s["sa"] - s["ga"]) / s["sa"]
		var bonus := 1.25 if p.team_id == champ else 1.0
		cands.append([p, s, ((svp - 0.9) * 900 + s["w"] * 1.6 + s["so"] * 2) * bonus, "%d W, %.3f SV%%" % [s["w"], svp]])
	out.append(_player_award("Conn Smith Trophy", "Playoff MVP", cands))
	return out


## [[Player, stat line]] for stats passing `filter`.
static func _players(stats: Dictionary, filter: Callable) -> Array:
	var out := []
	for key in stats:
		var p := League.get_player(int(key))
		var s: Dictionary = stats[key]
		if p != null and filter.call(p, s):
			out.append([p, s])
	return out


## candidates: [[Player, line, score, text]]; top score wins, next two are finalists.
static func _player_award(name: String, desc: String, candidates: Array) -> Dictionary:
	candidates.sort_custom(func(a, b): return a[2] > b[2])
	var award := {"name": name, "kind": "player", "desc": desc, "winner": 0, "winner_name": "-",
		"team": "", "line": "", "finalists": []}
	if candidates.is_empty():
		return award
	var w = candidates[0]
	award["winner"] = w[0].id
	award["winner_name"] = w[0].full_name()
	award["team"] = w[0].team_id
	award["line"] = w[3]
	for c in candidates.slice(1, 3):
		award["finalists"].append({"name": c[0].full_name(), "team": c[0].team_id, "line": c[3], "id": c[0].id})
	return award


static func _team_award(name: String, desc: String, team_id: String, line: String) -> Dictionary:
	return {"name": name, "kind": "team", "desc": desc, "winner": team_id,
		"winner_name": League.get_team(team_id).full_name(), "team": team_id, "line": line, "finalists": []}
