"""Season calibration: a Python mirror of match_sim.gd, lineup.gd and schedule.gd.

Plays a full 1,312-game season from data/league.json and prints league averages
(goals/game, shots, save %, PP %, OT rate) and the standings spread, so sim
constants can be tuned without opening Godot. Keep its constants in sync with
scripts/core/match_sim.gd when you change them.

Usage: python3 tools/sim_calibration.py data/league.json
"""
import json, math, random, sys
from collections import defaultdict

L = json.load(open(sys.argv[1]))
TIERS = [(18, 1.0), (14, .97), (10, .92), (6, .85), (1, .75)]
FWD = ["LW", "C", "RW"]; DS = ["LD", "RD"]


class P:
    def __init__(s, d):
        s.__dict__.update(d); s.pos = d["positions"]["preferred"]; s.fam = d["positions"]["familiarity"]
        s.off = d["positions"]["prefers_off_side"]; s.a = d["attributes"]
    def g(s): return s.pos == "G"
    def attr(s, k): return s.a.get(k, 1)
    def pf(s, spot):
        f = 20 if s.g() else s.fam.get(spot, 1)
        for t, m in TIERS:
            if f >= t: return m
    def side(s, spot): return "L" if spot in ("LW", "LD") else "R" if spot in ("RW", "RD") else ""
    def offside_at(s, spot): sd = s.side(spot); return sd != "" and sd != s.shoots
    def pref_side(s, spot): return s.side(spot) == "" or s.offside_at(spot) == s.off


players = {p["id"]: P(p) for p in L["players"]}
roster = defaultdict(list)
for p in players.values(): roster[p.team].append(p)


def autofill(ps):
    used = set(); fl = [[None] * 3 for _ in range(4)]; dp = [[None] * 2 for _ in range(3)]
    sk = [p for p in ps if not p.g()]
    def best(spot):
        c = [p for p in sk if p.id not in used]
        b = max(c, key=lambda p: p.overall * p.pf(spot) + (1 if p.pref_side(spot) else 0))
        used.add(b.id); return b
    for l in range(4):
        for s in range(3): fl[l][s] = best(FWD[s])
        if l < 3:
            for s in range(2): dp[l][s] = best(DS[s])
    gs = sorted([p for p in ps if p.g()], key=lambda p: -p.overall)
    f = [p for l in fl for p in l]; d = [p for x in dp for p in x]
    off = lambda p: p.attr("shooting") + p.attr("passing") + p.attr("offense_iq") + p.attr("puck_handling")
    de = lambda p: p.attr("defense") * 2 + p.attr("offense_iq") + p.attr("skating")
    fo = sorted(f, key=off, reverse=True); do = sorted(d, key=off, reverse=True)
    fd = sorted(f, key=de, reverse=True); dd = sorted(d, key=de, reverse=True)
    pp = [list(zip(fo[u*3:u*3+3], FWD)) + list(zip(do[u*2:u*2+2], DS)) for u in range(2)]
    pk = [list(zip(fd[u*2:u*2+2], ["C", "LW"])) + list(zip(dd[u*2:u*2+2], DS)) for u in range(2)]
    return {"f": [list(zip(l, FWD)) for l in fl], "d": [list(zip(x, DS)) for x in dp], "g": gs[0], "pp": pp, "pk": pk}


att = lambda p, s: (.25*p.attr("shooting")+.25*p.attr("passing")+.2*p.attr("puck_handling")+.2*p.attr("offense_iq")+.1*p.attr("skating"))*p.pf(s)
dfn = lambda p, s: (.45*p.attr("defense")+.2*p.attr("skating")+.15*p.attr("physical")+.2*p.attr("offense_iq"))*p.pf(s)
shv = lambda p, s: (.6*p.attr("shooting")+.2*p.attr("offense_iq")+.2*p.attr("puck_handling"))*p.pf(s)
gr = lambda g: .3*g.attr("reflexes")+.3*g.attr("positioning")+.15*g.attr("rebound_control")+.15*g.attr("glove")+.1*g.attr("consistency")

lineups = {t: autofill(r) for t, r in roster.items()}
A = D = n = sw = ss = gs = gn = 0
for lu in lineups.values():
    for e in [e for l in lu["f"] for e in l] + [e for x in lu["d"] for e in x]:
        p, s = e; A += att(p, s); D += dfn(p, s); n += 1
        w = p.attr("shooting")**2 * (.55 if s in DS else 1); ss += shv(p, s)*w; sw += w
    gs += gr(lu["g"]); gn += 1
