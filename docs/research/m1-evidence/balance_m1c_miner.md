# Balance: the away miner (M1c round E, D046 to D048)

Command: `python tools/balance.py --full --runs 900 --procs 6 --pack` (300 runs per bot, seeds
1000..1299), then greedy alone again (`--bots greedy --runs 300`) after its miner threshold moved.
Baseline: `balance_m1c_structures.md` (same seeds, before the miner).

| bot | won % before | won % now | median rows | median s | sorties/run | runs with a sortie | miner deaths | haul ore/run | haul gems/run | haul share of ore |
|---|---|---|---|---|---|---|---|---|---|---|
| cautious (front 3 rows behind) | 25.7 | 27.0 | 13 | 1349 | 0.10 | 6% | 0 | 4.0 | 0.3 | 0.3% |
| balanced (2 rows) | 37.7 | 38.3 | 13 | 1384 | 1.20 | 62% | 0 | 29.5 | 2.8 | 1.8% |
| greedy (2 rows, final) | 15.0 | 13.7 | 12 | 1077 | 0.14 | 9% | 0 | 3.2 | 0.2 | 0.2% |
| greedy (1.5 rows, spec start) | 15.0 | 5.3 | 11 | 1076 | 1.49 | 99% | 0 | 30.9 | 1.6 | 1.7% |
| greedy (1.75 rows, tried) | 15.0 | 11.3 | 12 | 1081 | 0.35 | 21% | 0 | 7.8 | 0.5 | 0.4% |

Haul share: miner ore paid over all ore gained, summed over the runs.

Reading:
- Balanced stays at about 38% (the cap is about 45%): no miner tuning was needed. It sends a miner in
  62% of runs, about 1.2 times a run, and brings back about 30 ore and 3 gems; nobody died outside.
- The miner is a modest earner for the bots (under 2% of all ore): a sortie stops the drill for about
  40 to 50 s, so the bots only go when the front is far behind. Players may use it more boldly.
- Greedy at the spec's 1.5 rows went out in 99% of runs and lost runs to the pursuer (35% to 58% of
  runs, wins 15.0% to 5.3%). At 1.75 rows still 11.3%. At 2 rows it is back near its old line
  (13.7%) but rarely sends (greedy keeps the front close). Kept at 2 rows (D048): the miner's
  cost is time, and greedy has none to spare.
- No miner deaths in 900 runs: the bots refuse tunnels through gas or water and with a full rockfall
  of fault rock, and recall below 40 hp or with the front within 1.2 rows.
- Determinism: the state hash covers the miner (test_miner), replays of a sortie match, and every run
  finished (0 stuck).
- Speed: full runs ran at about 8000 to 9000 ticks/s per process, as before. `balance.py --bench`:
  18234 ticks/s, 29.2 us per sim tick (the M1-shaped bench does not drive the miner).

The raw reports follow: the full 900-run batch (greedy at 1.5 rows), then greedy at 2 rows.

# Full-run balance report 20261017-003407

900 runs (300 per bot, seeds 1000..1299), 6 processes, wall 1337 s (22.3 min, 24.8 min per 1000 runs). Pack: 20261017-003400-656a1b7.pck


| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 300 | 27.0 | 0 | 13 | 1349 | 2.94 | 35 | gate 48% |
| greedy | 300 | 5.3 | 0 | 11 | 1076 | 2.44 | 21 | pursuer 58% |
| balanced | 300 | 38.3 | 0 | 13 | 1384 | 3.03 | 46 | gate 40% |

Dig verbs, means per run:

| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.40 | 4.85 | 0.40 | 2.48 | 0.87 | 0.18 | 2.91 | 0 |
| greedy | 5.50 | 6.99 | 5.50 | 12.04 | 139.69 | 19.34 | 2.88 | 92 |
| balanced | 2.99 | 7.57 | 2.99 | 9.51 | 153.11 | 20.33 | 3.34 | 0 |

Buried structures, means per run:

| bot | on the way | entered | crates opened | loot units | traders met | structure events |
|---|---|---|---|---|---|---|
| cautious | 5.83 | 4.05 | 4.93 | 25.27 | 0.38 | 1.53 |
| greedy | 5.50 | 5.17 | 11.08 | 66.84 | 0.40 | 1.95 |
| balanced | 6.15 | 5.23 | 7.93 | 44.38 | 0.53 | 1.95 |

Away miner, means per run (haul share: miner ore over all ore gained, summed over the runs):

| bot | sorties | runs with any % | back | deaths | haul ore | haul gems | lost units | haul share of ore % |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.10 | 6 | 0.10 | 0.00 | 4.0 | 0.3 | 0.0 | 0.3 |
| greedy | 1.49 | 99 | 1.49 | 0.00 | 30.9 | 1.6 | 0.0 | 1.7 |
| balanced | 1.20 | 62 | 1.20 | 0.00 | 29.5 | 2.8 | 0.0 | 1.8 |

## cautious (300 runs)

