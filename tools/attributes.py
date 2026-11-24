"""Detailed attributes and team colors.

The rating model has two layers:
  * 9 core ratings (skating, shooting, ...) that the match sim reads, and
  * ~26 detailed attributes per skater / 15 per goalie shown in the game,
    Football Manager style.

Detailed attributes are generated around the stat-based core ratings and
nudged by real "realtime" stats (hits, blocked shots, takeaways, giveaways,
penalty minutes). The core ratings are then rebuilt as weighted averages of
the details (CORE_FROM_DETAILS) so both layers always agree.
"""
import random

# Display order and grouping (keys must match scripts/core/player.gd).
SKATER_GROUPS = {
    "technical": ["wrist_shot", "slap_shot", "deflections", "passing", "stickhandling",
                  "faceoffs", "poke_check", "shot_blocking", "body_checking"],
    "mental": ["offensive_awareness", "defensive_awareness", "vision", "anticipation",
               "composure", "discipline", "work_rate", "aggression", "leadership", "teamwork"],
    "physical": ["speed", "acceleration", "agility", "balance", "strength", "stamina", "durability"],
}
GOALIE_GROUPS = {
    "technical": ["reflexes", "glove", "blocker", "positioning", "rebound_control",
                  "post_play", "puck_handling"],
    "mental": ["anticipation", "composure", "concentration", "consistency", "communication"],
    "physical": ["agility", "flexibility", "recovery"],
}

# Core rating = weighted average of these details.
CORE_FROM_DETAILS = {
    "skater": {
        "shooting": {"wrist_shot": .5, "slap_shot": .3, "deflections": .2},
        "passing": {"passing": .7, "vision": .3},
        "puck_handling": {"stickhandling": .75, "composure": .25},
        "offense_iq": {"offensive_awareness": .7, "anticipation": .3},
        "defense": {"defensive_awareness": .45, "poke_check": .2, "shot_blocking": .2, "anticipation": .15},
        "physical": {"strength": .4, "body_checking": .4, "balance": .2},
        "skating": {"speed": .4, "acceleration": .35, "agility": .25},
        "endurance": {"stamina": .75, "work_rate": .25},
        "faceoffs": {"faceoffs": 1.0},
    },
    "goalie": {
        "reflexes": {"reflexes": .6, "agility": .2, "recovery": .2},
        "positioning": {"positioning": .6, "post_play": .2, "anticipation": .2},
        "rebound_control": {"rebound_control": 1.0},
        "glove": {"glove": .6, "blocker": .4},
        "puck_handling": {"puck_handling": 1.0},
        "consistency": {"consistency": .6, "concentration": .4},
        "mental": {"composure": .5, "concentration": .5},
    },
}

# Team colors: (primary, secondary). Spoofed clubs keep their city's colors.
TEAM_COLORS = {
    "ANA": ("#F47A38", "#B9975B"), "BOS": ("#FFB81C", "#1A1A1A"), "BUF": ("#003087", "#FFB81C"),
    "CGY": ("#C8102E", "#F1BE48"), "CAR": ("#CE1126", "#A2AAAD"), "CHI": ("#CF0A2C", "#1A1A1A"),
    "COL": ("#6F263D", "#236192"), "CBJ": ("#002654", "#CE1126"), "DAL": ("#006847", "#8F8F8C"),
    "DET": ("#CE1126", "#FFFFFF"), "EDM": ("#FF4C00", "#041E42"), "FLA": ("#C8102E", "#B9975B"),
    "LAK": ("#2B2B2B", "#A2AAAD"), "MIN": ("#154734", "#A6192E"), "MTL": ("#AF1E2D", "#192168"),
    "NSH": ("#FFB81C", "#041E42"), "NJD": ("#CE1126", "#1A1A1A"), "NYI": ("#00539B", "#F47D30"),
    "NYR": ("#0038A8", "#CE1126"), "OTT": ("#C52032", "#C2912C"), "PHI": ("#F74902", "#1A1A1A"),
    "PIT": ("#FCB514", "#1A1A1A"), "SJS": ("#006D75", "#EA7200"), "SEA": ("#68A2B9", "#001628"),
    "STL": ("#002F87", "#FCB514"), "TBL": ("#002868", "#FFFFFF"), "TOR": ("#00205B", "#FFFFFF"),
    "UTA": ("#6CACE4", "#1A1A1A"), "VAN": ("#00205B", "#00843D"), "VGK": ("#B4975A", "#333F42"),
    "WSH": ("#C8102E", "#041E42"), "WPG": ("#041E42", "#AC162C"),
}


