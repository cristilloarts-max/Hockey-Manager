class_name Player
extends RefCounted
## A player in the league. Ratings come from data/league.json.

const SKATER_SPOTS := ["C", "LW", "RW", "LD", "RD"]

## Familiarity tiers: [min familiarity, label, rating multiplier].
const FAMILIARITY_TIERS := [
	[18, "Natural", 1.00],
	[14, "Accomplished", 0.97],
	[10, "Competent", 0.92],
	[6, "Unconvincing", 0.85],
	[1, "Awkward", 0.75],
]

var id: int = 0
var first_name: String = ""
var last_name: String = ""
var team_id: String = ""
var position: String = ""          ## preferred spot: C, LW, RW, LD, RD or G
var comfortable: Array = []        ## other spots with familiarity >= 14
var prefers_off_side: bool = false
var familiarity: Dictionary = {}   ## spot -> 1..20
var shoots: String = "L"
var number: int = 0
var birth_date: String = ""
var age: int = 0
var nationality: String = ""
var height_cm: int = 0
var weight_kg: int = 0
var nhl_games: int = 0
var overall: int = 50
var potential: int = 50
var attributes: Dictionary = {}    ## name -> 1..20
var contract: Dictionary = {}      ## cap_hit, years, elc, expiry_status, no_trade_clause


static func from_dict(d: Dictionary) -> Player:
	var p := Player.new()
	p.id = int(d["id"])
	p.first_name = d["first_name"]
	p.last_name = d["last_name"]
	p.team_id = d["team"]
	p.shoots = d.get("shoots", "L")
	p.number = int(d["number"]) if d.get("number") != null else 0
	p.birth_date = d.get("birth_date", "")
	p.age = int(d.get("age", 25))
	p.nationality = d.get("nationality", "")
	p.height_cm = int(d["height_cm"]) if d.get("height_cm") != null else 0
	p.weight_kg = int(d["weight_kg"]) if d.get("weight_kg") != null else 0
	p.nhl_games = int(d.get("nhl_games", 0))
	p.overall = int(d["overall"])
	p.potential = int(d["potential"])
	for k in d["attributes"]:
		p.attributes[k] = int(d["attributes"][k])
	var pos: Dictionary = d["positions"]
	p.position = pos["preferred"]
	p.comfortable = pos.get("comfortable", [])
	p.prefers_off_side = bool(pos.get("prefers_off_side", false))
	for k in pos["familiarity"]:
		p.familiarity[k] = int(pos["familiarity"][k])
	var c: Dictionary = d["contract"]
	p.contract = {
		"cap_hit": int(c["cap_hit"]),
		"years": int(c["years"]),
		"elc": bool(c.get("elc", false)),
		"expiry_status": c.get("expiry_status", "UFA"),
		"no_trade_clause": bool(c.get("no_trade_clause", false)),
	}
	return p


func to_dict() -> Dictionary:
	return {
		"id": id, "first_name": first_name, "last_name": last_name, "team": team_id,
		"shoots": shoots, "number": number, "birth_date": birth_date, "age": age,
		"nationality": nationality, "height_cm": height_cm, "weight_kg": weight_kg,
		"nhl_games": nhl_games, "overall": overall, "potential": potential,
		"attributes": attributes,
		"positions": {"preferred": position, "comfortable": comfortable,
			"prefers_off_side": prefers_off_side, "familiarity": familiarity},
		"contract": contract,
	}


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func short_name() -> String:
	return "%s. %s" % [first_name.substr(0, 1), last_name]


func is_goalie() -> bool:
	return position == "G"


func is_defense() -> bool:
	return position == "LD" or position == "RD"


func attr(name: String) -> int:
	return int(attributes.get(name, 1))


func familiarity_at(spot: String) -> int:
	if is_goalie():
		return 20 if spot == "G" else 1
	return int(familiarity.get(spot, 1))


func familiarity_tier(spot: String) -> Array:
	var f := familiarity_at(spot)
	for tier in FAMILIARITY_TIERS:
		if f >= tier[0]:
			return tier
	return FAMILIARITY_TIERS[-1]


func familiarity_label(spot: String) -> String:
	return familiarity_tier(spot)[1]


## Multiplier applied to all ratings when playing `spot`.
func position_factor(spot: String) -> float:
	return familiarity_tier(spot)[2]


## "L" or "R" for wings and D spots, "" for C and G.
static func spot_side(spot: String) -> String:
	if spot in ["LW", "LD"]:
		return "L"
	if spot in ["RW", "RD"]:
		return "R"
	return ""


## True when the player's stick is on the opposite side of his spot
## (a left shot on RW or RD).
func is_off_side_at(spot: String) -> bool:
	var side := spot_side(spot)
	return side != "" and side != shoots


## True when the player is on the side he likes (off side or strong side).
func on_preferred_side(spot: String) -> bool:
	var side := spot_side(spot)
	if side == "":
		return true
	return is_off_side_at(spot) == prefers_off_side


## Value used for picking lineups: overall adjusted for the spot.
func lineup_score(spot: String) -> float:
	return overall * position_factor(spot)


func cap_hit() -> int:
	return int(contract.get("cap_hit", 0))


func potential_range() -> String:
	# Phase 1 has no scouting yet: show a fuzzy range around the hidden potential.
	if potential <= overall:
		return str(overall)
	var spread := 3 + (potential - overall) / 3
	return "%d-%d" % [maxi(overall, potential - spread), mini(99, potential + spread)]