N = {"attack": A/n, "defense": D/n, "shooting": ss/sw, "goalie": gs/gn}
print("norms", {k: round(v, 2) for k, v in N.items()})

SEG = 40; BS = 28.5/3600; BG = .087; RX = 0.8; PEN = 3.2/3600
FS = [.35, .30, .21, .14]; DSH = [.40, .34, .26]


def poisson(r, lam):
    l = math.exp(-lam); k = 0; p = 1
    while True:
        p *= r.random()
        if p <= l: return k
        k += 1


def unit_rating(u, kind, late):
    t = 0
    for p, s in u:
        v = att(p, s) if kind == "a" else dfn(p, s)
        if p.side(s) and not p.off and not p.offside_at(s): v *= 1.02
        if late: v *= .96 + .04*p.attr("endurance")/20
        t += v
    return t/len(u)


def nextline(used, shares):
    tot = sum(used); return max(range(len(shares)), key=lambda k: shares[k]*(tot+1)-used[k])


def play(h, a, r):
    S = [{"lu": lineups[h], "goals": 0, "shots": 0, "pen": [], "fu": [0]*4, "du": [0]*3, "pull": False, "ppg": 0, "ppo": 0},
         {"lu": lineups[a], "goals": 0, "shots": 0, "pen": [], "fu": [0]*4, "du": [0]*3, "pull": False, "ppg": 0, "ppo": 0}]
    clock = 0
    def pick(i, sk, t):
        s = S[i]; o = S[1-i]
        if o["pen"] and not s["pen"]:
            el = 120-(min(o["pen"])-clock); u = list(s["lu"]["pp"][0 if el < 80 else 1])
        elif s["pen"] and not o["pen"]:
            u = list(s["lu"]["pk"][(t//SEG) % 2])
        else:
            fi = nextline(s["fu"], FS); di = nextline(s["du"], DSH); s["fu"][fi] += SEG; s["du"][di] += SEG
            u = list(s["lu"]["f"][fi]) + list(s["lu"]["d"][di])
        while len(u) > sk[i]:
            u.remove(min(u, key=lambda e: e[0].overall + (50 if e[1] in DS else 0)))
        for e in [e for l in s["lu"]["f"] for e in l]:
            if len(u) >= sk[i]: break
            if e not in u: u.append(e)
        return u
    def strength(m, t, ot):
        if ot: return 1.7
        d = m-t
        return 2.8 if d >= 2 else 2.0 if d == 1 else .32 if d == -1 else .2 if d <= -2 else 1.15 if m == 4 else 1.0
    def resolve(units, sk, seg, period, ot):
        nonlocal clock
        ev = []
        for i in range(2):
            ra = unit_rating(units[i], "a", period >= 3)/N["attack"] / (unit_rating(units[1-i], "d", period >= 3)/N["defense"])
            lam = BS*seg*ra**RX*strength(sk[i], sk[1-i], ot)
            lead = S[i]["goals"]-S[1-i]["goals"]
            if period == 3 and lead > 0 and 3600-clock <= 300: lam *= .85
            for _ in range(poisson(r, lam)): ev.append((r.randrange(seg), i))
            if not ot and r.random() < PEN*seg and len(S[i]["pen"]) < 2:
                S[i]["pen"].append(clock+r.randrange(seg)+120); S[1-i]["ppo"] += 1; S[i]["pull"] = False
        for _, i in sorted(ev):
            s = S[i]; o = S[1-i]; u = units[i]
            pp = sk[i] > sk[1-i] and not s["pull"]; sh = sk[i] < sk[1-i] and not o["pull"]
            w = [p.attr("shooting")**2*(.55 if sp in DS else 1)*(1.4 if pp and p.off and p.offside_at(sp) else 1) for p, sp in u]
            p, sp = r.choices(u, w)[0]; s["shots"] += 1
            if o["pull"]: pr = .55
            else:
                sv = shv(p, sp)*(1.05 if p.off and p.offside_at(sp) else 1)
                pr = BG*(sv/N["shooting"])**RX*(N["goalie"]/gr(o["lu"]["g"]))**RX
                if pp: pr *= 1.25
                elif sh: pr *= 1.1
                if ot: pr *= 1.25
                pr = min(.4, max(.015, pr))
            if r.random() < pr:
                s["goals"] += 1
                if pp:
                    s["ppg"] += 1; o["pen"].sort(); o["pen"] and o["pen"].pop(0)
                if ot: return True
        return False
    for period in (1, 2, 3):
        t = 0
        while t < 1200:
            for s in S: s["pen"] = [e for e in s["pen"] if e > clock]
            if period == 3:
                for i in range(2):
                    d = S[1-i]["goals"]-S[i]["goals"]; tl = 1200-t
                    pa = {1: 90, 2: 210}.get(d, -1)
                    S[i]["pull"] = pa > 0 and tl <= pa and not S[i]["pen"]
            sk = [5-min(2, len(s["pen"]))+(1 if s["pull"] else 0) for s in S]
            units = [pick(0, sk, t), pick(1, sk, t)]
            resolve(units, sk, SEG, period, False)
            t += SEG; clock += SEG
    ot = ""
    if S[0]["goals"] == S[1]["goals"]:
        ot = "OT"
        for s in S: s["pen"] = []; s["pull"] = False
        done = False
        for k in range(10):
            units = [list(s["lu"]["f"][k % 3][:2]) + [s["lu"]["d"][k % 3][0]] for s in S]
            if resolve(units, [3, 3], 30, 4, True): done = True; break
        if not done:
            ot = "SO"; S[r.randrange(2)]["goals"] += 1
    return S, ot


# schedule check mirrors schedule.gd
teams = L["teams"]
div = defaultdict(list); conf = defaultdict(set)
for t in teams: div[t["division"]].append(t["id"]); conf[t["conference"]].add(t["division"])
games = []
for d, ids in div.items():
    ids.sort(); n = len(ids)
    for i in range(n):
        for j in range(i+1, n):
            a, b = ids[i], ids[j]
            if j == i+1 or (i == 0 and j == n-1):
                h2 = a if j == i+1 else b; h1 = b if h2 == a else a
                games += [(h2, h1)]*2 + [(h1, h2)]
            else: games += [(a, b)]*2 + [(b, a)]*2
for c, ds in conf.items():
    ds = sorted(ds)
    d1, d2 = div[ds[0]], div[ds[1]]
    for i in range(8):
        for j in range(8):
            if (i+j) % 2 == 0: games += [(d1[i], d2[j])]*2 + [(d2[j], d1[i])]
            else: games += [(d1[i], d2[j])] + [(d2[j], d1[i])]*2
cs = list(conf)
E = [t["id"] for t in teams if t["conference"] == cs[0]]; W = [t["id"] for t in teams if t["conference"] != cs[0]]
for a in E:
    for b in W: games += [(a, b), (b, a)]
gp = defaultdict(int); home = defaultdict(int)
for h, a in games: gp[h] += 1; gp[a] += 1; home[h] += 1
print("games/team", set(gp.values()), "home/team", set(home.values()), "total", len(games))

r = random.Random(1)
pool = games[:]; r.shuffle(pool)
rem = defaultdict(int)
for h, a in pool: rem[h] += 1; rem[a] += 1
last = defaultdict(lambda: -10); day = 0; sched = []
while pool:
    playing = set(); taken = []
    order = sorted(range(len(pool)), key=lambda i: -(rem[pool[i][0]]+rem[pool[i][1]]))
    for i in order:
        h, a = pool[i]
        if h in playing or a in playing or last[h] >= day-1 or last[a] >= day-1: continue
        playing |= {h, a}; taken.append(i); sched.append((day, h, a))
    for i in sorted(taken, reverse=True):
        h, a = pool.pop(i); rem[h] -= 1; rem[a] -= 1; last[h] = day; last[a] = day
    day += 1
print("season days", day)

# play the season
pts = defaultdict(int); tot = defaultdict(float); ots = defaultdict(int)
for d, h, a in sched:
    S, ot = play(h, a, r)
    hg, ag = S[0]["goals"], S[1]["goals"]
    tot["g"] += hg+ag; tot["s"] += S[0]["shots"]+S[1]["shots"]; tot["ppg"] += S[0]["ppg"]+S[1]["ppg"]; tot["ppo"] += S[0]["ppo"]+S[1]["ppo"]
    ots[ot] += 1
    w = h if hg > ag else a; lo = a if w == h else h
    pts[w] += 2
    if ot: pts[lo] += 1
G = len(sched)
print(f"goals/game {tot['g']/G:.2f}  shots/team {tot['s']/G/2:.1f}  sv% {1-(tot['g']-ots['SO'])/tot['s']:.3f}  PP% {tot['ppg']/tot['ppo']*100:.1f}  PP opps/team {tot['ppo']/G/2:.2f}  OT {ots['OT']/G*100:.0f}% SO {ots['SO']/G*100:.0f}%")
names = {t["id"]: t["city"]+" "+t["name"] for t in teams}
st = sorted(pts.items(), key=lambda x: -x[1])
print("top:", [(names[t], p) for t, p in st[:5]]); print("bottom:", [(names[t], p) for t, p in st[-4:]])
