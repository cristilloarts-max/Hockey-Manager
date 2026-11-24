# Hockey GM — Game Design

A hockey management sim built in Godot 4. You take over a team in a league built from real NHL rosters, with spoofed names, and act as both **GM and head coach**. You rebuild the team, trade, manage the cap, coach games and chase the championship.

---

## Decisions so far

| Topic | Decision |
|---|---|
| Engine | Godot 4, GDScript |
| Data | Real NHL rosters and stats → `data/league.json` via `tools/build_league.py` |
| Names | Subtle spoofs: players one or two letters off, teams keep the real city with a new nickname. Hand fixes go in `tools/overrides.json` |
| Contracts | Generated from rating, age and stats for now; real cap data can be imported from CSV later |
| Ratings basis | 2025-26 (65%) + 2024-25 (35%) stats, applied to 2026-27 rosters |
| Role | GM **and** coach |
| Match viewing | Instant result + text play-by-play first; live match view in phase 6 |
| Firing | Yes, but **only** if you miss the owner's goals |

---

## 1. Players

### Attributes (1–20)
- **Skaters:** skating, shooting, passing, puck handling, offensive IQ, defense, physical, endurance, faceoffs.
- **Goalies:** reflexes, positioning, rebound control, glove, puck handling, consistency, mental.
- **Overall (45–99)** is a summary for display only. The sim uses the attributes.
- **Potential** is hidden. Scouts show it as a range.

### Positions and familiarity
Every skater has a familiarity rating from 1 to 20 for each of the five spots: **C, LW, RW, LD, RD**.

| Familiarity | Label | Effect in the sim |
|---|---|---|
| 18–20 | Natural | full ratings |
| 14–17 | Accomplished | about −3% |
| 10–13 | Competent | about −8% |
| 6–9 | Unconvincing | about −15%, more positional errors |
| 1–5 | Awkward | about −25%, frequent errors |

Each player also has:
- **Preferred position**, e.g. `RW`.
- **Comfortable positions** (familiarity 14+), e.g. `["C"]`.
- **Side preference**, `prefers_off_side`:
  - **Off-wing forward** (a left shot on RW): gets a one-timer bonus from the off-wing circle and a better shooting angle on the rush, but is weaker on the boards and on breakout passes along the wall.
  - **Strong-side forward:** gets a breakout and wall-play bonus and protects the puck better on the cycle.
  - **Off-side D** (a left shot on RD): gets a one-timer bonus from the point and more offensive activation, but is weaker on backhand retrievals and on clearing along his boards.
  - **Strong-side D:** gets a retrieval, breakout and gap-control bonus.
- **Rules of thumb in the data:**
  - Centers who take draws are usually accomplished on one wing.
  - Wingers who win faceoffs can fill in at C.
  - D can switch sides at a cost.
  - D rarely play forward.
- **Familiarity grows with time played.** A RW playing C all season becomes accomplished there. A training focus can speed this up.

The line editor shows each player's familiarity badge in the slot he's in. You can put anyone anywhere and the sim applies the penalty.

---

## 2. Coaching tactics

Tactics are layered:
1. **Team systems**
2. **Line overrides**
3. **Player instructions**
4. **Game situations**

Every system is a choice that has its own sub-options. Each option has strengths, weaknesses and the attributes it relies on. **Tactical familiarity** (0–100%) grows with practice, and new or changed systems are run poorly at first.

### 2.1 Forecheck
| System | Description |
|---|---|
| 1-2-2 | Balanced, F1 pressures and F2/F3 read |
| 2-1-2 | Aggressive, two forwards in deep |
| 2-3 / Left-wing lock | Conservative, LW drops into the D line |
| 1-3-1 | Neutral-zone clog |
| All-out (3 deep) | Maximum pressure, high risk |

**Sub-options:**
- **Pressure intensity:** contain / angle / attack.
- **F1 route:** steer to the strong side / steer to the weak side / take the body.
- **F2 role:** take away D-to-D / support F1 / seal the wall.
- **D pinch rule:** never / when supported / aggressive.
- **When to forecheck:** always / only after a dump-in / only when trailing.

**Effects:** aggressive systems create turnovers and offensive-zone time but give up odd-man rushes, drain fatigue faster and rely on skating, endurance and hockey IQ.

### 2.2 Neutral-zone defense
- **System:** 1-2-2 trap / 1-3-1 / left-wing lock / man pressure.
- **D gap:** tight / standard / loose.
- **Blue-line stand-up:** always / skill-dependent / never (sag back).
- **Forward backcheck:** all three / two / one high.

### 2.3 Defensive-zone coverage
- **System:** zone / man-to-man / hybrid (zone low, man high) / swarm.
- **Collapse level:** protect the house / balanced / pressure the points.
- **Weak-side winger:** cover the point / sag to the slot.
- **Shot blocking:** active / selective / avoid (protect players from injury).
- **Net-front battle:** box out / tie up sticks / front the shooter.
- **Centre low support:** always / read-based.

