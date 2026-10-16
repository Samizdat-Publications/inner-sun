# M1b round 2: the digging economy, balance check (300 runs)

Spec: `docs/plans/specs/m1b_dig_sim.md`. Decisions: D025 to D028. Command:
`python tools/balance.py --full --runs 300 --procs 6 --pack` (pack of the branch, seeds 1000..1099,
100 runs per policy bot). The generated report follows the headline.

## Headline

| policy | won | median run | ore gained / spent | gems gained / spent | gear + upgrades bought per run | top causes of death (share of all runs) |
|---|---|---|---|---|---|---|
| cautious | 22% | 13.1 min | 698 / 326 | 68 / 46 | 1.84 + 0.23 = 2.1 | pursuer 50%, gate 15%, gate while pursued 12% |
| greedy | 17% | 9.8 min | 1197 / 630 | 111 / 36 | 1.38 + 1.40 = 2.8 | pursuer 37%, gate 31%, gate while pursued 9% |
| balanced | 51% | 12.1 min | 992 / 660 | 101 / 48 | 2.16 + 0.98 = 3.1 | gate 36%, pursuer 10%, gate while pursued 3% |

What each policy buys (per run): cautious plating 1.12, pumps 0.69, bracing 0.11, helm 0.12;
balanced tungsten head 0.95, plating 0.67, pumps 0.53, bracing 0.70, reactor 0.14, helm 0.14;
greedy tungsten head 0.91, diamond head 0.47, weapons 0.76, drill 0.48, reactor 0.16.
Coolant outs: 0 in 300 runs (was 6 to 11% before D026's coolant retune, about 45% with 60 m
segments and the old unit). Bit breaks: 0.01 to 0.25 per run; bits bought 0.8 to 1.3 per run.

Per segment (measured on real segments by `game/tests/test_dig_economy.gd`, fair richness, fresh
bit, 12 seeds each): deposits 6.3 / 10.0 / 11.6 at 0 / 240 / 420 m; ore driving straight for the
node 9.5 / 17.9 / 25.8; ore weaving greedily 47.5 / 102.3 / 136.5; 60.5 s at 3 bars, 82 s at 2 bars;
a greedy segment wears 0.36 of a bit (a bit lasts about 2.7 segments).

## Against the targets

- Cautious 22% and greedy 17% are inside the D021/D022 band (12 to 25%). Balanced at 51% is not:
  it wins the gate 57% of the time (D022: 29%). Causes, in order: the policy bot's power fix (D027:
  its guns now get their bars in fights; before, they got only what the drill released), cheap
  full repairs (ore is plentiful and hull stays 2 ore a point), hull plating, fewer fights on the way
  (min 1 per path). The gate ship (`data/ships/rival_heavy.json`) is outside this spec's files. An
  in-memory probe (24 runs per policy, seeds 2000..2023) with rival_heavy hull 13 -> 17: balanced 38%,
  cautious 4%, greedy 13%, so one gate number does not fix the spread; the lead should pick the
  lever (gate ship, hull repair price, fights per path or the policies).
- Run length: medians 9.8 to 13.1 min, under the 15 to 25 min aim. With 10 rows and 45 to 75 s
  segments, drilling is 7 to 11 minutes of a run; reaching 15+ minutes needs longer segments
  (about 100 s) or more rows.
- Gear and upgrades: balanced buys 3.1 per run (target 3 to 5), with 330 ore unspent at the gate on
  median; cautious 2.1, greedy 2.8.

## Full generated report

## Full-run balance report 20261016-122335

300 runs (100 per bot, seeds 1000..1099), 6 processes, wall 224 s (3.7 min, 12.5 min per 1000 runs). Pack: 20261016-122324-2eca28a.pck


| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 100 | 22.0 | 0 | 9 | 787 | 1.87 | 45 | pursuer 50% |
| greedy | 100 | 17.0 | 0 | 9 | 587 | 2.07 | 30 | pursuer 37% |
| balanced | 100 | 51.0 | 0 | 9 | 727 | 2.29 | 57 | gate 36% |

## cautious (100 runs)

