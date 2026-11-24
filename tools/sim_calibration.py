"""Season calibration: a Python mirror of scripts/core/match_sim.gd.

Plays a full 1,312-game season from data/league.json with each team's real
depth chart and prints league averages plus individual stat leaders and the
spread of player stats, so sim constants can be tuned without Godot. Keep its
constants in sync with match_sim.gd.

Usage: python3 tools/sim_calibration.py data/league.json [seed]
"""
import json
import math
import random
import sys
from collections import defaultdict

# ---- constants (mirror match_sim.gd)
SEG = 40
BASE_SHOTS_PER_SEC = 29.0 / 3600
RATING_EXP = 0.6
GOALIE_EXP = 0.5
SH_SCALE = 0.87
TENDENCY_WEIGHT = 0.6
ASSIST_EXP = 1.4
SHOT_WEIGHT_EXP = 0.85
PEN_PER_SEC = 3.2 / 3600
F_SHARE = [0.31, 0.28, 0.23, 0.18]
D_SHARE = [0.38, 0.34, 0.28]
TIERS = [(18, 1.0), (14, .97), (10, .92), (6, .85), (1, .75)]
FWD, DS = ["LW", "C", "RW"], ["LD", "RD"]
PK_SPOTS = ["C", "LW", "LD", "RD"]

L = json.load(open(sys.argv[1]))
rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)


class P:
    def __init__(s, d):
        s.__dict__.update(d)
        s.pos = d["positions"]["preferred"]
        s.fam = d["positions"]["familiarity"]
        s.off = d["positions"]["prefers_off_side"]
        s.a = d["attributes"]
        s.t = d.get("tendencies", {})
    def g(s): return s.pos == "G"
    def attr(s, k): return s.a.get(k, 1)
    def pf(s, spot):
        f = 20 if s.g() else s.fam.get(spot, 1)
        return next(m for t, m in TIERS if f >= t)
    def side(s, spot): return "L" if spot in ("LW", "LD") else "R" if spot in ("RW", "RD") else ""
    def offside_at(s, spot): return s.side(spot) != "" and s.side(spot) != s.shoots


PL = {p["id"]: P(p) for p in L["players"]}
att = lambda p, s: (.25*p.attr("shooting")+.25*p.attr("passing")+.2*p.attr("puck_handling")+.2*p.attr("offense_iq")+.1*p.attr("skating"))*p.pf(s)
dfn = lambda p, s: (.45*p.attr("defense")+.2*p.attr("skating")+.15*p.attr("physical")+.2*p.attr("offense_iq"))*p.pf(s)
shv = lambda p, s: (.6*p.attr("shooting")+.2*p.attr("offense_iq")+.2*p.attr("puck_handling"))*p.pf(s)
gr = lambda g: .3*g.attr("reflexes")+.3*g.attr("positioning")+.15*g.attr("rebound_control")+.15*g.attr("glove")+.1*g.attr("consistency")


def lineup(team):
    dc = team["depth_chart"]
    return {"f": [[(PL.get(i), FWD[k]) for k, i in enumerate(l)] for l in dc["forwards"]],
            "d": [[(PL.get(i), DS[k]) for k, i in enumerate(l)] for l in dc["defense"]],
            "g": [PL.get(i) for i in dc["goalies"]], "share": dc["starter_share"],
            "pp": [[(PL.get(i), ["LW", "C", "RW", "LD", "RD"][k]) for k, i in enumerate(u)] for u in dc["power_play"]],
            "pk": [[(PL.get(i), PK_SPOTS[k]) for k, i in enumerate(u)] for u in dc["penalty_kill"]]}


LU = {t["id"]: lineup(t) for t in L["teams"]}
# norms from depth charts
a_sum = d_sum = n = 0
sw = ss = 0.0
gsum = gn = 0
for lu in LU.values():
    for p, s in [e for l in lu["f"] for e in l] + [e for x in lu["d"] for e in x]:
        if not p: continue
        a_sum += att(p, s); d_sum += dfn(p, s); n += 1
        w = p.t.get("shots60", 5) ** SHOT_WEIGHT_EXP; ss += shv(p, s) * w; sw += w
    if lu["g"][0]: gsum += gr(lu["g"][0]); gn += 1
N = {"attack": a_sum / n, "defense": d_sum / n, "shooting": ss / sw, "goalie": gsum / gn}

