# Hockey Manager

A hockey management sim built in **Godot 4.5**. Take over a team in a league built from real NHL rosters (with spoofed names), work within the salary cap, set your lines and tactics, simulate the season and chase the championship.

See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) for the full design and roadmap.

## Running it

1. Install [Godot 4.5](https://godotengine.org/download) (the standard build, not .NET).
2. In the Project Manager, choose **Import** and select `project.godot` in this folder.
3. Press **F5** (Run Project).

## Phase 3: trades and the trade deadline

- **Trade Center** (Trades menu):
  - Pick a partner and double-click players or picks on either side.
  - Live panel: cap and roster impact for both teams, plus the AI's reaction (Not interested / Not enough / Close / Deal).
  - Ask what they want: the AI fills in a package from your assets.
  - Retain 25% or 50% of an outgoing player's salary (max 3 retained contracts).
- **AI valuation**:
  - Each team is a contender, bubble team or rebuilding team, from roster strength and the standings.
  - Contenders want current ability and rentals; rebuilders want youth, potential and picks.
  - A player's value grows steeply with his overall, and contracts matter (bargains add value, overpays subtract).
  - Draft picks: 2027-2029, rounds 1-3. Their value depends on where the original team is projected to finish.
- **Anti-exploit rules**:
  - Quality beats quantity: extra pieces count for less, and each extra body costs a roster spot.
  - AI teams want to win by 5%.
  - Franchise players cost 35% extra.
  - Players you acquired in the last 30 days are worth 20% less to AI teams (no flipping).
  - Trades can't put either team over the cap or leave a team without two goalies.
  - No-trade clauses: those players only waive for contenders.
- **The market**:
  - AI teams send you offers (accept, decline or negotiate); the trading block draws more of them.
  - AI teams trade with each other: sellers move veterans to contenders.
  - Activity spikes in deadline week. Every trade appears in Trade History and the inbox.
- **Trade deadline: March 6.** You get a warning two weeks out; after the deadline, trading closes until the offseason.
- **Sim controls**:
  - "Sim to end of regular season" now stops when the playoffs begin.
  - In the playoffs, use "Sim to end of this round" or "Sim to end of playoffs", or play game by game with Continue.

## Phase 2: real rosters, roster rules, playoffs and awards

- **Ratings from four seasons of career data.**
  - The current 2026-27 season counts most, then 2025-26, 2024-25 and 2023-24, each weighted by games played.
  - Prospects are rated from their junior, college, AHL and European production, converted to NHL-equivalent scoring (NHLe).
- **Rosters and lines as teams use them right now.**
  - Current rosters, with each team's lines, PP units, PK units and goalie split taken from this season's real ice time.
  - Extra players start on the reserve list.
- **Roster and cap rules.**
  - A maximum of 23 players on the NHL roster, at least 20, and two goalies.
  - Reserve players count against the cap only above the burial allowance.
  - Continue is blocked until your roster is legal.
  - Use **Call Up** / **Send to Reserve** on the Players page or the player profile.
- **Lines: drag and drop.**
  - Drag a player from the squad table onto a jersey, or drag one jersey onto another to swap them.
  - Drop a jersey on the table to take him out of the lineup.
  - Clicking a jersey still opens the player list.
  - Set how often your starting goalie plays.
- **Realistic stats.**
  - Each player shoots, scores and sets up goals at rates based on his real per-60 numbers, blended with his ratings.
  - The goalie split follows each team's real starts.
  - Calibrated over full seasons: about 6.1 goals per game, a .900 save %, 19% on the power play, a few 100-point players, 40-goal leaders around 45-54, starting goalies around 65-72 games, and standings from about 60 to 120 points.
- **Playoffs.**
  - 16 teams: the top 3 in each division plus 2 wild cards per conference.
  - Best-of-seven series with 2-2-1-1-1 home ice and playoff overtime.
  - A bracket page and separate playoff stats.
- **Champion and awards.**
  - Team awards: the Stanton Cup, the conference trophies (Wallace Trophy, Campton Bowl), the Presidents' Shield, the Jenning Trophy and the Jack Addams Award (coach of the year; it can be you).
  - Player awards: the Hartwell (MVP), Art Rose (points), Rocket Richter (goals), Norrison (defenseman), Vezino (goalie), Caldor (rookie), Selkirk (defensive forward) and Conn Smith (playoff MVP).
  - During the season, the Awards page shows the live races.

## Look and feel

- **Dark navy theme, team colors everywhere.**
  - Each club has its own colors: crests, jerseys, the top bar when it's your team, the club page when it's an opponent, and the box score.
  - A hot-pink **Continue** button drives the game.
- **Color scales you can read at a glance:**
  - attributes 1-20: red (weak), orange, yellow, lime, green (elite)
  - match ratings and form tiles: red (bad night) to green (great night)
  - morale (Superb to Very Poor) and condition (%)
  - results: green W, red L, orange OT
- **Football Manager-style navigation:** back/forward, section menus (Home, Squad, Tactics, League) with sub-tabs, the date and next opponent, and Continue.
- **Player profile:**
  - **Header:** team-colored, with ability and potential stars and squad status.
  - **Positions:** a rink showing familiarity at every spot.
  - **Roles:** hockey roles (Sniper, Playmaker, Power Forward, Offensive D, Butterfly...) with star ratings. Picking one highlights its key attributes.
  - **Attributes:** 26 detailed attributes in Technical / Mental / Physical columns (15 for goalies).
  - **Bottom strip:** morale, condition, last-5 form tiles and season stats.
- **Lines:**
  - Pick a unit (Line 1-4, PP1-2, PK1-2, Goalies) and see it on the rink in your jerseys.
  - Each jersey shows the player's best role and his familiarity at that spot; click a jersey to swap players.
  - The squad table alongside shows line badges, condition, morale and form.
- **Club page:**
  - crest card and club facts
  - a league-position chart over the season
  - recent results as colored tiles
  - upcoming games
  - key personnel on jerseys
- **Living players:** every game gives each player a match rating, which feeds his form (last 5) and season average.
  - **Morale** rises and falls with results, his own play and whether he dresses.
  - **Condition** drops with ice time and recovers between games; tired players play slightly worse.

## What's in Phase 1

- **Team picker:** all 32 teams with strength, payroll, cap space and key players.
- **Players:** sortable, color-coded roster with roles, condition, morale, form, stats, contracts and squad status. Double-click anyone to open his profile.
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
