#!/usr/bin/env python3
"""Build data/league.json for the game from public NHL data.

Pulls current rosters (2026-27) and the last two regular seasons of stats,
turns stats into 1-20 attributes, generates contracts, and replaces every
real team and player name with a spoofed one.

Usage:  python3 tools/build_league.py            (uses cached responses if present)
        python3 tools/build_league.py --refresh  (re-downloads everything)
"""
import json
import random
import subprocess
import sys
import time
from datetime import date
from pathlib import Path

from spoof_names import spoof_name
from attributes import (TEAM_COLORS, skater_details, goalie_details, core_from_details,
                        apply_core_override)

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUT = ROOT / "data" / "league.json"
API = "https://api-web.nhle.com/v1"
STATS_API = "https://api.nhle.com/stats/rest/en"

SEASON_LABEL = "2026-27"
STAT_SEASONS = [("20252026", 0.65), ("20242025", 0.35)]  # (season, weight)
SEASON_START = date(2026, 10, 1)

# League finances (2026-27)
SALARY_CAP = 104_000_000
CAP_FLOOR = 76_900_000
MIN_SALARY = 850_000
MAX_SALARY = SALARY_CAP // 5
ELC_MAX = 1_000_000

# Real abbrev -> (city, spoof nickname, spoof abbrev). Cities stay real.
TEAMS = {
    "ANA": ("Anaheim", "Mallards", "ANM"),
    "BOS": ("Boston", "Bruisers", "BSN"),
    "BUF": ("Buffalo", "Blades", "BFB"),
    "CGY": ("Calgary", "Blaze", "CLB"),
    "CAR": ("Carolina", "Cyclones", "CRC"),
    "CHI": ("Chicago", "Warhawks", "CHW"),
    "COL": ("Colorado", "Rockslide", "CLR"),
    "CBJ": ("Columbus", "Bluecoats", "CBC"),
    "DAL": ("Dallas", "Comets", "DLC"),
    "DET": ("Detroit", "Redtails", "DTR"),
    "EDM": ("Edmonton", "Drillers", "EDD"),
    "FLA": ("Florida", "Cougars", "FLC"),
    "LAK": ("Los Angeles", "Monarchs", "LAM"),
    "MIN": ("Minnesota", "Timber", "MNT"),
    "MTL": ("Montréal", "Voyageurs", "MTV"),
    "NSH": ("Nashville", "Prowlers", "NSP"),
    "NJD": ("New Jersey", "Demons", "NJM"),
    "NYI": ("New York", "Shoremen", "NYS"),
    "NYR": ("New York", "Rovers", "NYV"),
    "OTT": ("Ottawa", "Statesmen", "OTS"),
    "PHI": ("Philadelphia", "Aviators", "PHA"),
    "PIT": ("Pittsburgh", "Puffins", "PTP"),
    "SJS": ("San Jose", "Stingrays", "SJR"),
    "SEA": ("Seattle", "Leviathans", "SEL"),
    "STL": ("St. Louis", "Bluenotes", "SLB"),
    "TBL": ("Tampa Bay", "Thunder", "TBT"),
    "TOR": ("Toronto", "Lumberjacks", "TRL"),
    "UTA": ("Utah", "Mastodons", "UTM"),
    "VAN": ("Vancouver", "Orcas", "VNO"),
    "VGK": ("Vegas", "Paladins", "VGP"),
    "WSH": ("Washington", "Federals", "WSF"),
    "WPG": ("Winnipeg", "Falcons", "WPF"),
}
assert len({t[2] for t in TEAMS.values()}) == 32