stats = defaultdict(lambda: defaultdict(float))
gstats = defaultdict(lambda: defaultdict(float))


def poisson(lam):
    l, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= rng.random()
        if p <= l: return k
        k += 1


def unit_rating(u, kind, late):
    t = 0
    for p, s in u:
        v = att(p, s) if kind == "a" else dfn(p, s)
        if p.side(s) and not p.off and not p.offside_at(s): v *= 1.02
        if late: v *= .96 + .04 * p.attr("endurance") / 20
        t += v
    return t / max(1, len(u))


def nextline(used, shares):
    tot = sum(used); return max(range(len(shares)), key=lambda k: shares[k] * (tot + 1) - used[k])


def goal_prob(p, spot, goalie, pp, sh, ot):
    t = p.t
    pos_avg = 0.05 if p.pos in ("LD", "RD") else 0.115
    rating_pct = pos_avg * (shv(p, spot) / N["shooting"]) ** RATING_EXP
    base = TENDENCY_WEIGHT * t.get("sh_pct", pos_avg) + (1 - TENDENCY_WEIGHT) * rating_pct
    if p.off and p.offside_at(spot): base *= 1.04
    pr = SH_SCALE * base * (N["goalie"] / gr(goalie)) ** GOALIE_EXP
    if pp: pr *= 1.2
    elif sh: pr *= 1.1
    if ot: pr *= 1.2
    return min(0.45, max(0.01, pr))