### 2.4 Breakout
- **Type:** standard up the wall / reverse / wheel (D carries) / stretch pass / D-to-D / centre swing low.
- **Risk:** safe (glass and out) / balanced / possession at all costs.
- **Winger depth:** on the hash marks / at the blue line / stretched to the red line.
- **Retrieval D:** strong-side man / whoever's closest.

### 2.5 Zone entry
- **Style:** carry in / dump and chase / chip and chase / drop pass / cross-ice delay.
- **Carrier:** best puck handler / whoever has it.
- **Trailer:** D jumps up / F3 stays high.
- **Dump target:** wide rim / hard around / soft area for the chase.

### 2.6 Offensive-zone attack
- **Structure:** low cycle / point shots + traffic / overload / umbrella / low-to-high / east-west seam.
- **Net-front presence:** none / one player / crash two on every shot.
- **D activation:** stay home / walk the line / activate down the wall / rove.
- **Shot selection:** shoot everything / quality only / looking for tips and rebounds.
- **Cycle direction:** strong side / switch on the weak side.

### 2.7 Rush offense
- **Width:** stretch wide / narrow lanes / triangle.
- **Middle lane:** drive the net / delay and find the trailer.
- **Odd-man rushes:** shoot first / pass first / attack the net.

### 2.8 Power play
- **Formation:** 1-3-1 / umbrella (1-2-2) / overload / spread / 2-1-2.
- **Entry:** drop pass / slingshot / carry with support / dump and retrieve.
- **Primary threat:** off-wing one-timer / point bomb / bumper slot / net-front tips.
  - This uses the **handedness and side preference** from section 1. An off-wing righty on the left circle gets the one-timer bonus.
- **Puck movement:** patient / quick strike / shoot on sight.
- **Unit usage:** PP1 heavy (about 1:40) / even split.

### 2.9 Penalty kill
- **Formation:** box / diamond / wedge+1 / aggressive 1-3.
- **Pressure:** passive (protect the slot) / pressure the bumps / attack the puck carrier.
- **Shorthanded offense:** clear and change / counter when chances appear.
- **Shot blocking:** maximum / selective.
- **Entry defense:** pressure at the red line / 1-3 stack at the blue line.

### 2.10 Game management
- **Mentality:** a 7-step slider from Shell to Defensive to Cautious to Balanced to Positive to Attacking to All-out.
- **Tempo:** slow / controlled / fast.
- **Physicality:** avoid / balanced / punishing (affects injuries and penalties).
- **Discipline:** stay clean / balanced / edge.
- **Shift length:** short (35s) / standard (45s) / long (60s).

### 2.11 Line overrides
Each forward line and D pair can override any team system, and gets a **role**:
- Scoring
- Two-way
- Shutdown
- Checking
- Energy

**Ice-time targets** come in three ways: per line (as percentages) or per player (in minutes). Line roles also feed line matching (section 2.13).

### 2.12 Player instructions
| Group | Instructions |
|---|---|
| Shooting | shoot more / normal / pass first |
| Positioning | stay home / normal / jump into the play |
| Physical | finish checks / normal / avoid contact |
| Net-front | crash the net / normal |
| Puck play | carry / move it quickly |
| Defense (D only) | pinch more / pinch less |
| Faceoffs | tie-up / win cleanly to the strong side / win to the weak side |

### 2.13 Game situations (automatic rules)
- **Leading in the 3rd:** switch to Defensive at X minutes / keep the system.
- **Trailing late:** pull the goalie with X:XX left when down by 1 or by 2. Choose the 6-attacker personnel and formation.
- **Line matching:**
  - At home, you get the last change and can choose who matches the opponent's top line.
  - On the road, match on the fly or don't match.
- **Overtime 3-on-3:** possession and regroup / attack / two forwards and one D vs one forward and two D.
- **Shootout:** your shooter order, or auto by shooting and puck handling.
- **Icing:** keep the timeout for a tired line after icing / save it.
- **After goals:** send the energy line out / the shutdown line / nothing.

### 2.14 Counters and scouting
- Opponents have their own systems. Your **pre-game scouting report** shows them, e.g. "They run a 2-1-2 forecheck → the stretch breakout exploits it."
- Some systems naturally beat others:
  - stretch pass vs an aggressive forecheck
  - dump and chase vs a stand-up blue line
  - point shots vs a collapsing zone
- Changes you make mid-game during intermission cost tactical familiarity for that game.

---

## 3. Set play creator

Build your own plays on a 2D rink, practice them, and call them in games.

### 3.1 Situations a play can be made for
| Situation | Example |
|---|---|
| Offensive-zone faceoff (left or right dot) | win back, D-to-D, one-timer from the off-side D |
| Defensive-zone faceoff | win to the strong-side D, wall exit |
| Neutral-zone faceoff | win forward, chip, wingers drive |
| Power play entry | drop-pass slingshot |
| Power play setup | 1-3-1 bumper look → backdoor |
| Penalty kill faceoff | win and clear |
| 6-on-5 (goalie pulled) | overload low, point slap-pass |
| Breakout (set, after a regroup) | reverse with the D swinging |
| 3-on-3 OT | regroup and wide carry |