def _c(v):
    return max(1, min(20, int(round(v))))


def skater_details(core: dict, pos: str, sig: dict, age: int, ovr: int, nhl_gp: int,
                   weight_z: float, rng: random.Random) -> dict:
    """core: 9 core ratings (1-20). sig: z-scores for hits, blocks, takeaways,
    giveaways, pim (0 when there's no NHL sample)."""
    n = lambda s: rng.gauss(0, s)
    d_man = pos == "D"
    z = lambda k: max(-2.5, min(3.0, sig.get(k, 0.0)))
    c = core
    det = {
        "wrist_shot": c["shooting"] + (-0.8 if d_man else 0.3) + n(0.9),
        "slap_shot": c["shooting"] + (2.0 if d_man else -0.6) + n(1.2),
        "deflections": c["shooting"] + (-1.5 if d_man else 0.2) + n(1.4),
        "passing": c["passing"] + n(0.8),
        "stickhandling": c["puck_handling"] + n(0.9),
        "faceoffs": c["faceoffs"],
        "poke_check": c["defense"] + 0.8 * z("takeaways") + n(1.0),
        "shot_blocking": c["defense"] - 0.5 + 1.6 * z("blocks") + n(1.0),
        "body_checking": c["physical"] + 1.8 * z("hits") + n(1.0),
        "offensive_awareness": c["offense_iq"] + n(0.8),
        "defensive_awareness": c["defense"] + n(0.8),
        "vision": (c["passing"] + c["offense_iq"]) / 2 + n(1.0),
        "anticipation": (c["offense_iq"] + c["defense"]) / 2 + 0.5 * z("takeaways") + n(1.0),
        "composure": (c["puck_handling"] + c["offense_iq"]) / 2 - 0.4 * z("giveaways") + n(1.1),
        "discipline": 12.5 - 2.2 * z("pim") + n(1.3),
        "work_rate": (c["endurance"] + c["defense"]) / 2 + 0.5 * z("hits") + n(1.2),
        "aggression": c["physical"] + 1.2 * z("pim") + 0.6 * z("hits") + n(1.2),
        "leadership": 8 + (age - 20) * 0.35 + (ovr - 60) / 8 + n(2.0),
        "teamwork": 11 + (c["passing"] - 11) * 0.3 + n(2.0),
        "speed": c["skating"] + n(0.9),
        "acceleration": c["skating"] + n(1.1),
        "agility": c["skating"] + n(1.1),
        "balance": (c["skating"] + c["physical"]) / 2 + n(1.2),
        "strength": c["physical"] + 1.5 * weight_z + n(1.0),
        "stamina": c["endurance"] + n(0.8),
        "durability": 12 + n(2.5) + (1.0 if nhl_gp > 300 else 0.0),
    }
    return {k: _c(v) for k, v in det.items()}


def goalie_details(core: dict, age: int, nhl_gp: int, rng: random.Random) -> dict:
    n = lambda s: rng.gauss(0, s)
    c = core
    det = {
        "reflexes": c["reflexes"] + n(0.8),
        "glove": c["glove"] + n(0.9),
        "blocker": (c["reflexes"] + c["positioning"]) / 2 + n(1.0),
        "positioning": c["positioning"] + n(0.8),
        "rebound_control": c["rebound_control"],
        "post_play": c["positioning"] + n(1.2),
        "puck_handling": c["puck_handling"],
        "anticipation": (c["positioning"] + c["mental"]) / 2 + n(1.0),
        "composure": c["mental"] + n(1.0),
        "concentration": (c["consistency"] + c["mental"]) / 2 + n(1.0),
        "consistency": c["consistency"] + n(0.8),
        "communication": 9 + (age - 20) * 0.3 + n(2.2),
        "agility": c["reflexes"] + n(1.1),
        "flexibility": c["reflexes"] - 0.5 + n(1.3),
        "recovery": c["reflexes"] + n(1.1) + (0.8 if nhl_gp > 150 else 0.0),
    }
    return {k: _c(v) for k, v in det.items()}


def core_from_details(details: dict, kind: str, old_core: dict) -> dict:
    out = dict(old_core)
    for core_key, parts in CORE_FROM_DETAILS[kind].items():
        if all(k in details for k in parts):
            out[core_key] = _c(sum(details[k] * w for k, w in parts.items()))
    return out


def apply_core_override(details: dict, kind: str, core_key: str, value: int) -> None:
    """Pinning a core rating raises the details that feed it so they agree."""
    for k in CORE_FROM_DETAILS[kind].get(core_key, {}):
        details[k] = max(details[k], value)