def play(home, away, playoff=False):
    S = []
    for t in (home, away):
        lu = LU[t]
        g = lu["g"][0] if (lu["g"][1] is None or rng.random() < lu["share"]) else lu["g"][1]
        S.append({"t": t, "lu": lu, "g": g, "goals": 0, "shots": 0, "pen": [], "fu": [0]*4, "du": [0]*3,
                  "pull": False, "ppg": 0, "ppo": 0})
    clock = 0
    on = lambda e: e[0] is not None

    def pick(i, sk, t):
        s, o = S[i], S[1 - i]
        if o["pen"] and not s["pen"]:
            el = 120 - (min(o["pen"]) - clock); u = [e for e in s["lu"]["pp"][0 if el < 80 else 1] if on(e)]
        elif s["pen"] and not o["pen"]:
            u = [e for e in s["lu"]["pk"][(t // SEG) % 2] if on(e)]
        else:
            fi = nextline(s["fu"], F_SHARE); di = nextline(s["du"], D_SHARE)
            s["fu"][fi] += SEG; s["du"][di] += SEG
            u = [e for e in s["lu"]["f"][fi] + s["lu"]["d"][di] if on(e)]
        while len(u) > sk[i]:
            u.remove(min(u, key=lambda e: e[0].overall + (50 if e[1] in DS else 0)))
        for e in [e for l in s["lu"]["f"] for e in l if on(e)]:
            if len(u) >= sk[i]: break
            if e not in u: u.append(e)
        return u

    def strength(m, t, ot):
        if ot: return 1.7
        d = m - t
        return 2.8 if d >= 2 else 2.0 if d == 1 else .32 if d == -1 else .2 if d <= -2 else 1.15 if m == 4 else 1.0

    def resolve(units, sk, seg, period, ot):
        nonlocal clock
        for i in range(2):
            for p, _ in units[i]:
                stats[p.id]["toi"] += seg
        ev = []
        for i in range(2):
            ra = unit_rating(units[i], "a", period >= 3) / N["attack"] / (unit_rating(units[1 - i], "d", period >= 3) / N["defense"])
            lam = BASE_SHOTS_PER_SEC * seg * ra ** RATING_EXP * strength(sk[i], sk[1 - i], ot)
            if period == 3 and S[i]["goals"] > S[1 - i]["goals"] and 3600 - clock <= 300: lam *= .85
            ev += [(rng.randrange(seg), i) for _ in range(poisson(lam))]
            if not ot and rng.random() < PEN_PER_SEC * seg and len(S[i]["pen"]) < 2:
                offender = rng.choices(units[i], [e[0].attr("physical") ** 1.5 for e in units[i]])[0][0]
                stats[offender.id]["pim"] += 2
                S[i]["pen"].append(clock + rng.randrange(seg) + 120); S[1 - i]["ppo"] += 1; S[i]["pull"] = False
        for _, i in sorted(ev):
            s, o, u = S[i], S[1 - i], units[i]
            pp = sk[i] > sk[1 - i] and not s["pull"]
            sh = sk[i] < sk[1 - i] and not o["pull"]
            w = [p.t.get("shots60", 5) ** SHOT_WEIGHT_EXP * (1.25 if pp and p.off and p.offside_at(sp) else 1) for p, sp in u]
            p, sp = rng.choices(u, w)[0]
            s["shots"] += 1; stats[p.id]["shots"] += 1
            pr = 0.55 if o["pull"] else goal_prob(p, sp, o["g"], pp, sh, ot)
            if not o["pull"]: gstats[o["g"].id]["sa"] += 1
            if rng.random() < pr:
                s["goals"] += 1; stats[p.id]["g"] += 1
                if not o["pull"]: gstats[o["g"].id]["ga"] += 1
                if pp: s["ppg"] += 1
                helpers = [(q, q.t.get("a60", 1.2) ** ASSIST_EXP) for q, _ in u if q is not p]
                for chance in (0.93, 0.72):
                    if helpers and rng.random() < chance:
                        q = rng.choices([h[0] for h in helpers], [h[1] for h in helpers])[0]
                        stats[q.id]["a"] += 1; helpers = [h for h in helpers if h[0] is not q]
                    else:
                        break
                if not pp:
                    for q, _ in u: stats[q.id]["pm"] += 1
                    for q, _ in units[1 - i]: stats[q.id]["pm"] -= 1
                if pp and o["pen"]:
                    o["pen"].sort(); o["pen"].pop(0)
                if ot: return True
        return False

    for period in (1, 2, 3):
        t = 0
        while t < 1200:
            for s in S: s["pen"] = [e for e in s["pen"] if e > clock]
            if period == 3:
                for i in range(2):
                    d = S[1 - i]["goals"] - S[i]["goals"]; tl = 1200 - t
                    pa = {1: 90, 2: 210}.get(d, -1)
                    S[i]["pull"] = pa > 0 and tl <= pa and not S[i]["pen"]
            sk = [5 - min(2, len(s["pen"])) + (1 if s["pull"] else 0) for s in S]
            resolve([pick(0, sk, t), pick(1, sk, t)], sk, SEG, period, False)
            t += SEG; clock += SEG
    ot = ""
    if S[0]["goals"] == S[1]["goals"]:
        ot = "OT"
        for s in S: s["pen"] = []; s["pull"] = False
        done = False
        for k in range(10):
            units = [[e for e in s["lu"]["f"][k % 3][:2] if on(e)] + [s["lu"]["d"][k % 3][0]] for s in S]
            if resolve(units, [3, 3], 30, 4, True): done = True; break
        if not done:
            ot = "SO"; S[rng.randrange(2)]["goals"] += 1
    for s in S:
        for e in [e for l in s["lu"]["f"] for e in l] + [e for x in s["lu"]["d"] for e in x]:
            if on(e): stats[e[0].id]["gp"] += 1
        gstats[s["g"].id]["gp"] += 1
        gstats[s["g"].id]["w"] += 1 if s["goals"] > S[1 - S.index(s)]["goals"] else 0
    return S, ot


def schedule():
    teams = L["teams"]
    div = defaultdict(list); conf = defaultdict(set)
    for t in teams: div[t["division"]].append(t["id"]); conf[t["conference"]].add(t["division"])
    games = []
    for ids in div.values():
        ids.sort(); n = len(ids)
        for i in range(n):
            for j in range(i + 1, n):
                a, b = ids[i], ids[j]
                if j == i + 1 or (i == 0 and j == n - 1):
                    h2 = a if j == i + 1 else b; h1 = b if h2 == a else a
                    games += [(h2, h1)] * 2 + [(h1, h2)]
                else:
                    games += [(a, b)] * 2 + [(b, a)] * 2
    for ds in conf.values():
        d1, d2 = (div[d] for d in sorted(ds))
        for i in range(8):
            for j in range(8):
                games += ([(d1[i], d2[j])] * 2 + [(d2[j], d1[i])]) if (i + j) % 2 == 0 else ([(d1[i], d2[j])] + [(d2[j], d1[i])] * 2)
    cs = list(conf)
    E = [t["id"] for t in teams if t["conference"] == cs[0]]; W = [t["id"] for t in teams if t["conference"] != cs[0]]
    games += [g for a in E for b in W for g in ((a, b), (b, a))]
    rng.shuffle(games)
    return games


if __name__ == "__main__":
    print("norms", {k: round(v, 2) for k, v in N.items()})
    pts = defaultdict(int); tot = defaultdict(float); ots = defaultdict(int)
    games = schedule()
    for h, a in games:
        S, ot = play(h, a)
        hg, ag = S[0]["goals"], S[1]["goals"]
        tot["g"] += hg + ag; tot["s"] += S[0]["shots"] + S[1]["shots"]
        tot["ppg"] += S[0]["ppg"] + S[1]["ppg"]; tot["ppo"] += S[0]["ppo"] + S[1]["ppo"]; ots[ot] += 1
        w = h if hg > ag else a; lo = a if w == h else h
        pts[w] += 2
        if ot: pts[lo] += 1
    G = len(games)
    print(f"goals/game {tot['g']/G:.2f}  shots/team {tot['s']/G/2:.1f}  sv% {1-(tot['g']-ots['SO'])/tot['s']:.3f}  "
          f"PP% {tot['ppg']/tot['ppo']*100:.1f}  PP opps/team {tot['ppo']/G/2:.2f}  OT {ots['OT']/G*100:.0f}% SO {ots['SO']/G*100:.0f}%")
    names = {t["id"]: t["city"] + " " + t["name"] for t in L["teams"]}
    st = sorted(pts.items(), key=lambda x: -x[1])
    print("standings: top", [(names[t], p) for t, p in st[:3]], "bottom", [(names[t], p) for t, p in st[-3:]])

    def nm(pid): return f'{PL[pid].first_name} {PL[pid].last_name} ({PL[pid].team})'
    sk = {pid: s for pid, s in stats.items() if s["gp"] > 0}
    for key, label in (("pts", "Points"), ("g", "Goals"), ("a", "Assists")):
        get = (lambda s: s["g"] + s["a"]) if key == "pts" else (lambda s: s[key])
        top = sorted(sk, key=lambda pid: -get(sk[pid]))[:8]
        print(f"{label}: " + ", ".join(f"{nm(pid)} {int(get(sk[pid]))}" for pid in top))
    dmen = [pid for pid in sk if PL[pid].pos in ("LD", "RD")]
    top_d = sorted(dmen, key=lambda pid: -(sk[pid]["g"] + sk[pid]["a"]))[:5]
    print("D points: " + ", ".join(f"{nm(pid)} {int(sk[pid]['g']+sk[pid]['a'])}" for pid in top_d))
    full = [pid for pid in sk if sk[pid]["gp"] >= 70]
    count = lambda f: sum(1 for pid in full if f(sk[pid]))
    print(f"100-pt players {count(lambda s: s['g']+s['a'] >= 100)}, 80+ {count(lambda s: s['g']+s['a'] >= 80)}, "
          f"40-goal {count(lambda s: s['g'] >= 40)}, 30-goal {count(lambda s: s['g'] >= 30)}")
    toi_f = sorted((sk[pid]["toi"] / sk[pid]["gp"] / 60 for pid in full if PL[pid].pos not in ("LD", "RD")), reverse=True)
    toi_d = sorted((sk[pid]["toi"] / sk[pid]["gp"] / 60 for pid in full if PL[pid].pos in ("LD", "RD")), reverse=True)
    print(f"TOI F max {toi_f[0]:.1f} median {toi_f[len(toi_f)//2]:.1f} min {toi_f[-1]:.1f} | D max {toi_d[0]:.1f} median {toi_d[len(toi_d)//2]:.1f}")
    pm = sorted(sk[pid]["pm"] for pid in full)
    pim = sorted((sk[pid]["pim"] for pid in full), reverse=True)
    print(f"+/- range {int(pm[0])}..{int(pm[-1])}  PIM leader {int(pim[0])}")
    gl = [(pid, s) for pid, s in gstats.items() if s["gp"] >= 30]
    svs = sorted(((1 - s["ga"] / s["sa"]), s["gp"], pid) for pid, s in gl)
    print(f"goalies 30+ GP: {len(gl)}, sv% {svs[0][0]:.3f}..{svs[-1][0]:.3f}, max GP {int(max(s['gp'] for _, s in gl))}")