# ---------------------------------------------------------------- fetching
def fetch(path: str, refresh: bool, base: str = API, cache_name: str = ""):
    CACHE.mkdir(parents=True, exist_ok=True)
    cache_file = CACHE / ((cache_name or path.strip("/").replace("/", "_")) + ".json")
    if cache_file.exists() and not refresh:
        return json.loads(cache_file.read_text())
    for attempt in range(4):
        r = subprocess.run(
            ["curl", "-s", "-L", "--max-time", "60", "-w", "\n%{http_code}", f"{base}/{path}"],
            capture_output=True, text=True,
        )
        body, _, code = r.stdout.rpartition("\n")
        if code == "200":
            cache_file.write_text(body)
            return json.loads(body)
        if code == "404":
            return None
        time.sleep(2 ** attempt)
    raise RuntimeError(f"failed to fetch {path} (last status {code})")


# ---------------------------------------------------------------- helpers
def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def age_on(birth: str, when: date) -> int:
    y, m, d = map(int, birth.split("-"))
    return when.year - y - ((when.month, when.day) < (m, d))


def toi_seconds(v) -> float:
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, str) and ":" in v:
        mm, ss = v.split(":")
        return int(mm) * 60 + int(ss)
    return 0.0


def percentiles(values: dict) -> dict:
    """Map {key: value} -> {key: percentile 0..1}."""
    ordered = sorted(values, key=lambda k: values[k])
    n = len(ordered)
    return {k: (i + 0.5) / n for i, k in enumerate(ordered)}


def zscores(values: dict) -> dict:
    """Map {key: value} -> {key: standard score}. Unlike percentiles, these don't
    saturate, so a 138-point season stays clearly ahead of a 97-point one."""
    vals = list(values.values())
    mean = sum(vals) / len(vals)
    sd = (sum((v - mean) ** 2 for v in vals) / len(vals)) ** 0.5 or 1.0
    return {k: (v - mean) / sd for k, v in values.items()}


def soft_cap(v: float) -> float:
    """Above 18, gains are compressed instead of hard-clipped at 20."""
    return v if v <= 18 else 18 + (v - 18) * 0.5


def pct_to_attr(p: float) -> float:
    """NHL regulars span roughly 7..20 on the 1-20 scale."""
    return 7 + 13 * (p ** 1.15)


# ---------------------------------------------------------------- positions
SKATER_SPOTS = ("C", "LW", "RW", "LD", "RD")


def position_profile(pos: str, shoots: str, attrs: dict, rng: random.Random) -> dict:
    """Familiarity 1-20 for every spot, plus preferred / comfortable spots.

    18-20 natural, 14-17 accomplished, 10-13 competent, 6-9 unconvincing, 1-5 awkward.
    Wingers and D each have a preferred side: strong side (same as their stick)
    or off side (opposite: a left shot on the right, for one-timers and better
    angles). The NHL API doesn't list LD/RD, so the side is inferred.
    """
    if pos == "G":
        return {"preferred": "G", "comfortable": [], "prefers_off_side": False, "familiarity": {"G": 20}}
    fam = {spot: rng.randint(1, 4) for spot in SKATER_SPOTS}
    strong = "L" if shoots == "L" else "R"
    off = "R" if strong == "L" else "L"

    if pos == "D":
        # About a third of D (mostly lefties) prefer the off side.
        off_side = rng.random() < (0.38 if shoots == "L" else 0.15)
        pref = (off if off_side else strong) + "D"
        other = ("L" if pref[0] == "R" else "R") + "D"
        fam[pref] = 20
        fam[other] = rng.randint(11, 17)
        # The odd D can fill in up front in a pinch.
        for w in ("LW", "RW"):
            fam[w] = rng.randint(3, 11 if rng.random() < 0.15 else 6)
        prefers_off = off_side
    else:
        if pos == "C":
            pref = "C"
            fam["C"] = 20
            # Centers slide to the wing they'd rather play: usually the off wing.
            wing_side = off if rng.random() < 0.6 else strong
            fam[wing_side + "W"] = rng.randint(13, 18)
            fam[("L" if wing_side == "R" else "R") + "W"] = rng.randint(9, 15)
            prefers_off = wing_side == off
        else:
            pref = pos + "W"
            other = ("L" if pos == "R" else "R") + "W"
            prefers_off = pos != strong
            fam[pref] = 20
            fam[other] = rng.randint(10, 16)
            # Wingers who take draws are comfortable at center.
            fo = attrs.get("faceoffs", 5)
            fam["C"] = clamp(int(fo * 0.7 + rng.randint(2, 6)), 4, 17)
        fam["LD"] = rng.randint(1, 4)
        fam["RD"] = rng.randint(1, 4)
    comfortable = sorted((sp for sp, v in fam.items() if sp != pref and v >= 14), key=lambda sp: -fam[sp])
    return {"preferred": pref, "comfortable": comfortable, "prefers_off_side": prefers_off, "familiarity": fam}


