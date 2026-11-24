class_name Roles
extends RefCounted
## Hockey player roles (like Football Manager's player roles). Each role
## weights a handful of key attributes; a player's suitability is shown as
## 0.5-5 stars. The profile highlights a role's key attributes.

const FORWARD := {
	"sniper": {"name": "Sniper", "abbr": "SNP",
		"keys": {"wrist_shot": 3, "slap_shot": 1, "offensive_awareness": 2, "composure": 2, "acceleration": 1}},
	"playmaker": {"name": "Playmaker", "abbr": "PLY",
		"keys": {"passing": 3, "vision": 3, "stickhandling": 2, "offensive_awareness": 1, "agility": 1}},
	"power_forward": {"name": "Power Forward", "abbr": "PWF",
		"keys": {"strength": 2, "body_checking": 2, "wrist_shot": 2, "deflections": 1, "balance": 2}},
	"two_way": {"name": "Two-Way Forward", "abbr": "2WF",
		"keys": {"defensive_awareness": 2, "offensive_awareness": 2, "work_rate": 2, "poke_check": 1, "stamina": 1, "passing": 1}},
	"net_front": {"name": "Net-Front Presence", "abbr": "NFP",
		"keys": {"deflections": 3, "strength": 2, "balance": 2, "composure": 1}},
	"grinder": {"name": "Grinder", "abbr": "GRN",
		"keys": {"work_rate": 3, "body_checking": 2, "stamina": 2, "shot_blocking": 1, "aggression": 1}},
	"enforcer": {"name": "Enforcer", "abbr": "ENF",
		"keys": {"aggression": 3, "strength": 3, "body_checking": 2, "balance": 1}},
}

const DEFENSE := {
	"offensive_d": {"name": "Offensive Defenseman", "abbr": "OFD",
		"keys": {"slap_shot": 2, "passing": 2, "vision": 2, "offensive_awareness": 2, "speed": 1}},
	"two_way_d": {"name": "Two-Way Defenseman", "abbr": "2WD",
		"keys": {"defensive_awareness": 2, "passing": 2, "poke_check": 1, "composure": 2, "stamina": 1}},
	"puck_mover": {"name": "Puck-Moving Defenseman", "abbr": "PMD",
		"keys": {"passing": 3, "stickhandling": 2, "speed": 2, "agility": 1, "vision": 1}},
	"stay_at_home": {"name": "Stay-at-Home Defenseman", "abbr": "SAH",
		"keys": {"defensive_awareness": 3, "shot_blocking": 2, "body_checking": 2, "strength": 2, "discipline": 1}},
	"shutdown": {"name": "Shutdown Defenseman", "abbr": "SHD",
		"keys": {"defensive_awareness": 2, "poke_check": 2, "anticipation": 2, "shot_blocking": 1, "agility": 1}},
}

const GOALIE := {
	"butterfly": {"name": "Butterfly", "abbr": "BTF",
		"keys": {"positioning": 3, "rebound_control": 2, "post_play": 2, "flexibility": 2, "composure": 1}},
	"hybrid": {"name": "Hybrid", "abbr": "HYB",
		"keys": {"positioning": 2, "reflexes": 2, "glove": 2, "blocker": 1, "anticipation": 2}},
	"athletic": {"name": "Athletic", "abbr": "ATH",
		"keys": {"reflexes": 3, "agility": 2, "recovery": 2, "glove": 1}},
	"puck_mover_g": {"name": "Puck-Moving Goalie", "abbr": "PMG",
		"keys": {"puck_handling": 3, "communication": 2, "composure": 1, "positioning": 1}},
}


static func for_player(p) -> Dictionary:
	if p.is_goalie():
		return GOALIE
	if p.is_defense():
		return DEFENSE
	return FORWARD


static func for_spot(spot: String) -> Dictionary:
	if spot == "G":
		return GOALIE
	if spot in ["LD", "RD"]:
		return DEFENSE
	return FORWARD


static func get_role(key: String) -> Dictionary:
	for table in [FORWARD, DEFENSE, GOALIE]:
		if table.has(key):
			return table[key]
	return {}


## Weighted 1-20 score for a role.
static func score(p, role_key: String) -> float:
	var role := get_role(role_key)
	if role.is_empty():
		return 0.0
	var total := 0.0
	var weight := 0.0
	for k in role["keys"]:
		total += p.detail(k) * role["keys"][k]
		weight += role["keys"][k]
	return total / maxf(1.0, weight)


## 0.5 to 5 stars, in half steps.
static func stars(p, role_key: String) -> float:
	return clampf(roundf((score(p, role_key) - 5.0) / 13.0 * 5.0 * 2.0) / 2.0, 0.5, 5.0)


## Role keys for this player, best first.
static func ranked(p, table: Dictionary = {}) -> Array:
	var t := table if not table.is_empty() else for_player(p)
	var keys := t.keys()
	keys.sort_custom(func(a, b): return score(p, a) > score(p, b))
	return keys


static func best(p) -> String:
	var r := ranked(p)
	return r[0] if not r.is_empty() else ""
