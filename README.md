# Hockey Manager

A hockey management sim built in **Godot 4.5**. Take over a team in a league built from real NHL rosters (with spoofed names), work within the salary cap, set your lines and tactics, simulate the season and chase the championship.

See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the full design and roadmap.

## Running it

1. Install [Godot 4.5](https://godotengine.org/download) (the standard build, not .NET).
2. In the Project Manager, choose **Import** and select `project.godot` in this folder.
3. Press **F5** (Run Project).

## What's in Phase 1

- **Team picker:** all 32 teams with strength, payroll, cap space and key players.
- **Roster:** sortable table with positions, side preference, ratings, potential range, stats and contracts. Double-click a player for his profile: attributes, position familiarity at every spot, contract and season stats.
- **Lines:** 4 forward lines, 3 D pairs, goalies, 2 PP and 2 PK units.
  - Every slot shows the player's familiarity there (Natural to Awkward) and whether he's on his off side.
  - Anyone can play anywhere, but the sim applies the penalty.
  - Auto-pick builds the best lineup for you.
- **Tactics:** 11 areas and 52 settings.
  - 15 of them already affect games: mentality, forecheck, coverage, shot blocking, shot selection, physicality, discipline, power play threat, movement and usage, penalty kill pressure, protecting a lead and pulling the goalie.
  - The rest are saved and arrive with the full tactics engine.
- **Contracts & cap:** payroll, cap space and committed money for the next 5 seasons.
- **Season:**
  - An 82-game schedule in the NHL format, with 41 home games per team and no back-to-backs.
  - **Continue** sims to your next game and shows its box score and play-by-play.
  - **Sim to End** plays out the rest of the season.
- **Standings:** division, conference and league views with playoff spots marked.
- **League stats:** skater and goalie leaders.
- **Save / Load.**

### The match sim
`scripts/core/match_sim.gd` plays a game in 40-second shifts:
- Attack ratings vs defense ratings decide shots, and each shot is the shooter against the goalie.
- Every rating goes through position familiarity and side preference. Off-side shooters get a one-timer bonus; strong-side players get a breakout and wall-play bonus.
- It includes penalties and power plays, 4-on-4, pulling the goalie, 3-on-3 overtime, shootouts and playoff overtime.

**Calibrated over a full season:** about 6.0 goals per game, 30 shots per team, .902 save %, ~20% on the power play, and standings from about 58 to 127 points.

## Project layout

```
project.godot
scenes/main.tscn            root scene (everything else is built in code)
scripts/core/               game logic, no UI
  league.gd                 autoload "League": teams, players, finances
  game_state.gd             autoload "Game": calendar, schedule, results, standings, stats, save/load
  player.gd team.gd         data classes
  lineup.gd                 lines, PP/PK units, auto-fill
  tactics.gd                every tactic as data + effects used by the sim
  schedule.gd               82-game NHL-format schedule
  match_sim.gd              game simulation
scripts/ui/                 screens, built in code
data/league.json            the league (generated)
tools/                      Python data pipeline + sim calibration
docs/GAME_DESIGN.md         design doc
```

## Updating the league data

```
python3 tools/build_league.py --refresh
```
This pulls current rosters and the last two seasons of stats from the public NHL API, turns them into ratings, spoofs every name, generates contracts and writes `data/league.json`.

- To hand-tune a player (pin an overall, set attributes or fix an awkward name), add him to `tools/overrides.json`, keyed by real NHL player id, then rerun.
- After changing sim constants, check the league averages with:
  ```
  python3 tools/sim_calibration.py data/league.json
  ```

## Exporting

`data/league.json` is not a Godot resource, so when you set up an export preset, add `*.json` under **Resources → Filters to export non-resource files**.