- results: dead 219 (73.0%), won 81 (27.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 121, crew_combat 40, crew_fire 30, hull 27, rockfall 1
- killers (share of all runs): gate 143 (47.7%), rival 41 (13.7%), pursuer 16 (5.3%), drill_crew_heat 10 (3.3%), gate_pursued 5 (1.7%), drill_crew_combat 2 (0.7%), drill_crew_fire 1 (0.3%), rival_pursued 1 (0.3%)
- rows reached: 7: 12, 8: 7, 9: 8, 10: 16, 11: 15, 12: 13, 13: 229
- death row (non-wins): 7: 12, 8: 7, 9: 8, 10: 16, 11: 15, 12: 13, 13: 148
- run length s: median 1349, p10 1158, p90 1455
- fights per run: 1: 12, 2: 41, 3: 202, 4: 44, 5: 1
- fight results: died 42, fled 8, gate died 148, gate won 81, won 602
- fight length s: rivals median 49, gate median 60
- gate reached 229 times, won 81 (35%)
- pursuer strikes on overtaken nodes: mean 0.02, runs with any 2%
- pursuer strikes while caught: mean 0.65, runs with any 8%
- pursuer catches: mean 0.10, runs with any 9%
- bit breaks: mean 0.13, runs with any 13%
- coolant outs: mean 0.08, runs with any 8%
- crew lost: mean 2.55, runs with any 91%
- fires started: mean 6.42, runs with any 100%
- nodes overtaken: mean 16.42, runs with any 100%
- rockfalls hit: mean 0.40, runs with any 32%
- rockfalls absorbed: mean 4.85, runs with any 98%
- hull lost to rockfalls: mean 0.40, runs with any 32%
- blasts: mean 2.48, runs with any 92%
- ore from blasts: mean 0.87, runs with any 19%
- gems from blasts: mean 0.18, runs with any 6%
- douses: mean 2.91, runs with any 92%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 5.83, runs with any 100%
- structures entered: mean 4.05, runs with any 99%
- crates opened: mean 4.93, runs with any 94%
- loot units from crates: mean 25.27, runs with any 94%
- hollow traders met: mean 0.38, runs with any 32%
- structure events: mean 1.53, runs with any 83%
- miner sorties: mean 0.10, runs with any 6%
- miners back aboard: mean 0.10, runs with any 6%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 3.97, runs with any 5%
- gems from the miner: mean 0.31, runs with any 2%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@gate 350, combat@gate 159, heat@combat 72, combat@combat 59, heat@drill 47, fire@gate 41, fire@combat 28, fire@drill 6, fire@idle 2, heat@idle 2
- all: gems gained median 148, ore gained median 1258
- winners: gems gained median 161, ore gained median 1333
- losers: gems gained median 136, ore gained median 1213
- store lines bought (store line: count): crust_trader 0: 674, crust_trader 1: 333, crust_trader 13: 285, crust_trader 15: 487, crust_trader 16: 260, crust_trader 2: 493, crust_trader 3: 502, crust_trader 4: 468, crust_trader 7: 187, crust_trader 8: 165, crust_trader 9: 51, hollow_trader 0: 56, hollow_trader 1: 57, hollow_trader 2: 64

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 40 [35-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 82 | 40 [30-40] | 61 [24-118] | 15 [15-22] | 14 [14-18] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 300 | 185 | 40 [29-40] | 142 [68-218] | 21 [5-30] | 12 [11-17] | 10 [10-11] | 2 [2-2] | 4 [3-6] |
| 3 | 300 | 295 | 35 [28-40] | 187 [107-291] | 19 [1-39] | 14 [10-16] | 10 [9-11] | 1 [1-2] | 4 [3-6] |
| 4 | 300 | 392 | 35 [28-40] | 232 [129-360] | 19 [2-41] | 13 [8-18] | 10 [8-11] | 1 [1-2] | 4 [3-6] |
| 5 | 300 | 513 | 30 [28-40] | 259 [138-410] | 19 [4-41] | 14 [9-18] | 9 [9-12] | 1 [0-2] | 4 [2-7] |
| 6 | 300 | 616 | 30 [27-40] | 344 [193-522] | 31 [7-62] | 13 [7-18] | 8 [8-11] | 1 [0-2] | 4 [2-6] |
| 7 | 300 | 717 | 30 [26-35] | 365 [159-617] | 34 [7-71] | 14 [6-19] | 7 [7-11] | 1 [0-2] | 4 [2-7] |
| 8 | 288 | 813 | 35 [26-35] | 306 [148-623] | 35 [10-75] | 15 [9-20] | 7 [6-11] | 1 [0-2] | 5 [2-7] |
| 9 | 281 | 910 | 35 [29-35] | 298 [152-582] | 41 [13-80] | 16 [11-20] | 6 [5-10] | 1 [0-2] | 5 [2-7] |
| 10 | 273 | 1009 | 34 [25-35] | 406 [234-742] | 57 [19-108] | 15 [10-20] | 6 [4-10] | 1 [0-2] | 4 [2-7] |
| 11 | 257 | 1105 | 35 [26-40] | 388 [166-799] | 61 [16-114] | 15 [9-22] | 5 [3-11] | 1 [0-2] | 6 [2-9] |
| 12 | 242 | 1203 | 40 [28-40] | 338 [149-750] | 64 [19-120] | 16 [11-23] | 5 [2-10] | 1 [1-2] | 7 [3-9] |
| 13 | 229 | 1297 | 40 [32-40] | 341 [177-553] | 66 [19-128] | 17 [12-23] | 5 [1-10] | 2 [1-2] | 8 [3-9] |

## greedy (300 runs)

- results: dead 284 (94.7%), won 16 (5.3%)
- run end causes (hull, crew_<cause>, flooded): hull 199, crew_heat 40, crew_fire 25, crew_combat 11, flooded 4, rockfall 3, crew_drowned 2
- killers (share of all runs): pursuer 175 (58.3%), gate 38 (12.7%), gate_pursued 24 (8.0%), rival 22 (7.3%), drill_crew_heat 13 (4.3%), rival_pursued 8 (2.7%), drill_crew_combat 2 (0.7%), drill_crew_fire 2 (0.7%)
- rows reached: 5: 2, 6: 10, 7: 13, 8: 27, 9: 38, 10: 43, 11: 48, 12: 41, 13: 78
- death row (non-wins): 5: 2, 6: 10, 7: 13, 8: 27, 9: 38, 10: 43, 11: 48, 12: 41, 13: 62
- run length s: median 1076, p10 856, p90 1219
- fights per run: 0: 2, 1: 30, 2: 132, 3: 108, 4: 27, 5: 1
- fight results: died 30, fled 4, gate died 62, gate won 16, won 619
- fight length s: rivals median 41, gate median 41
- gate reached 78 times, won 16 (21%)
- pursuer strikes on overtaken nodes: mean 0.43, runs with any 40%
- pursuer strikes while caught: mean 5.69, runs with any 83%
- pursuer catches: mean 1.13, runs with any 84%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.04, runs with any 4%
- crew lost: mean 1.37, runs with any 60%
- fires started: mean 8.18, runs with any 100%
- nodes overtaken: mean 16.23, runs with any 100%
- rockfalls hit: mean 5.50, runs with any 99%
- rockfalls absorbed: mean 6.99, runs with any 99%
- hull lost to rockfalls: mean 5.50, runs with any 99%
- blasts: mean 12.04, runs with any 100%
- ore from blasts: mean 139.69, runs with any 97%
- gems from blasts: mean 19.34, runs with any 88%
- douses: mean 2.88, runs with any 90%
- drilling s past 60 degrees: mean 91.88, runs with any 100%
- structures on the way: mean 5.50, runs with any 100%
- structures entered: mean 5.17, runs with any 100%
- crates opened: mean 11.08, runs with any 99%
- loot units from crates: mean 66.84, runs with any 99%
- hollow traders met: mean 0.40, runs with any 32%
- structure events: mean 1.95, runs with any 93%
- miner sorties: mean 1.49, runs with any 99%
- miners back aboard: mean 1.49, runs with any 99%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 30.93, runs with any 91%
- gems from the miner: mean 1.59, runs with any 22%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@drill 172, heat@gate 55, fire@drill 42, combat@combat 32, combat@gate 29, heat@combat 24, fire@combat 23, fire@gate 18, event@dialog 11, drowned@drill 6
- all: gems gained median 206, ore gained median 1840
- winners: gems gained median 300, ore gained median 2208
- losers: gems gained median 202, ore gained median 1794
- store lines bought (store line: count): crust_trader 0: 136, crust_trader 1: 239, crust_trader 10: 276, crust_trader 11: 254, crust_trader 13: 299, crust_trader 14: 244, crust_trader 15: 158, crust_trader 2: 266, crust_trader 3: 694, crust_trader 4: 118, crust_trader 5: 140, crust_trader 9: 260, hollow_trader 0: 20, hollow_trader 1: 24, hollow_trader 2: 103

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 30 [30-35] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 130 | 30 [28-35] | 113 [70-178] | 19 [15-27] | 13 [13-20] | 11 [11-11] | 2 [2-3] | 4 [3-5] |
| 2 | 300 | 244 | 29 [25-35] | 247 [183-333] | 25 [15-34] | 14 [11-20] | 10 [10-11] | 2 [2-4] | 3 [2-5] |
| 3 | 300 | 347 | 28 [23-30] | 320 [140-455] | 31 [11-51] | 13 [9-21] | 9 [9-10] | 2 [1-3] | 3 [1-6] |
| 4 | 300 | 434 | 27 [22-29] | 348 [186-562] | 34 [12-58] | 13 [7-21] | 9 [8-14] | 2 [1-3] | 3 [1-6] |
| 5 | 300 | 533 | 26 [20-29] | 378 [190-558] | 37 [18-67] | 13 [7-22] | 8 [8-14] | 2 [1-3] | 3 [2-6] |
| 6 | 298 | 631 | 24 [18-27] | 514 [324-718] | 60 [27-99] | 12 [5-23] | 8 [7-14] | 2 [1-3] | 3 [0-4] |
| 7 | 288 | 717 | 23 [17-27] | 578 [215-906] | 72 [35-117] | 11 [5-23] | 8 [6-14] | 2 [1-3] | 3 [0-5] |
| 8 | 275 | 790 | 22 [16-26] | 473 [222-950] | 86 [37-137] | 11 [5-25] | 9 [5-15] | 2 [1-3] | 3 [1-5] |
| 9 | 248 | 861 | 21 [14-26] | 464 [222-744] | 87 [41-144] | 12 [7-24] | 10 [4-17] | 2 [1-3] | 3 [2-5] |
| 10 | 210 | 941 | 20 [11-26] | 592 [336-968] | 114 [56-180] | 12 [6-26] | 9 [4-17] | 2 [1-3] | 3 [1-5] |
| 11 | 167 | 1001 | 21 [11-28] | 570 [290-1080] | 123 [57-201] | 13 [6-29] | 10 [4-18] | 2 [1-3] | 3 [1-5] |
| 12 | 119 | 1076 | 22 [8-29] | 671 [359-1020] | 144 [57-214] | 15 [7-31] | 11 [4-18] | 2 [1-3] | 3 [1-5] |
| 13 | 78 | 1146 | 22 [11-29] | 687 [386-1106] | 140 [69-242] | 16 [7-34] | 11 [4-20] | 2 [1-2] | 3 [1-6] |

## balanced (300 runs)

- results: dead 185 (61.7%), won 115 (38.3%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 80, crew_combat 42, hull 40, crew_fire 23
- killers (share of all runs): gate 119 (39.7%), rival 30 (10.0%), gate_pursued 17 (5.7%), pursuer 7 (2.3%), drill_crew_heat 5 (1.7%), drill_crew_fire 5 (1.7%), rival_pursued 2 (0.7%)
- rows reached: 1: 1, 5: 1, 7: 7, 8: 5, 9: 5, 10: 7, 11: 14, 12: 9, 13: 251
- death row (non-wins): 1: 1, 5: 1, 7: 7, 8: 5, 9: 5, 10: 7, 11: 14, 12: 9, 13: 136
- run length s: median 1384, p10 1211, p90 1506
- fights per run: 1: 5, 2: 31, 3: 219, 4: 43, 5: 1, 7: 1
- fight results: died 32, fled 7, gate died 136, gate won 115, won 618
- fight length s: rivals median 49, gate median 62
- gate reached 251 times, won 115 (46%)
- pursuer strikes on overtaken nodes: mean 0.02, runs with any 2%
- pursuer strikes while caught: mean 0.89, runs with any 19%
- pursuer catches: mean 0.24, runs with any 23%
- bit breaks: mean 0.04, runs with any 4%
- coolant outs: mean 0.07, runs with any 7%
- crew lost: mean 2.21, runs with any 82%
- fires started: mean 7.14, runs with any 100%
- nodes overtaken: mean 17.18, runs with any 100%
- rockfalls hit: mean 2.99, runs with any 95%
- rockfalls absorbed: mean 7.57, runs with any 99%
- hull lost to rockfalls: mean 2.99, runs with any 95%
- blasts: mean 9.51, runs with any 100%
- ore from blasts: mean 153.11, runs with any 99%
- gems from blasts: mean 20.33, runs with any 89%
- douses: mean 3.34, runs with any 94%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 6.15, runs with any 100%
- structures entered: mean 5.23, runs with any 100%
- crates opened: mean 7.93, runs with any 98%
- loot units from crates: mean 44.38, runs with any 98%
- hollow traders met: mean 0.53, runs with any 41%
- structure events: mean 1.95, runs with any 90%
- miner sorties: mean 1.20, runs with any 62%
- miners back aboard: mean 1.20, runs with any 62%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 29.47, runs with any 54%
- gems from the miner: mean 2.83, runs with any 22%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@gate 315, combat@gate 158, combat@combat 59, fire@gate 37, heat@combat 36, fire@combat 26, heat@drill 25, heat@idle 4, fire@drill 3
- all: gems gained median 204, ore gained median 1698
- winners: gems gained median 227, ore gained median 1780
- losers: gems gained median 190, ore gained median 1622
- store lines bought (store line: count): crust_trader 0: 435, crust_trader 1: 269, crust_trader 10: 68, crust_trader 13: 292, crust_trader 14: 39, crust_trader 15: 495, crust_trader 16: 268, crust_trader 2: 347, crust_trader 3: 710, crust_trader 4: 440, crust_trader 5: 157, crust_trader 7: 175, crust_trader 8: 287, crust_trader 9: 315, hollow_trader 0: 56, hollow_trader 1: 69, hollow_trader 2: 127

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 40 [35-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 83 | 40 [29-40] | 87 [44-138] | 15 [15-23] | 14 [14-18] | 11 [11-11] | 2 [2-2] | 4 [3-6] |
| 2 | 299 | 190 | 35 [28-40] | 193 [118-272] | 21 [15-30] | 12 [11-16] | 10 [10-11] | 2 [2-3] | 4 [3-7] |
| 3 | 299 | 300 | 29 [27-40] | 242 [123-364] | 25 [9-44] | 11 [9-18] | 10 [9-10] | 1 [1-2] | 5 [3-8] |
| 4 | 299 | 415 | 29 [26-40] | 290 [160-448] | 30 [11-53] | 12 [8-18] | 9 [8-11] | 1 [1-2] | 4 [3-7] |
| 5 | 299 | 529 | 28 [26-35] | 310 [144-481] | 36 [15-63] | 11 [7-19] | 8 [8-12] | 1 [0-2] | 4 [3-7] |
| 6 | 298 | 642 | 28 [25-33] | 408 [229-625] | 52 [23-86] | 11 [6-19] | 7 [7-12] | 1 [0-2] | 3 [2-6] |
| 7 | 298 | 737 | 27 [24-33] | 446 [171-777] | 61 [30-105] | 12 [5-20] | 7 [6-12] | 1 [0-2] | 3 [2-5] |
| 8 | 291 | 834 | 29 [24-33] | 387 [168-788] | 72 [34-123] | 13 [6-20] | 7 [5-12] | 1 [0-1] | 3 [2-5] |
| 9 | 286 | 933 | 31 [26-34] | 328 [174-602] | 74 [38-127] | 13 [8-21] | 7 [4-13] | 1 [0-1] | 3 [3-5] |
| 10 | 281 | 1046 | 31 [23-34] | 466 [282-777] | 90 [49-145] | 12 [7-21] | 7 [3-14] | 0 [0-1] | 3 [2-5] |
| 11 | 274 | 1142 | 31 [22-37] | 461 [199-871] | 96 [42-168] | 13 [7-23] | 7 [2-14] | 0 [0-1] | 3 [2-7] |
| 12 | 260 | 1235 | 34 [24-40] | 402 [199-875] | 99 [42-163] | 14 [9-23] | 7 [2-15] | 1 [0-1] | 4 [3-7] |
| 13 | 251 | 1332 | 37 [30-40] | 381 [179-589] | 96 [44-170] | 14 [9-25] | 6 [1-15] | 1 [0-1] | 4 [2-7] |

## Events (all bots)

900 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 186 | 207 |
| byrd_signal | 254 | 282 |
| cold_spring | 133 | 148 |
| gas_pocket | 157 | 174 |
| green_gallery | 177 | 197 |
| hollow_knocking | 172 | 191 |
| hollow_pool | 189 | 210 |
| knocking_pipe | 168 | 187 |
| kola_tapes | 224 | 249 |
| listening_post | 192 | 213 |
| mine_cage | 552 | 613 |
| mohole_core | 187 | 208 |
| rig_hatch | 340 | 378 |
| rig_teleprinter | 375 | 417 |
| rival_claim | 183 | 203 |
| shaft_nine | 207 | 230 |
| zarya_wreck | 193 | 214 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 82 | braced: 82 |
| blind_aquifer/intro/1 | 77 | grouted: 77 |
| blind_aquifer/intro/2 | 27 | burst: 19, rode: 8 |
| byrd_signal/intro/0 | 1 | answer: 1 |
| byrd_signal/intro/1 | 141 | mast: 141 |
| byrd_signal/intro/2 | 112 | silence: 112 |
| cold_spring/intro/1 | 98 | filtered: 98 |
| cold_spring/intro/3 | 35 | drained: 35 |
| gas_pocket/intro/0 | 157 | vented: 157 |
| green_gallery/intro/0 | 125 | amber: 125 |
| green_gallery/intro/1 | 52 | deep: 42, spores: 10 |
| hollow_knocking/intro/0 | 64 | answer: 41, wall: 23 |
| hollow_knocking/intro/2 | 108 | quiet: 108 |
| hollow_pool/intro/0 | 124 | pump_bad: 24, pumped: 100 |
| hollow_pool/intro/1 | 65 | deep: 21, lamp: 44 |
| knocking_pipe/intro/0 | 167 | clean: 167 |
| knocking_pipe/intro/1 | 1 | bored: 1 |
| kola_tapes/intro/1 | 224 | strip: 224 |
| listening_post/intro/1 | 6 | trace: 6 |
| listening_post/intro/2 | 186 | decoy: 186 |
| mine_cage/intro/0 | 189 | fall: 38, haul: 151 |
| mine_cage/intro/1 | 195 | dropped: 63, winched: 132 |
| mine_cage/intro/2 | 168 | tag: 87, tag_back: 81 |
| mohole_core/intro/0 | 118 | gas: 21, recovered: 97 |
| mohole_core/intro/2 | 69 | leave: 69 |
| rig_hatch/intro/0 | 248 | gas: 69, stores: 179 |
| rig_hatch/intro/2 | 92 | leave: 92 |
| rig_teleprinter/intro/0 | 104 | tape: 104 |
| rig_teleprinter/intro/2 | 271 | salvage: 193, shock: 78 |
| rival_claim/intro/0 | 122 | paid: 122 |
| rival_claim/intro/2 | 61 | fight: 61 |
| shaft_nine/intro/0 | 73 | carts: 73 |
| shaft_nine/intro/1 | 75 | coolant: 61, sludge: 14 |
| shaft_nine/intro/2 | 59 | cable: 10, cage: 49 |
| zarya_wreck/intro/0 | 143 | logs: 143 |
| zarya_wreck/intro/2 | 50 | bits: 34, derrick: 16 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1016 | 17/17 | 0 | 9447 | 141 |
| cautious | 1017..1033 | 17/17 | 0 | 9475 | 144 |
| cautious | 1034..1050 | 17/17 | 0 | 9414 | 139 |
| cautious | 1051..1067 | 17/17 | 0 | 9537 | 146 |
| cautious | 1068..1084 | 17/17 | 0 | 9445 | 143 |
| cautious | 1085..1101 | 17/17 | 0 | 9562 | 144 |
| cautious | 1102..1118 | 17/17 | 0 | 9602 | 140 |
| cautious | 1119..1135 | 17/17 | 0 | 9449 | 146 |
| cautious | 1136..1152 | 17/17 | 0 | 9553 | 144 |
| cautious | 1153..1169 | 17/17 | 0 | 9490 | 144 |
| cautious | 1170..1186 | 17/17 | 0 | 9463 | 145 |
| cautious | 1187..1203 | 17/17 | 0 | 9372 | 146 |
| cautious | 1204..1219 | 16/16 | 0 | 9415 | 135 |
| cautious | 1220..1235 | 16/16 | 0 | 9259 | 137 |
| cautious | 1236..1251 | 16/16 | 0 | 9135 | 141 |
| cautious | 1252..1267 | 16/16 | 0 | 9167 | 136 |
| cautious | 1268..1283 | 16/16 | 0 | 9257 | 141 |
| cautious | 1284..1299 | 16/16 | 0 | 9208 | 134 |
| greedy | 1000..1016 | 17/17 | 0 | 8395 | 132 |
| greedy | 1017..1033 | 17/17 | 0 | 8557 | 124 |
| greedy | 1034..1050 | 17/17 | 0 | 8686 | 129 |
| greedy | 1051..1067 | 17/17 | 0 | 8659 | 122 |
| greedy | 1068..1084 | 17/17 | 0 | 8747 | 123 |
| greedy | 1085..1101 | 17/17 | 0 | 8788 | 122 |
| greedy | 1102..1118 | 17/17 | 0 | 8570 | 130 |
| greedy | 1119..1135 | 17/17 | 0 | 8734 | 129 |
| greedy | 1136..1152 | 17/17 | 0 | 8455 | 124 |
| greedy | 1153..1169 | 17/17 | 0 | 8551 | 127 |
| greedy | 1170..1186 | 17/17 | 0 | 8548 | 121 |
| greedy | 1187..1203 | 17/17 | 0 | 8536 | 130 |
| greedy | 1204..1219 | 16/16 | 0 | 8492 | 120 |
| greedy | 1220..1235 | 16/16 | 0 | 8468 | 119 |
| greedy | 1236..1251 | 16/16 | 0 | 8508 | 118 |
| greedy | 1252..1267 | 16/16 | 0 | 8483 | 124 |
| greedy | 1268..1283 | 16/16 | 0 | 8412 | 119 |
| greedy | 1284..1299 | 16/16 | 0 | 8421 | 123 |
| balanced | 1000..1016 | 17/17 | 0 | 8175 | 171 |
| balanced | 1017..1033 | 17/17 | 0 | 8249 | 168 |
| balanced | 1034..1050 | 17/17 | 0 | 8178 | 174 |
| balanced | 1051..1067 | 17/17 | 0 | 8135 | 175 |
| balanced | 1068..1084 | 17/17 | 0 | 8197 | 171 |
| balanced | 1085..1101 | 17/17 | 0 | 8178 | 172 |
| balanced | 1102..1118 | 17/17 | 0 | 7673 | 184 |
| balanced | 1119..1135 | 17/17 | 0 | 7847 | 179 |
| balanced | 1136..1152 | 17/17 | 0 | 7808 | 180 |
| balanced | 1153..1169 | 17/17 | 0 | 7750 | 182 |
| balanced | 1170..1186 | 17/17 | 0 | 7618 | 185 |
| balanced | 1187..1203 | 17/17 | 0 | 7603 | 185 |
| balanced | 1204..1219 | 16/16 | 0 | 7666 | 172 |
| balanced | 1220..1235 | 16/16 | 0 | 7615 | 174 |
| balanced | 1236..1251 | 16/16 | 0 | 7537 | 162 |
| balanced | 1252..1267 | 16/16 | 0 | 7766 | 170 |
| balanced | 1268..1283 | 16/16 | 0 | 7817 | 169 |
| balanced | 1284..1299 | 16/16 | 0 | 7817 | 174 |
# Full-run balance report 20261017-005705

300 runs (300 per bot, seeds 1000..1299), 6 processes, wall 413 s (6.9 min, 23.0 min per 1000 runs). Pack: 20261017-005659-656a1b7.pck


| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| greedy | 300 | 13.7 | 0 | 12 | 1077 | 2.73 | 29 | pursuer 36% |

Dig verbs, means per run:

| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|
| greedy | 5.70 | 7.52 | 5.70 | 13.04 | 153.20 | 21.16 | 3.28 | 93 |

Buried structures, means per run:

| bot | on the way | entered | crates opened | loot units | traders met | structure events |
|---|---|---|---|---|---|---|
| greedy | 5.87 | 5.56 | 11.74 | 68.80 | 0.44 | 2.13 |

Away miner, means per run (haul share: miner ore over all ore gained, summed over the runs):

| bot | sorties | runs with any % | back | deaths | haul ore | haul gems | lost units | haul share of ore % |
|---|---|---|---|---|---|---|---|---|
| greedy | 0.14 | 9 | 0.14 | 0.00 | 3.2 | 0.2 | 0.0 | 0.2 |

## greedy (300 runs)

- results: dead 259 (86.3%), won 41 (13.7%)
- run end causes (hull, crew_<cause>, flooded): hull 159, crew_heat 52, crew_fire 26, crew_combat 13, flooded 6, rockfall 3
- killers (share of all runs): pursuer 108 (36.0%), gate 68 (22.7%), gate_pursued 33 (11.0%), rival 22 (7.3%), drill_crew_heat 15 (5.0%), rival_pursued 5 (1.7%), drill_crew_fire 5 (1.7%), drill_crew_combat 3 (1.0%)
- rows reached: 5: 1, 6: 3, 7: 9, 8: 17, 9: 29, 10: 40, 11: 31, 12: 28, 13: 142
- death row (non-wins): 5: 1, 6: 3, 7: 9, 8: 17, 9: 29, 10: 40, 11: 31, 12: 28, 13: 101
- run length s: median 1077, p10 856, p90 1181
- fights per run: 0: 3, 1: 20, 2: 87, 3: 140, 4: 47, 5: 2, 6: 1
- fight results: died 27, fled 8, gate died 101, gate won 41, won 641
- fight length s: rivals median 41, gate median 49
- gate reached 142 times, won 41 (29%)
- pursuer strikes on overtaken nodes: mean 0.29, runs with any 27%
- pursuer strikes while caught: mean 4.12, runs with any 69%
- pursuer catches: mean 0.94, runs with any 72%
- bit breaks: mean 0.01, runs with any 1%
- coolant outs: mean 0.05, runs with any 5%
- crew lost: mean 1.67, runs with any 70%
- fires started: mean 8.30, runs with any 100%
- nodes overtaken: mean 16.70, runs with any 100%
- rockfalls hit: mean 5.70, runs with any 98%
- rockfalls absorbed: mean 7.52, runs with any 99%
- hull lost to rockfalls: mean 5.70, runs with any 98%
- blasts: mean 13.04, runs with any 100%
- ore from blasts: mean 153.20, runs with any 99%
- gems from blasts: mean 21.16, runs with any 90%
- douses: mean 3.28, runs with any 92%
- drilling s past 60 degrees: mean 92.54, runs with any 100%
- structures on the way: mean 5.87, runs with any 100%
- structures entered: mean 5.56, runs with any 100%
- crates opened: mean 11.74, runs with any 100%
- loot units from crates: mean 68.80, runs with any 100%
- hollow traders met: mean 0.44, runs with any 36%
- structure events: mean 2.13, runs with any 95%
- miner sorties: mean 0.14, runs with any 9%
- miners back aboard: mean 0.14, runs with any 9%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 3.18, runs with any 9%
- gems from the miner: mean 0.17, runs with any 2%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@drill 155, heat@gate 105, combat@gate 61, combat@combat 44, fire@gate 43, fire@drill 38, heat@combat 23, fire@combat 22, event@dialog 10, drowned@drill 1
- all: gems gained median 234, ore gained median 1970
- winners: gems gained median 306, ore gained median 2242
- losers: gems gained median 220, ore gained median 1901
- store lines bought (store line: count): crust_trader 0: 128, crust_trader 1: 239, crust_trader 10: 284, crust_trader 11: 271, crust_trader 13: 297, crust_trader 14: 259, crust_trader 15: 198, crust_trader 2: 297, crust_trader 3: 760, crust_trader 4: 164, crust_trader 5: 165, crust_trader 9: 311, hollow_trader 0: 21, hollow_trader 1: 23, hollow_trader 2: 112

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 35 [30-35] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 78 | 30 [28-35] | 108 [62-171] | 18 [15-25] | 14 [13-21] | 11 [11-11] | 2 [2-3] | 4 [3-5] |
| 2 | 300 | 184 | 29 [25-35] | 238 [171-322] | 23 [15-33] | 14 [11-20] | 10 [10-11] | 2 [2-4] | 3 [2-5] |
| 3 | 300 | 285 | 28 [23-30] | 310 [148-449] | 29 [10-52] | 14 [9-22] | 9 [9-10] | 2 [1-3] | 3 [1-6] |
| 4 | 300 | 375 | 27 [22-29] | 349 [174-548] | 34 [12-59] | 13 [8-22] | 9 [8-14] | 2 [1-3] | 3 [1-6] |
| 5 | 300 | 470 | 26 [20-29] | 365 [190-553] | 36 [15-65] | 13 [7-23] | 8 [8-14] | 2 [1-3] | 3 [2-6] |
| 6 | 299 | 567 | 24 [19-27] | 503 [317-698] | 59 [25-97] | 12 [5-23] | 8 [7-14] | 2 [1-3] | 3 [0-4] |
| 7 | 296 | 650 | 23 [17-27] | 568 [218-904] | 70 [37-117] | 12 [6-23] | 8 [6-14] | 2 [1-3] | 3 [0-5] |
| 8 | 287 | 729 | 22 [16-26] | 476 [215-944] | 85 [38-136] | 12 [5-24] | 9 [5-15] | 2 [1-3] | 3 [1-5] |
| 9 | 270 | 802 | 21 [15-26] | 449 [219-741] | 87 [40-148] | 12 [7-25] | 10 [4-16] | 2 [1-3] | 3 [2-5] |
| 10 | 241 | 885 | 19 [11-25] | 603 [342-938] | 110 [55-182] | 13 [6-25] | 9 [4-17] | 2 [1-3] | 3 [1-5] |
| 11 | 201 | 955 | 21 [11-27] | 617 [259-1091] | 124 [60-203] | 14 [6-29] | 10 [4-18] | 2 [1-3] | 3 [1-5] |
| 12 | 170 | 1026 | 22 [10-29] | 650 [366-1217] | 139 [66-231] | 15 [7-30] | 11 [5-19] | 2 [1-3] | 3 [2-5] |
| 13 | 142 | 1092 | 26 [12-29] | 717 [433-1095] | 146 [71-246] | 16 [7-31] | 10 [4-21] | 2 [1-3] | 3 [2-6] |

## Events (all bots)

300 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 62 | 207 |
| byrd_signal | 62 | 207 |
| cold_spring | 41 | 137 |
| gas_pocket | 60 | 200 |
| green_gallery | 52 | 173 |
| hollow_knocking | 74 | 247 |
| hollow_pool | 75 | 250 |
| knocking_pipe | 42 | 140 |
| kola_tapes | 65 | 217 |
| listening_post | 61 | 203 |
| mine_cage | 195 | 650 |
| mohole_core | 58 | 193 |
| rig_hatch | 142 | 473 |
| rig_teleprinter | 152 | 507 |
| rival_claim | 53 | 177 |
| shaft_nine | 63 | 210 |
| zarya_wreck | 56 | 187 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 3 | braced: 3 |
| blind_aquifer/intro/1 | 30 | grouted: 30 |
| blind_aquifer/intro/2 | 29 | burst: 19, rode: 10 |
| byrd_signal/intro/0 | 1 | answer: 1 |
| byrd_signal/intro/1 | 61 | mast: 61 |
| cold_spring/intro/3 | 41 | drained: 41 |
| gas_pocket/intro/0 | 60 | vented: 60 |
| green_gallery/intro/1 | 52 | deep: 42, spores: 10 |
| hollow_knocking/intro/0 | 74 | answer: 47, wall: 27 |
| hollow_pool/intro/1 | 75 | deep: 26, lamp: 49 |
| knocking_pipe/intro/0 | 42 | clean: 42 |
| kola_tapes/intro/1 | 65 | strip: 65 |
| listening_post/intro/1 | 5 | trace: 5 |
| listening_post/intro/2 | 56 | decoy: 56 |
| mine_cage/intro/1 | 195 | dropped: 64, winched: 131 |
| mohole_core/intro/0 | 58 | gas: 9, recovered: 49 |
| rig_hatch/intro/0 | 142 | gas: 43, stores: 99 |
| rig_teleprinter/intro/2 | 152 | salvage: 110, shock: 42 |
| rival_claim/intro/2 | 53 | fight: 53 |
| shaft_nine/intro/2 | 63 | cable: 10, cage: 53 |
| zarya_wreck/intro/2 | 56 | bits: 38, derrick: 18 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| greedy | 1000..1016 | 17/17 | 0 | 8014 | 136 |
| greedy | 1017..1033 | 17/17 | 0 | 8059 | 130 |
| greedy | 1034..1050 | 17/17 | 0 | 8107 | 134 |
| greedy | 1051..1067 | 17/17 | 0 | 8074 | 132 |
| greedy | 1068..1084 | 17/17 | 0 | 8089 | 134 |
| greedy | 1085..1101 | 17/17 | 0 | 8104 | 131 |
| greedy | 1102..1118 | 17/17 | 0 | 7759 | 144 |
| greedy | 1119..1135 | 17/17 | 0 | 8004 | 137 |
| greedy | 1136..1152 | 17/17 | 0 | 7833 | 135 |
| greedy | 1153..1169 | 17/17 | 0 | 7843 | 136 |
| greedy | 1170..1186 | 17/17 | 0 | 7941 | 134 |
| greedy | 1187..1203 | 17/17 | 0 | 7674 | 141 |
| greedy | 1204..1219 | 16/16 | 0 | 7551 | 132 |
| greedy | 1220..1235 | 16/16 | 0 | 7523 | 130 |
| greedy | 1236..1251 | 16/16 | 0 | 7528 | 133 |
| greedy | 1252..1267 | 16/16 | 0 | 7525 | 135 |
| greedy | 1268..1283 | 16/16 | 0 | 7604 | 135 |
| greedy | 1284..1299 | 16/16 | 0 | 7628 | 136 |