- results: dead 78 (78.0%), won 22 (22.0%)
- run end causes (hull, crew_<cause>, flooded): hull 49, crew_heat 15, crew_fire 9, crew_combat 5
- killers (share of all runs): pursuer 50 (50.0%), gate 15 (15.0%), gate_pursued 12 (12.0%), drill_crew_heat 1 (1.0%)
- rows reached: 4: 1, 5: 3, 6: 1, 7: 10, 8: 24, 9: 61
- death row (non-wins): 4: 1, 5: 3, 6: 1, 7: 10, 8: 24, 9: 39
- run length s: median 787, p10 671, p90 847
- fights per run: 0: 1, 1: 24, 2: 62, 3: 13
- fight results: fled 9, gate died 27, gate won 22, won 129
- fight length s: rivals median 48, gate median 66
- gate reached 49 times, won 22 (45%)
- pursuer strikes on overtaken nodes: mean 0.46, runs with any 41%
- pursuer strikes while caught: mean 8.16, runs with any 80%
- pursuer catches: mean 0.93, runs with any 84%
- bit breaks: mean 0.25, runs with any 25%
- coolant outs: mean 0.00, runs with any 0%
- crew lost: mean 1.33, runs with any 50%
- fires started: mean 7.78, runs with any 100%
- nodes overtaken: mean 12.48, runs with any 100%
- crew death causes: heat@gate 51, combat@gate 32, heat@drill 20, fire@drill 13, fire@gate 11, fire@idle 5, combat@combat 1
- all: gems gained median 68, ore gained median 698
- winners: gems gained median 104, ore gained median 727
- losers: gems gained median 62, ore gained median 698
- store lines bought (store line: count): crust_trader 0: 160, crust_trader 1: 114, crust_trader 13: 3, crust_trader 15: 112, crust_trader 16: 69, crust_trader 2: 88, crust_trader 3: 60, crust_trader 4: 78, crust_trader 7: 12, crust_trader 8: 11

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 35 [30-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 60 | 35 [30-40] | 54 [24-107] | 15 [15-21] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 135 | 35 [30-40] | 122 [60-200] | 19 [1-27] | 13 [13-18] | 6 [6-7] | 2 [2-2] | 4 [4-4] |
| 3 | 100 | 217 | 35 [28-40] | 169 [103-243] | 15 [1-32] | 12 [11-17] | 6 [5-7] | 1 [1-1] | 4 [3-4] |
| 4 | 100 | 296 | 34 [28-40] | 222 [118-323] | 17 [2-39] | 15 [10-15] | 6 [4-6] | 1 [1-1] | 4 [2-5] |
| 5 | 99 | 416 | 34 [27-35] | 245 [129-380] | 17 [3-38] | 13 [9-18] | 5 [4-6] | 0 [0-1] | 4 [2-5] |
| 6 | 96 | 480 | 30 [27-35] | 292 [174-463] | 24 [5-53] | 12 [7-17] | 4 [4-5] | 0 [0-1] | 3 [2-5] |
| 7 | 95 | 565 | 35 [27-35] | 288 [148-513] | 19 [3-63] | 15 [10-16] | 3 [3-5] | 1 [0-2] | 4 [2-7] |
| 8 | 85 | 652 | 35 [15-40] | 293 [146-537] | 25 [2-59] | 14 [8-19] | 2 [2-4] | 0 [0-1] | 4 [2-8] |
| 9 | 61 | 722 | 35 [17-40] | 308 [161-494] | 30 [3-61] | 16 [11-17] | 1 [1-3] | 1 [0-1] | 4 [2-8] |

## greedy (100 runs)

- results: dead 83 (83.0%), won 17 (17.0%)
- run end causes (hull, crew_<cause>, flooded): hull 54, crew_heat 16, crew_fire 9, crew_combat 4
- killers (share of all runs): pursuer 37 (37.0%), gate 31 (31.0%), gate_pursued 9 (9.0%), drill_crew_heat 3 (3.0%), drill_crew_fire 2 (2.0%), rival_pursued 1 (1.0%)
- rows reached: 6: 11, 7: 14, 8: 8, 9: 67
- death row (non-wins): 6: 11, 7: 14, 8: 8, 9: 50
- run length s: median 587, p10 488, p90 655
- fights per run: 1: 17, 2: 62, 3: 18, 4: 3
- fight results: died 1, fled 2, gate died 40, gate won 17, won 147
- fight length s: rivals median 41, gate median 60
- gate reached 57 times, won 17 (30%)
- pursuer strikes on overtaken nodes: mean 0.59, runs with any 38%
- pursuer strikes while caught: mean 4.91, runs with any 67%
- pursuer catches: mean 0.89, runs with any 69%
- bit breaks: mean 0.01, runs with any 1%
- coolant outs: mean 0.00, runs with any 0%
- crew lost: mean 1.60, runs with any 69%
- fires started: mean 7.55, runs with any 100%
- nodes overtaken: mean 12.22, runs with any 100%
- crew death causes: heat@gate 61, combat@gate 29, heat@drill 28, fire@gate 19, fire@drill 18, event@dialog 3, combat@combat 1, fire@combat 1
- all: gems gained median 111, ore gained median 1196
- winners: gems gained median 133, ore gained median 1301
- losers: gems gained median 99, ore gained median 1141
- store lines bought (store line: count): crust_trader 0: 40, crust_trader 1: 85, crust_trader 10: 76, crust_trader 11: 48, crust_trader 13: 91, crust_trader 14: 47, crust_trader 2: 134, crust_trader 3: 103, crust_trader 4: 5, crust_trader 5: 14, crust_trader 9: 16

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 52 | 30 [30-30] | 91 [54-139] | 15 [15-23] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 120 | 30 [28-30] | 185 [122-271] | 23 [15-31] | 13 [13-13] | 6 [6-7] | 2 [2-2] | 4 [1-4] |
| 3 | 100 | 189 | 30 [28-30] | 256 [115-372] | 29 [13-47] | 12 [11-12] | 6 [5-6] | 1 [1-1] | 4 [1-4] |
| 4 | 100 | 256 | 30 [27-30] | 305 [157-456] | 32 [15-64] | 11 [10-11] | 5 [4-6] | 1 [1-2] | 4 [1-5] |
| 5 | 100 | 325 | 28 [25-30] | 341 [161-496] | 39 [16-62] | 9 [8-10] | 4 [4-5] | 2 [0-2] | 4 [1-5] |
| 6 | 100 | 396 | 27 [15-30] | 443 [241-655] | 54 [31-91] | 8 [7-9] | 3 [3-5] | 1 [0-2] | 3 [1-5] |
| 7 | 89 | 441 | 27 [16-30] | 476 [238-832] | 63 [19-111] | 7 [6-14] | 2 [2-4] | 1 [0-2] | 5 [1-6] |
| 8 | 75 | 495 | 27 [18-29] | 489 [227-912] | 67 [23-119] | 7 [5-12] | 1 [1-4] | 2 [1-2] | 5 [2-6] |
| 9 | 67 | 549 | 26 [19-29] | 461 [182-774] | 67 [37-122] | 9 [4-12] | 1 [0-2] | 2 [1-2] | 5 [3-6] |

## balanced (100 runs)

- results: won 51 (51.0%), dead 49 (49.0%)
- run end causes (hull, crew_<cause>, flooded): hull 20, crew_heat 15, crew_combat 9, crew_fire 5
- killers (share of all runs): gate 36 (36.0%), pursuer 10 (10.0%), gate_pursued 3 (3.0%)
- rows reached: 7: 6, 8: 3, 9: 91
- death row (non-wins): 7: 6, 8: 3, 9: 40
- run length s: median 727, p10 672, p90 773
- fights per run: 1: 1, 2: 70, 3: 28, 4: 1
- fight results: fled 3, gate died 39, gate won 51, won 136
- fight length s: rivals median 42, gate median 61
- gate reached 90 times, won 51 (57%)
- pursuer strikes on overtaken nodes: mean 0.10, runs with any 8%
- pursuer strikes while caught: mean 1.71, runs with any 27%
- pursuer catches: mean 0.41, runs with any 34%
- bit breaks: mean 0.03, runs with any 3%
- coolant outs: mean 0.00, runs with any 0%
- crew lost: mean 1.53, runs with any 61%
- fires started: mean 6.06, runs with any 100%
- nodes overtaken: mean 12.02, runs with any 100%
- crew death causes: heat@gate 80, combat@gate 44, fire@gate 21, heat@drill 6, heat@combat 1, fire@idle 1
- all: gems gained median 101, ore gained median 992
- winners: gems gained median 120, ore gained median 1027
- losers: gems gained median 87, ore gained median 970
- store lines bought (store line: count): crust_trader 0: 128, crust_trader 1: 93, crust_trader 13: 95, crust_trader 14: 1, crust_trader 15: 67, crust_trader 16: 53, crust_trader 2: 83, crust_trader 3: 176, crust_trader 4: 59, crust_trader 5: 5, crust_trader 7: 14, crust_trader 8: 70, crust_trader 9: 14

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 35 [30-35] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 62 | 35 [30-35] | 72 [35-134] | 15 [15-23] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 139 | 35 [29-35] | 169 [79-232] | 21 [7-30] | 13 [12-13] | 6 [6-7] | 2 [2-2] | 4 [3-4] |
| 3 | 100 | 218 | 30 [28-35] | 198 [104-314] | 20 [7-40] | 11 [11-12] | 6 [5-6] | 1 [1-1] | 4 [3-6] |
| 4 | 100 | 291 | 30 [28-35] | 260 [122-405] | 27 [8-55] | 10 [10-15] | 5 [4-6] | 1 [1-1] | 4 [3-6] |
| 5 | 100 | 376 | 29 [27-35] | 291 [136-508] | 34 [11-55] | 13 [8-14] | 4 [4-6] | 1 [0-1] | 5 [2-6] |
| 6 | 100 | 461 | 28 [27-35] | 337 [182-625] | 44 [15-85] | 12 [7-13] | 3 [3-5] | 0 [0-1] | 5 [2-6] |
| 7 | 100 | 520 | 29 [26-35] | 347 [179-656] | 44 [9-89] | 11 [7-15] | 2 [2-4] | 0 [0-1] | 6 [2-8] |
| 8 | 94 | 590 | 30 [27-35] | 366 [154-713] | 50 [13-106] | 10 [9-15] | 1 [1-3] | 0 [0-1] | 7 [2-8] |
| 9 | 91 | 669 | 33 [27-35] | 339 [145-570] | 57 [16-89] | 13 [8-14] | 0 [0-2] | 1 [0-1] | 7 [4-8] |

## Events (all bots)

300 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 55 | 183 |
| byrd_signal | 69 | 230 |
| cold_spring | 48 | 160 |
| gas_pocket | 54 | 180 |
| green_gallery | 69 | 230 |
| knocking_pipe | 48 | 160 |
| kola_tapes | 70 | 233 |
| listening_post | 43 | 143 |
| mohole_core | 33 | 110 |
| rival_claim | 43 | 143 |
| shaft_nine | 38 | 127 |
| zarya_wreck | 50 | 167 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/1 | 42 | grouted: 42 |
| blind_aquifer/intro/2 | 13 | burst: 10, rode: 3 |
| byrd_signal/intro/1 | 69 | mast: 69 |
| cold_spring/intro/1 | 31 | filtered: 31 |
| cold_spring/intro/3 | 17 | drained: 17 |
| gas_pocket/intro/0 | 54 | vented: 54 |
| green_gallery/intro/0 | 50 | amber: 50 |
| green_gallery/intro/1 | 19 | deep: 14, spores: 5 |
| knocking_pipe/intro/0 | 48 | clean: 48 |
| kola_tapes/intro/1 | 70 | strip: 70 |
| listening_post/intro/2 | 43 | decoy: 43 |
| mohole_core/intro/0 | 20 | gas: 3, recovered: 17 |
| mohole_core/intro/2 | 13 | leave: 13 |
| rival_claim/intro/0 | 27 | paid: 27 |
| rival_claim/intro/2 | 16 | fight: 16 |
| shaft_nine/intro/0 | 11 | carts: 11 |
| shaft_nine/intro/1 | 16 | coolant: 14, sludge: 2 |
| shaft_nine/intro/2 | 11 | cable: 3, cage: 8 |
| zarya_wreck/intro/0 | 34 | logs: 34 |
| zarya_wreck/intro/2 | 16 | bits: 13, derrick: 3 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1009 | 10/10 | 0 | 10258 | 47 |
| cautious | 1010..1019 | 10/10 | 0 | 10425 | 43 |
| cautious | 1020..1029 | 10/10 | 0 | 10501 | 47 |
| cautious | 1030..1039 | 10/10 | 0 | 10268 | 46 |
| cautious | 1040..1049 | 10/10 | 0 | 10697 | 43 |
| cautious | 1050..1059 | 10/10 | 0 | 10573 | 45 |
| cautious | 1060..1069 | 10/10 | 0 | 10500 | 46 |
| cautious | 1070..1079 | 10/10 | 0 | 10573 | 47 |
| cautious | 1080..1089 | 10/10 | 0 | 10577 | 46 |
| cautious | 1090..1099 | 10/10 | 0 | 10634 | 45 |
| greedy | 1000..1009 | 10/10 | 0 | 9817 | 35 |
| greedy | 1010..1019 | 10/10 | 0 | 9681 | 35 |
| greedy | 1020..1029 | 10/10 | 0 | 10650 | 35 |
| greedy | 1030..1039 | 10/10 | 0 | 10446 | 36 |
| greedy | 1040..1049 | 10/10 | 0 | 9759 | 37 |
| greedy | 1050..1059 | 10/10 | 0 | 9750 | 37 |
| greedy | 1060..1069 | 10/10 | 0 | 9681 | 36 |
| greedy | 1070..1079 | 10/10 | 0 | 9960 | 37 |
| greedy | 1080..1089 | 10/10 | 0 | 9134 | 38 |
| greedy | 1090..1099 | 10/10 | 0 | 8813 | 40 |
| balanced | 1000..1009 | 10/10 | 0 | 9090 | 49 |
| balanced | 1010..1019 | 10/10 | 0 | 9037 | 51 |
| balanced | 1020..1029 | 10/10 | 0 | 9027 | 50 |
| balanced | 1030..1039 | 10/10 | 0 | 9002 | 49 |
| balanced | 1040..1049 | 10/10 | 0 | 9358 | 48 |
| balanced | 1050..1059 | 10/10 | 0 | 9440 | 48 |
| balanced | 1060..1069 | 10/10 | 0 | 9590 | 46 |
| balanced | 1070..1079 | 10/10 | 0 | 9733 | 46 |
| balanced | 1080..1089 | 10/10 | 0 | 9631 | 45 |
| balanced | 1090..1099 | 10/10 | 0 | 9559 | 47 |