# ---------------------------------------------------------------- main build
def main():
    refresh = "--refresh" in sys.argv

    standings = fetch("standings/now", refresh)["standings"]
    div_of = {t["teamAbbrev"]["default"]: (t["conferenceName"], t["divisionName"]) for t in standings}

    # Weighted stat totals per player across seasons and teams (trades split rows).
    skater_stats: dict[int, dict] = {}
    goalie_stats: dict[int, dict] = {}
    for season, weight in STAT_SEASONS:
        for abbr in TEAMS:
            data = fetch(f"club-stats/{abbr}/{season}/2", refresh)
            if not data:
                continue
            for s in data.get("skaters", []):
                acc = skater_stats.setdefault(s["playerId"], {})
                gp = s.get("gamesPlayed", 0)
                acc["nhl_gp"] = acc.get("nhl_gp", 0) + gp
                for key, src in [("gp", "gamesPlayed"), ("g", "goals"), ("a", "assists"),
                                 ("shots", "shots"), ("pim", "penaltyMinutes"), ("pm", "plusMinus"),
                                 ("ppg", "powerPlayGoals"), ("shg", "shorthandedGoals")]:
                    acc[key] = acc.get(key, 0) + weight * (s.get(src) or 0)
                acc["toi_x_gp"] = acc.get("toi_x_gp", 0) + weight * gp * toi_seconds(s.get("avgTimeOnIcePerGame"))
                fo = s.get("faceoffWinPctg") or 0
                if fo > 0:
                    acc["fo_x_gp"] = acc.get("fo_x_gp", 0) + weight * gp * fo
                    acc["fo_gp"] = acc.get("fo_gp", 0) + weight * gp
            for g in data.get("goalies", []):
                acc = goalie_stats.setdefault(g["playerId"], {})
                acc["nhl_gp"] = acc.get("nhl_gp", 0) + g.get("gamesPlayed", 0)
                for key, src in [("gp", "gamesPlayed"), ("gs", "gamesStarted"), ("sa", "shotsAgainst"),
                                 ("sv", "saves"), ("ga", "goalsAgainst"), ("w", "wins"), ("so", "shutouts")]:
                    acc[key] = acc.get(key, 0) + weight * (g.get(src) or 0)

    # "Realtime" stats: hits, blocked shots, takeaways, giveaways (per 60 minutes).
    realtime: dict[int, dict] = {}
    for season, weight in STAT_SEASONS:
        data = fetch(f"skater/realtime?limit=-1&cayenneExp=seasonId={season}%20and%20gameTypeId=2",
                     refresh, base=STATS_API, cache_name=f"realtime_{season}")
        for r in (data or {}).get("data", []):
            acc = realtime.setdefault(r["playerId"], {})
            toi = (r.get("timeOnIcePerGame") or 0) * (r.get("gamesPlayed") or 0)
            acc["toi"] = acc.get("toi", 0) + weight * toi
            acc["gp"] = acc.get("gp", 0) + weight * (r.get("gamesPlayed") or 0)
            for k, src in [("hits", "hits"), ("blocks", "blockedShots"), ("takeaways", "takeaways"),
                           ("giveaways", "giveaways")]:
                acc[k] = acc.get(k, 0) + weight * (r.get(src) or 0)

    # Current rosters.
    roster_players = []
    for abbr in TEAMS:
        roster = fetch(f"roster/{abbr}/current", refresh)
        for group in ("forwards", "defensemen", "goalies"):
            for p in roster.get(group, []):
                roster_players.append((abbr, p))

    # Per-game rates for percentile ranking (only meaningful samples).
    def rates(pid, pos):
        s = skater_stats.get(pid)
        if not s or s["gp"] < 1:
            return None
        gp = s["gp"]
        return {
            "gpg": s["g"] / gp, "apg": s["a"] / gp, "ppg": (s["g"] + s["a"]) / gp,
            "spg": s["shots"] / gp, "pimpg": s["pim"] / gp, "pm": s["pm"] / gp,
            "toi": s["toi_x_gp"] / gp, "shpct": (s["g"] + 2) / (s["shots"] + 20),
            "fo": (s.get("fo_x_gp", 0) / s["fo_gp"]) if s.get("fo_gp", 0) > 0 else None,
            "fo_gp": s.get("fo_gp", 0), "gp": gp,
        }

    pools = {"F": {}, "D": {}}
    for abbr, p in roster_players:
        pos = p["positionCode"]
        if pos == "G":
            continue
        grp = "D" if pos == "D" else "F"
        r = rates(p["id"], pos)
        if r and r["gp"] >= 15:
            pools[grp][p["id"]] = r
    pct = {}
    for grp, pool in pools.items():
        for metric in ("gpg", "apg", "ppg", "spg", "pimpg", "pm", "toi", "shpct"):
            pct[(grp, metric)] = zscores({k: v[metric] for k, v in pool.items()})
    fo_pool = {k: v["fo"] for k, v in pools["F"].items() if v["fo"] is not None and v["fo_gp"] >= 15}
    pct[("F", "fo")] = zscores(fo_pool)

    weights = {p["id"]: p["weightInPounds"] for _, p in roster_players if p.get("weightInPounds")}
    pct_weight = percentiles(weights)

    # Per-60 realtime signals as z-scores within forwards / defense.
    signals: dict[int, dict] = {}
    for grp_codes in (("C", "L", "R"), ("D",)):
        pool = {}
        for _, p in roster_players:
            rt = realtime.get(p["id"])
            sk = skater_stats.get(p["id"])
            if p["positionCode"] in grp_codes and rt and rt["gp"] >= 15 and rt["toi"] > 0:
                per60 = {k: rt[k] * 3600 / rt["toi"] for k in ("hits", "blocks", "takeaways", "giveaways")}
                per60["pim"] = (sk["pim"] / sk["gp"]) if sk and sk["gp"] else 0
                pool[p["id"]] = per60
        if pool:
            for metric in ("hits", "blocks", "takeaways", "giveaways", "pim"):
                for pid_, zv in zscores({k: v[metric] for k, v in pool.items()}).items():
                    signals.setdefault(pid_, {})[metric] = zv

    goalie_pool = {}
    for _, p in roster_players:
        if p["positionCode"] == "G":
            g = goalie_stats.get(p["id"])
            if g and g["gp"] >= 8 and g["sa"] > 0:
                # Regress save% toward league average with 600 phantom shots.
                goalie_pool[p["id"]] = (g["sv"] + 0.900 * 600) / (g["sa"] + 600)
    pct_goalie = percentiles(goalie_pool)
    pct_goalie_gp = percentiles({k: goalie_stats[k]["gp"] for k in goalie_pool})

    overrides = json.loads((ROOT / "tools" / "overrides.json").read_text())

    used_names: set[str] = set()
    real_names = {f'{p["firstName"]["default"]} {p["lastName"]["default"]}' for _, p in roster_players}
    players = []

    for abbr, p in roster_players:
        pid = p["id"]
        rng = random.Random(pid)
        pos = p["positionCode"]
        age = age_on(p["birthDate"], SEASON_START)
        first, last = spoof_name(p["firstName"]["default"], p["lastName"]["default"], pid, used_names | real_names)
        used_names.add(f"{first} {last}")

        def noise(spread=1.2):
            return rng.uniform(-spread, spread) * noise_scale

        noise_scale = 1.0

        if pos == "G":
            g = goalie_stats.get(pid, {})
            nhl_gp = g.get("nhl_gp", 0)
            if pid in pct_goalie:
                base = pct_to_attr(pct_goalie[pid])
                trust = pct_to_attr(pct_goalie_gp[pid])
            else:
                base = rng.uniform(7, 10.5) if nhl_gp else rng.uniform(6, 9.5)
                trust = base - 1
            attrs = {
                "reflexes": base + noise(), "positioning": base + noise(),
                "rebound_control": base + noise(1.5), "glove": base + noise(1.5),
                "puck_handling": rng.uniform(5, 14), "consistency": (base + trust) / 2 + noise(),
                "mental": base + noise(1.5),
            }
            ovr_w = {"reflexes": .25, "positioning": .25, "rebound_control": .15, "glove": .15,
                     "consistency": .12, "mental": .08}
        else:
            grp = "D" if pos == "D" else "F"
            r = rates(pid, pos)
            nhl_gp = skater_stats.get(pid, {}).get("nhl_gp", 0)
            wt = pct_weight.get(pid, 0.5)
            if pid in pools[grp]:
                Z = {m: pct[(grp, m)][pid] for m in ("gpg", "apg", "ppg", "spg", "pimpg", "pm", "toi", "shpct")}
                # Small samples get pulled toward a depth-player baseline.
                trust = clamp(r["gp"] / 60, 0.35, 1.0)
                noise_scale = 0.4  # real data: keep random wobble small
                A = lambda z: soft_cap(10.5 + 3.0 * z) * trust + 9.5 * (1 - trust)
                zwt = (wt - 0.5) * 3.4
                youth = clamp((30 - age) / 10, -0.5, 1.0)
                attrs = {
                    "skating": A(0.6 * Z["ppg"] + 0.4 * Z["toi"]) + 1.0 * youth + noise(),
                    "shooting": A(0.55 * Z["gpg"] + 0.25 * Z["shpct"] + 0.2 * Z["spg"]) + noise(0.8),
                    "passing": A(Z["apg"]) + noise(0.8),
                    "puck_handling": A(0.5 * Z["gpg"] + 0.5 * Z["apg"]) + noise(),
                    "offense_iq": A(Z["ppg"]) + noise(0.8),
                    "defense": A(0.6 * Z["toi"] + 0.4 * Z["pm"]) + (1.5 if grp == "D" else -1.0) + noise(),
                    "physical": A(0.55 * zwt + 0.45 * Z["pimpg"]) + noise(),
                    "endurance": A(Z["toi"]) + 1.0 * youth + noise(),
                    "faceoffs": (A(pct[("F", "fo")][pid]) if pid in pct[("F", "fo")]
                                 else rng.uniform(4, 9) if pos == "C" else rng.uniform(2, 7)),
                }
            else:
                # Rookies / call-ups without a usable NHL sample.
                base = rng.uniform(7.5, 10.5) if nhl_gp else rng.uniform(6.5, 10)
                attrs = {k: base + noise(1.8) for k in
                         ("skating", "shooting", "passing", "puck_handling", "offense_iq",
                          "defense", "physical", "endurance")}
                attrs["physical"] = attrs["physical"] * 0.6 + (6 + 8 * wt) * 0.4
                attrs["faceoffs"] = rng.uniform(5, 10) if pos == "C" else rng.uniform(2, 7)
                if grp == "D":
                    attrs["defense"] += 1.5
            if grp == "D":
                ovr_w = {"defense": .26, "skating": .16, "passing": .14, "physical": .12, "offense_iq": .10,
                         "puck_handling": .08, "shooting": .06, "endurance": .08}
            else:
                ovr_w = {"offense_iq": .18, "shooting": .17, "passing": .15, "skating": .15,
                         "puck_handling": .12, "defense": .08, "physical": .05, "endurance": .05,
                         "faceoffs": .05 if pos == "C" else 0}

        pos_profile = position_profile(pos, p.get("shootsCatches", "L"), attrs, random.Random(pid * 13 + 5))
        ov = overrides.get(str(pid), {})
        pos_profile.update(ov.get("positions", {}))
        attrs.update(ov.get("attributes", {}))
        first = ov.get("first_name", first)
        last = ov.get("last_name", last)

        # Rank on the unrounded, uncapped values so stars separate; show 1-20 ints.
        wsum = sum(ovr_w.values())
        raw = sum(attrs[k] * w for k, w in ovr_w.items()) / wsum + ov.get("rating_bonus", 0)
        attrs = {k: int(round(clamp(v, 1, 20))) for k, v in attrs.items()}
        ovr = int(round(clamp(raw * 5, 30, 99)))

        # Detailed attributes, then rebuild the core ratings from them.
        drng = random.Random(pid * 31 + 7)
        if pos == "G":
            kind = "goalie"
            details = goalie_details(attrs, age, int(nhl_gp), drng)
        else:
            kind = "skater"
            details = skater_details(attrs, pos, signals.get(pid, {}), age, ovr, int(nhl_gp),
                                     (pct_weight.get(pid, 0.5) - 0.5) * 3.4, drng)
        for k, v in ov.get("attributes", {}).items():
            apply_core_override(details, kind, k, v)
        attrs = core_from_details(details, kind, attrs)

        # Hidden potential.
        if age <= 20:
            pot = ovr + rng.randint(6, 22)
        elif age <= 23:
            pot = ovr + rng.randint(2, 12)
        elif age <= 26:
            pot = ovr + rng.randint(0, 4)
        else:
            pot = ovr
        pot = clamp(pot, ovr, 99)

        players.append({
            "id": pid,
            "first_name": first,
            "last_name": last,
            "team": TEAMS[abbr][2],
            "position": pos_profile["preferred"],
            "positions": pos_profile,
            "shoots": p.get("shootsCatches", "L"),
            "number": p.get("sweaterNumber"),
            "birth_date": p["birthDate"],
            "age": age,
            "nationality": p.get("birthCountry", ""),
            "height_cm": p.get("heightInCentimeters"),
            "weight_kg": p.get("weightInKilograms"),
            "nhl_games": int(nhl_gp),
            "overall": ovr,
            "potential": pot,
            "attributes": attrs,
            "details": details,
            "_real_team": abbr,
            "_raw": raw,
        })

    # Balance D sides per team: if one side is overloaded, players who could go
    # either way (off-side preference, closest familiarity) switch over.
    for abbr in TEAMS:
        d = [pl for pl in players if pl["_real_team"] == abbr and pl["position"] in ("LD", "RD")]
        while True:
            lds = [pl for pl in d if pl["position"] == "LD"]
            rds = [pl for pl in d if pl["position"] == "RD"]
            big, small_side = (rds, "LD") if len(rds) > len(lds) + 1 else (lds, "RD") if len(lds) > len(rds) + 1 else (None, None)
            if not big:
                break
            mover = max(big, key=lambda pl: pl["positions"]["familiarity"][small_side])
            prof = mover["positions"]
            old = prof["preferred"]
            prof["familiarity"][small_side], prof["familiarity"][old] = 20, max(14, prof["familiarity"][small_side])
            prof["preferred"] = mover["position"] = small_side
            prof["prefers_off_side"] = small_side[0] != mover["shoots"]
            prof["comfortable"] = sorted((sp for sp, v in prof["familiarity"].items() if sp != small_side and v >= 14),
                                         key=lambda sp: -prof["familiarity"][sp])

    # Rescale overalls by rank so the league has a realistic star curve:
    # ~top 4% reach 90+, median player in the low 60s.
    for is_goalie in (False, True):
        group = [pl for pl in players if (pl["position"] == "G") == is_goalie]
        ranks = percentiles({pl["id"]: pl["_raw"] for pl in group})
        for pl in group:
            r = ranks[pl["id"]]
            new = int(round(45 + 35 * r + 17 * r ** 8))
            pl["potential"] = int(clamp(new + (pl["potential"] - pl["overall"]), new, 99))
            pl["overall"] = new
            fixed = overrides.get(str(pl["id"]), {}).get("overall")
            if fixed:
                pl["potential"] = max(pl["potential"], fixed)
                pl["overall"] = fixed

    # ------------------------------------------------------------ contracts
    by_team: dict[str, list] = {}
    for pl in players:
        by_team.setdefault(pl["_real_team"], []).append(pl)

    for abbr, roster in by_team.items():
        trng = random.Random(abbr)
        for pl in roster:
            rng = random.Random(pl["id"] * 7 + 1)
            age, ovr = pl["age"], pl["overall"]
            elc = age <= 22 and pl["nhl_games"] < 160
            if elc:
                hit = rng.choice([775_000, 850_000, 925_000, 950_000, 975_000, ELC_MAX])
                years = rng.randint(1, 3)
            else:
                v = clamp((ovr - 48) / 44, 0, 1)
                hit = MIN_SALARY + (MAX_SALARY * 0.70 - MIN_SALARY) * v ** 2.4
                hit *= rng.uniform(0.85, 1.15)
                if age <= 25:
                    years = rng.randint(1, 4) if ovr < 75 else rng.randint(3, 8)
                elif age <= 30:
                    years = rng.randint(1, 4) if ovr < 75 else rng.randint(2, 7)
                else:
                    years = rng.randint(1, 3) if ovr < 80 else rng.randint(1, 4)
            pl["contract"] = {"cap_hit": int(hit), "years": years, "elc": elc}

        # Scale non-ELC deals so payrolls land in a realistic spread under the cap.
        target = SALARY_CAP * trng.uniform(0.88, 0.995)
        elc_total = sum(p["contract"]["cap_hit"] for p in roster if p["contract"]["elc"])
        vets = [p for p in roster if not p["contract"]["elc"]]
        vet_total = sum(p["contract"]["cap_hit"] for p in vets) or 1
        scale = clamp((target - elc_total) / vet_total, 0.75, 1.25)
        # Every team must at least reach the cap floor.
        scale = max(scale, (CAP_FLOOR * 1.04 - elc_total) / vet_total)
        for p in vets:
            hit = clamp(p["contract"]["cap_hit"] * scale, MIN_SALARY, MAX_SALARY * 0.85)
            p["contract"]["cap_hit"] = int(round(hit / 5000) * 5000)

        for p in roster:
            c = p["contract"]
            age_at_expiry = p["age"] + c["years"]
            c["expiry_status"] = "RFA" if (c["elc"] or age_at_expiry <= 26) and p["nhl_games"] < 500 else "UFA"
            c["no_trade_clause"] = (not c["elc"]) and c["cap_hit"] > 7_000_000 and p["age"] >= 27 \
                and random.Random(p["id"] * 3).random() < 0.6

    for pl in players:
        del pl["_real_team"], pl["_raw"]

    teams = []
    for abbr, (city, nick, code) in TEAMS.items():
        conf, div = div_of[abbr]
        payroll = sum(p["contract"]["cap_hit"] for p in by_team[abbr])
        primary, secondary = TEAM_COLORS[abbr]
        teams.append({"id": code, "city": city, "name": nick, "conference": conf,
                      "division": div, "payroll": payroll,
                      "colors": {"primary": primary, "secondary": secondary}})
    teams.sort(key=lambda t: (t["city"], t["name"]))

    league = {
        "season": SEASON_LABEL,
        "generated": date.today().isoformat(),
        "finances": {"salary_cap": SALARY_CAP, "cap_floor": CAP_FLOOR, "min_salary": MIN_SALARY,
                     "max_salary": MAX_SALARY, "elc_max": ELC_MAX},
        "teams": teams,
        "players": sorted(players, key=lambda p: (p["team"], p["position"], -p["overall"])),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(league, indent=1, ensure_ascii=False))
    print(f"wrote {OUT} - {len(teams)} teams, {len(players)} players")


if __name__ == "__main__":
    main()