### 3.2 Building a play
1. **Pick the situation.** The rink snaps players to their starting spots, including the faceoff alignment.
2. **Slots are positions, not names:** C, LW, RW, LD, RD (plus a sixth attacker for 6-on-5). Any line can run any play.
3. **Draw steps on a timeline.** Each step is one of:
   - **Move** (drag a path)
   - **Pass** (A → B; choose saucer / hard / slap-pass)
   - **Shoot** (wrist / slap / one-timer / tip)
   - **Screen** (stand in front of the goalie)
   - **Pick / pick-off** (legal interference)
   - **Win the faceoff** to a target (back / forward / to the side)
   - **Retrieve / support**
4. **Tie steps together** with "after step 2", "at the same time" or "if the pass is blocked, go to option B".
5. **Option branches** (up to 3): read the defense and choose a pass or shot target.
6. **Name the play** and save it to the playbook, e.g. "Hammer Left".

### 3.3 How a play works in the sim
The sim scores a play using:
- **Role fit:** players' attributes for their tasks. A one-timer shooter needs shooting, and gets the off-side bonus if his hand matches his spot. A passer needs passing, a faceoff taker needs faceoffs.
- **Execution chance:** for each step, from attributes + **play familiarity** (practice) + fatigue.
- **Defensive read:** the opponent's PK or defensive system and their hockey IQ can read and disrupt the play.
- **Predictability:** running the same play over and over raises opponents' scouting on it, and it works less well until you vary it.

| Outcome | Result |
|---|---|
| Full success | High-danger shot with a bonus |
| Partial success | Normal shot or possession kept |
| Failure | Turnover, possibly an odd-man rush against |

**Commentary** narrates the play: *"Off the draw, McDevid wins it back to Boucherd, D-to-D to Ekholmm — one-timer — SCORES!"*

### 3.4 Playbook management
- **Practice slots** are limited (see section 4). More slots on a play means it's executed better.
- Each special-teams unit and each faceoff situation has its own play list.
- **Auto-call** chooses from the list based on the opponent's weak spots. You can also call plays manually in the live view.
- **Starter playbook:** a handful of pre-made plays, so it works out of the box.

---

## 4. Practice and coaching staff
- Each week has a set number of **practice points** to spread across:
  - conditioning
  - team systems (raises tactical familiarity)
  - set plays
  - special teams
  - individual skill development
  - position retraining
- **Too much practice causes fatigue and injury risk.** Back-to-back games limit what you can do.
- **Coaching staff:**
  - assistants (PP specialist, D coach, goalie coach)
  - skills coach
  - video coach (scouting and counters)
  - Staff ratings speed up familiarity and development.

---

## 5. Match simulation (summary)
- **Shift-based possession model.** Each possession runs through these phases, each checking the relevant tactics against the opponent's:
  1. faceoff / retrieval
  2. breakout
  3. neutral zone
  4. entry
  5. offensive-zone play
  6. shot
  7. rebound
- **Position familiarity** and **side preference** modify the player's ratings on every event.
- **Calibration targets:** about 6 goals per game, ~30 shots per team, 0.905 save %, ~20% PP, ~3 power plays per team.
- **Output:**
  - box score
  - shot map
  - event log for commentary
  - player stats
  - fatigue and injuries

---

## 6. Owner and job security
- **Each season the owner sets 1–3 goals,** based on team strength and the club's situation. Examples:
  - make the playoffs
  - win a round
  - develop two prospects into NHL regulars
  - stay under budget
  - win the Cup
- **Confidence (0–100)** moves with results, but the **firing decision is made only at evaluation points:**
  - the trade deadline, as a warning only
  - the end of the season
- **You're fired only if goals are missed.** Meeting the goals keeps you safe, however confidence looks.
- Missing a goal in one season gives a warning. Missing goals in two seasons in a row gets you fired.
- After a firing: game over, or apply to an open job elsewhere.

---

## 7. Other systems
These carry over from the brainstorm:
- calendar and events
- contracts: RFA/UFA, extensions, buyouts, waivers, LTIR
- trades with AI GM strategies and anti-exploit rules
- generated draft classes, lottery and scouting fog
- free agency bidding
- minor-league affiliate
- injuries and morale
- awards and history

---

## 8. Build order
| Phase | Scope |
|---|---|
| 1 | Load the league, team picker, roster and cap screens, line editor with position familiarity, basic sim, standings and stats, text play-by-play |
| 2 | Playoffs, champion, awards, owner goals and firing |
| 3 | Trades with AI valuation, trade deadline |
| 4 | Offseason: contracts, re-signing, free agency, buyouts, waivers |
| 5 | Draft, scouting, development and aging (multi-season) |
| 6 | Full tactics layer, practice, coaching staff, live match view |
| 7 | Set play creator and playbook |

Tactics data structures are defined in phase 1, so the sim reads them from the start, even before the full tactics screens exist.
