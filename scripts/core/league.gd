extends Node
## Autoload "League": the static world: teams, players, finances.
## Loaded from res://data/league.json (built by tools/build_league.py).

const DATA_PATH := "res://data/league.json"

var season_label := ""
var finances := {}
var teams := {}      ## id -> Team
var players := {}    ## id -> Player
## League-average ratings the match sim normalises against.
var norms := {"attack": 12.0, "defense": 12.0, "shooting": 12.0, "goalie": 13.0}


func load_default() -> bool:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % DATA_PATH)
		return false
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("league.json is not valid JSON")
		return false
	load_from_dict(data)
	return true


func load_from_dict(data: Dictionary) -> void:
	teams.clear()
	players.clear()
	season_label = data.get("season", "")
	finances = {}
	for k in data["finances"]:
		finances[k] = int(data["finances"][k])
	for t in data["teams"]:
		var team := Team.from_dict(t)
		teams[team.id] = team
	for p in data["players"]:
		var player := Player.from_dict(p)
		players[player.id] = player
	compute_norms()


func to_dict() -> Dictionary:
	return {
		"season": season_label,
		"finances": finances,
		"teams": teams.values().map(func(t): return t.to_dict()),
		"players": players.values().map(func(p): return p.to_dict()),
	}


func get_team(id: String) -> Team:
	return teams.get(id)


func get_player(id: int) -> Player:
	return players.get(id)


## Teams sorted by city then nickname.
func team_list() -> Array:
	var list := teams.values()
	list.sort_custom(func(a, b): return a.full_name() < b.full_name())
	return list


func roster(team_id: String) -> Array:
	var list := players.values().filter(func(p): return p.team_id == team_id)
	list.sort_custom(func(a, b): return a.overall > b.overall)
	return list


func payroll(team_id: String) -> int:
	var total := 0
	for p in roster(team_id):
		total += p.cap_hit()
	return total


func cap_space(team_id: String) -> int:
	return int(finances.get("salary_cap", 0)) - payroll(team_id)


## Average overall of a team's best 18 skaters + best goalie.
func team_strength(team_id: String) -> float:
	var r := roster(team_id)
	var skaters := r.filter(func(p): return not p.is_goalie()).slice(0, 18)
	var goalies := r.filter(func(p): return p.is_goalie()).slice(0, 1)
	var total := 0.0
	for p in skaters:
		total += p.overall
	for g in goalies:
		total += g.overall * 3   # a starting goalie matters a lot
	return total / maxf(1.0, skaters.size() + goalies.size() * 3)


## Computes league-average unit ratings from every team's auto lineup.
func compute_norms() -> void:
	var att := 0.0
	var dfn := 0.0
	var n := 0
	var shoot_w := 0.0
	var shoot_sum := 0.0
	var goalie_sum := 0.0
	var goalie_n := 0
	for team_id in teams:
		var lineup := Lineup.new()
		lineup.auto_fill(roster(team_id))
		for line in lineup.forwards:
			for s in 3:
				var p := get_player(line[s])
				if p == null:
					continue
				var spot: String = Lineup.FWD_SLOTS[s]
				att += MatchSim.skater_attack(p, spot)
				dfn += MatchSim.skater_defense(p, spot)
				n += 1
				var w := pow(p.attr("shooting"), 2)
				shoot_sum += MatchSim.shooting_value(p, spot) * w
				shoot_w += w
		for pair in lineup.defense:
			for s in 2:
				var p := get_player(pair[s])
				if p == null:
					continue
				var spot: String = Lineup.D_SLOTS[s]
				att += MatchSim.skater_attack(p, spot)
				dfn += MatchSim.skater_defense(p, spot)
				n += 1
				var w := pow(p.attr("shooting"), 2) * 0.55
				shoot_sum += MatchSim.shooting_value(p, spot) * w
				shoot_w += w
		var g := get_player(lineup.goalies[0])
		if g != null:
			goalie_sum += MatchSim.goalie_rating(g)
			goalie_n += 1
	if n > 0:
		norms["attack"] = att / n
		norms["defense"] = dfn / n
	if shoot_w > 0:
		norms["shooting"] = shoot_sum / shoot_w
	if goalie_n > 0:
		norms["goalie"] = goalie_sum / goalie_n
