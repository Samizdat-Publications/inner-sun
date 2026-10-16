# Balance after the M1c dig verbs (300 runs per bot, 4 passes at 300)

`python tools/balance.py --full --runs 900 --procs 6 --pack`, seeds 1000..1299, every bot on the
same maps. Baseline D033 (before the verbs): cautious 10%, greedy 12%, balanced 23% wins; medians
17 to 21 min.

## Final (pass 4)

| bot | won % | median min | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|---|---|
| cautious | 26.0 | 22.4 | 0.28 | 3.96 | 0.28 | 1.84 | 1.7 | 0.2 | 3.21 | 0 |
| greedy | 12.0 | 18.2 | 4.37 | 6.81 | 4.37 | 8.09 | 252 | 32.8 | 2.87 | 94 |
| balanced | 40.3 | 22.4 | 2.44 | 6.18 | 2.44 | 6.75 | 231 | 29.6 | 3.54 | 0 |

(means per run)

- Medians 18 to 22 min: in the 16 to 24 band. Cautious and greedy are in the 10 to 30% band;
  balanced is above it (40%). Its gain comes from the blast economy (about 230 ore and 30 gems a
  run on top of the drilled yield) turning into store upgrades and a 51% gate win rate (was the
  main killer before). Not tuned further here: the remaining levers (gate difficulty, store prices,
  blast yields) are outside this round or are product calls for the lead.
- Rockfalls are a real cost: greedy (braces only in fault rock, after drill and helm) loses 4.4
  hull a run, balanced 2.4, cautious (always braced) 0.3; cautious soaks about 4 a run.
- Blasts pay for themselves: a blast costs one charge (4 gems at the store) and returns about 31
  ore (9 gems at the bots' 0.3 rate) plus 4 gems for greedy.
- Greedy is the loud one: drill 4 bars, 8 blasts and the most fault rock; the pursuer is its top
  killer (28%), as before (D033: 11% pursuer, more gate).
- Douse: about 3 a run for every policy; heat and fire deaths stay 5 to 15%.

## Pass history (300 per bot unless noted)

| pass | change | cautious | greedy | balanced |
|---|---|---|---|---|
| 0 (30 per bot) | spec numbers (blast noise 15, strain 80) | 33 | 0 | 0 (pursuer 30 to 73%) |
| a (50 per bot) | blast noise 6, steer caps 70 / 60 | 30 | 2 | 8 |
| b (50 per bot) | blast keep 4 / 3, store charges 7 / 6 | 30 | 6 | 38 |
| c (50 per bot) | strain 50 cells, faults 1 to 3 lenses | 30 | 4 | 48 |
| d (50 per bot) | blast noise 4, balanced charges 6, greedy min value 40 | 26 | 14 | 34 |
| 1 | greedy steer cap 80 | 28.3 | 13.7 | 41.3 |
| 2 | loot blast min value 50 (balanced), douse fire 0.45 | 28.0 | 13.7 | 48.7 |
| 3 | balanced store charges back to 5 | 28.0 | 13.7 | 41.7 |
| 4 (final) | douse 0.3 fire, 150 kJ, 6 s cooldown | 26.0 | 12.0 | 40.3 |

The full report of the final pass follows.

# Full-run balance report 20261016-185902

900 runs (300 per bot, seeds 1000..1299), 6 processes, wall 1609 s (26.8 min, 29.8 min per 1000 runs). Pack: 20261016-185851-53e1e43.pck


| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 300 | 26.0 | 0 | 13 | 1342 | 2.81 | 37 | gate 43% |
| greedy | 300 | 12.0 | 0 | 12 | 1092 | 2.76 | 26 | pursuer 28% |
| balanced | 300 | 40.3 | 0 | 13 | 1342 | 2.94 | 51 | gate 34% |

Dig verbs, means per run:

| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.28 | 3.96 | 0.28 | 1.84 | 1.67 | 0.17 | 3.21 | 0 |
| greedy | 4.37 | 6.81 | 4.37 | 8.09 | 252.48 | 32.75 | 2.87 | 94 |
| balanced | 2.44 | 6.18 | 2.44 | 6.75 | 231.26 | 29.62 | 3.54 | 0 |

## cautious (300 runs)

- results: dead 222 (74.0%), won 78 (26.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 113, crew_combat 57, crew_fire 26, hull 26
- killers (share of all runs): gate 129 (43.0%), rival 44 (14.7%), pursuer 21 (7.0%), drill_crew_heat 18 (6.0%), drill_crew_fire 5 (1.7%), drill_crew_combat 3 (1.0%), gate_pursued 2 (0.7%)
- rows reached: 5: 1, 6: 1, 7: 15, 8: 12, 9: 15, 10: 21, 11: 15, 12: 11, 13: 209
- death row (non-wins): 5: 1, 6: 1, 7: 15, 8: 12, 9: 15, 10: 21, 11: 15, 12: 11, 13: 131
- run length s: median 1342, p10 1028, p90 1460
- fights per run: 1: 24, 2: 52, 3: 186, 4: 35, 5: 2, 6: 1
- fight results: died 44, fled 13, gate died 131, gate won 78, won 576
- fight length s: rivals median 57, gate median 62
- gate reached 209 times, won 78 (37%)
- pursuer strikes on overtaken nodes: mean 0.03, runs with any 3%
- pursuer strikes while caught: mean 0.81, runs with any 9%
- pursuer catches: mean 0.11, runs with any 11%
- bit breaks: mean 0.17, runs with any 17%
- coolant outs: mean 0.15, runs with any 15%
- crew lost: mean 2.64, runs with any 91%
- fires started: mean 6.88, runs with any 100%
- nodes overtaken: mean 16.04, runs with any 100%
- rockfalls hit: mean 0.28, runs with any 25%
- rockfalls absorbed: mean 3.96, runs with any 96%
- hull lost to rockfalls: mean 0.28, runs with any 25%
- blasts: mean 1.84, runs with any 87%
- ore from blasts: mean 1.67, runs with any 18%
- gems from blasts: mean 0.17, runs with any 4%
- douses: mean 3.21, runs with any 92%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- crew death causes: heat@gate 324, combat@gate 137, combat@combat 85, heat@drill 77, heat@combat 77, fire@gate 39, fire@combat 34, heat@idle 10, fire@drill 7, fire@idle 1
- all: gems gained median 132, ore gained median 1266
- winners: gems gained median 167, ore gained median 1396
- losers: gems gained median 116, ore gained median 1208
- store lines bought (store line: count): crust_trader 0: 808, crust_trader 1: 345, crust_trader 13: 276, crust_trader 15: 455, crust_trader 16: 255, crust_trader 2: 523, crust_trader 3: 468, crust_trader 4: 428, crust_trader 7: 178, crust_trader 8: 173, crust_trader 9: 50

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 40 [30-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 82 | 40 [30-40] | 61 [23-115] | 15 [15-23] | 14 [14-14] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 300 | 186 | 40 [29-40] | 140 [66-215] | 21 [5-30] | 12 [11-17] | 10 [10-11] | 2 [2-2] | 4 [3-4] |
| 3 | 300 | 295 | 35 [28-40] | 184 [108-280] | 20 [1-41] | 11 [9-15] | 10 [9-11] | 1 [1-1] | 3 [2-4] |
| 4 | 300 | 393 | 35 [28-40] | 232 [131-356] | 19 [4-42] | 13 [8-18] | 10 [8-10] | 1 [1-1] | 3 [2-4] |
| 5 | 300 | 512 | 30 [28-40] | 253 [130-413] | 19 [4-44] | 12 [7-17] | 9 [8-10] | 1 [0-2] | 3 [2-5] |
| 6 | 299 | 620 | 30 [27-40] | 338 [201-515] | 29 [7-62] | 10 [5-15] | 8 [7-9] | 0 [0-1] | 3 [2-5] |
| 7 | 298 | 720 | 30 [26-35] | 362 [154-620] | 32 [7-74] | 12 [3-18] | 7 [7-9] | 0 [0-2] | 3 [2-6] |
| 8 | 283 | 814 | 35 [26-35] | 306 [156-598] | 34 [6-75] | 14 [6-17] | 6 [6-8] | 1 [0-2] | 3 [2-6] |
| 9 | 271 | 910 | 35 [30-35] | 317 [155-578] | 37 [7-74] | 14 [10-17] | 5 [5-7] | 1 [0-2] | 4 [2-7] |
| 10 | 256 | 1011 | 34 [25-35] | 420 [241-734] | 50 [14-93] | 12 [8-16] | 4 [4-6] | 1 [0-2] | 3 [2-6] |
| 11 | 235 | 1111 | 35 [26-40] | 421 [186-798] | 55 [11-99] | 13 [7-18] | 3 [3-5] | 1 [0-2] | 4 [2-8] |
| 12 | 220 | 1208 | 38 [27-40] | 356 [161-775] | 55 [15-97] | 14 [7-17] | 3 [2-4] | 1 [0-2] | 6 [2-9] |
| 13 | 209 | 1302 | 40 [32-40] | 356 [168-565] | 48 [10-99] | 15 [10-18] | 2 [1-4] | 1 [1-2] | 7 [3-9] |

## greedy (300 runs)

- results: dead 264 (88.0%), won 36 (12.0%)
- run end causes (hull, crew_<cause>, flooded): hull 131, crew_heat 80, crew_fire 37, crew_combat 16
- killers (share of all runs): pursuer 83 (27.7%), gate 74 (24.7%), drill_crew_heat 37 (12.3%), gate_pursued 29 (9.7%), rival 22 (7.3%), drill_crew_fire 10 (3.3%), rival_pursued 7 (2.3%), drill_crew_combat 2 (0.7%)
- rows reached: 5: 1, 6: 4, 7: 14, 8: 17, 9: 20, 10: 38, 11: 34, 12: 33, 13: 139
- death row (non-wins): 5: 1, 6: 4, 7: 14, 8: 17, 9: 20, 10: 38, 11: 34, 12: 33, 13: 103
- run length s: median 1092, p10 862, p90 1182
- fights per run: 1: 12, 2: 93, 3: 153, 4: 38, 5: 4
- fight results: died 29, fled 10, gate died 103, gate won 36, won 651
- fight length s: rivals median 41, gate median 55
- gate reached 139 times, won 36 (26%)
- pursuer strikes on overtaken nodes: mean 0.22, runs with any 19%
- pursuer strikes while caught: mean 3.29, runs with any 56%
- pursuer catches: mean 0.74, runs with any 61%
- bit breaks: mean 0.01, runs with any 1%
- coolant outs: mean 0.30, runs with any 30%
- crew lost: mean 2.06, runs with any 81%
- fires started: mean 8.12, runs with any 100%
- nodes overtaken: mean 16.47, runs with any 100%
- rockfalls hit: mean 4.37, runs with any 97%
- rockfalls absorbed: mean 6.81, runs with any 100%
- hull lost to rockfalls: mean 4.37, runs with any 97%
- blasts: mean 8.09, runs with any 99%
- ore from blasts: mean 252.48, runs with any 98%
- gems from blasts: mean 32.75, runs with any 85%
- douses: mean 2.87, runs with any 93%
- drilling s past 60 degrees: mean 94.08, runs with any 100%
- crew death causes: heat@drill 231, heat@gate 129, combat@gate 78, combat@combat 47, fire@gate 37, fire@combat 30, heat@combat 27, fire@drill 20, event@dialog 17, heat@idle 1
- all: gems gained median 208, ore gained median 2138
- winners: gems gained median 260, ore gained median 2464
- losers: gems gained median 204, ore gained median 2082
- store lines bought (store line: count): crust_trader 0: 509, crust_trader 1: 254, crust_trader 10: 277, crust_trader 11: 258, crust_trader 13: 296, crust_trader 14: 259, crust_trader 15: 237, crust_trader 2: 558, crust_trader 3: 755, crust_trader 4: 103, crust_trader 5: 131, crust_trader 9: 327

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 35 [30-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 78 | 35 [29-40] | 102 [61-161] | 19 [15-26] | 14 [13-14] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 300 | 184 | 30 [27-35] | 234 [169-315] | 24 [15-35] | 12 [10-12] | 10 [10-11] | 2 [2-2] | 3 [1-4] |
| 3 | 300 | 282 | 29 [27-35] | 304 [145-449] | 33 [13-53] | 10 [8-11] | 9 [9-10] | 1 [1-1] | 3 [1-6] |
| 4 | 300 | 370 | 28 [25-35] | 366 [209-569] | 36 [13-65] | 8 [6-9] | 9 [8-10] | 1 [1-2] | 3 [1-5] |
| 5 | 300 | 467 | 27 [24-30] | 410 [216-599] | 38 [15-71] | 7 [5-9] | 8 [8-9] | 2 [1-2] | 3 [1-5] |
| 6 | 299 | 566 | 26 [22-29] | 528 [348-764] | 61 [23-99] | 5 [3-8] | 7 [7-9] | 1 [1-2] | 3 [0-3] |
| 7 | 295 | 650 | 25 [21-29] | 607 [250-968] | 71 [28-113] | 4 [1-9] | 6 [6-8] | 1 [0-2] | 3 [0-4] |
| 8 | 281 | 725 | 24 [19-28] | 507 [276-959] | 75 [32-129] | 6 [1-10] | 5 [5-7] | 2 [1-2] | 3 [1-4] |
| 9 | 264 | 796 | 24 [18-29] | 538 [291-848] | 80 [37-137] | 7 [3-10] | 4 [4-6] | 2 [1-2] | 3 [1-4] |
| 10 | 244 | 883 | 23 [16-28] | 698 [428-1039] | 100 [48-167] | 6 [2-9] | 4 [3-6] | 2 [1-2] | 3 [0-3] |
| 11 | 206 | 952 | 24 [14-30] | 719 [399-1209] | 96 [41-171] | 6 [2-11] | 3 [2-5] | 2 [1-2] | 3 [1-5] |
| 12 | 172 | 1026 | 24 [12-31] | 780 [445-1272] | 104 [52-183] | 7 [2-10] | 2 [1-4] | 2 [1-2] | 3 [1-4] |
| 13 | 139 | 1096 | 28 [15-33] | 907 [562-1328] | 104 [51-179] | 7 [3-10] | 1 [0-3] | 2 [1-2] | 3 [1-6] |

## balanced (300 runs)

- results: dead 179 (59.7%), won 121 (40.3%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 90, crew_combat 37, hull 30, crew_fire 22
- killers (share of all runs): gate 103 (34.3%), rival 33 (11.0%), drill_crew_heat 16 (5.3%), gate_pursued 12 (4.0%), pursuer 9 (3.0%), drill_crew_fire 5 (1.7%), drill_crew_combat 1 (0.3%)
- rows reached: 5: 2, 7: 14, 8: 4, 9: 6, 10: 9, 11: 17, 12: 12, 13: 236
- death row (non-wins): 5: 2, 7: 14, 8: 4, 9: 6, 10: 9, 11: 17, 12: 12, 13: 115
- run length s: median 1342, p10 1117, p90 1443
- fights per run: 1: 11, 2: 43, 3: 199, 4: 46, 5: 1
- fight results: died 33, fled 6, gate died 115, gate won 121, won 608
- fight length s: rivals median 57, gate median 64
- gate reached 236 times, won 121 (51%)
- pursuer strikes on overtaken nodes: mean 0.01, runs with any 1%
- pursuer strikes while caught: mean 0.50, runs with any 11%
- pursuer catches: mean 0.14, runs with any 14%
- bit breaks: mean 0.09, runs with any 9%
- coolant outs: mean 0.14, runs with any 14%
- crew lost: mean 2.13, runs with any 80%
- fires started: mean 7.50, runs with any 100%
- nodes overtaken: mean 16.68, runs with any 100%
- rockfalls hit: mean 2.44, runs with any 91%
- rockfalls absorbed: mean 6.18, runs with any 99%
- hull lost to rockfalls: mean 2.44, runs with any 91%
- blasts: mean 6.75, runs with any 99%
- ore from blasts: mean 231.26, runs with any 97%
- gems from blasts: mean 29.62, runs with any 77%
- douses: mean 3.54, runs with any 95%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- crew death causes: heat@gate 270, combat@gate 140, heat@drill 64, heat@combat 49, combat@combat 47, fire@gate 29, fire@combat 26, heat@idle 7, fire@drill 6
- all: gems gained median 188, ore gained median 1819
- winners: gems gained median 206, ore gained median 1921
- losers: gems gained median 161, ore gained median 1734
- store lines bought (store line: count): crust_trader 0: 761, crust_trader 1: 272, crust_trader 10: 80, crust_trader 13: 288, crust_trader 14: 52, crust_trader 15: 470, crust_trader 16: 268, crust_trader 2: 495, crust_trader 3: 827, crust_trader 4: 404, crust_trader 5: 90, crust_trader 7: 174, crust_trader 8: 278, crust_trader 9: 320

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 40 [35-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 83 | 40 [29-40] | 80 [43-134] | 15 [15-23] | 14 [13-14] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 300 | 189 | 35 [28-40] | 188 [116-257] | 21 [15-31] | 12 [11-12] | 10 [10-11] | 2 [2-2] | 4 [3-4] |
| 3 | 300 | 299 | 29 [27-40] | 234 [116-359] | 26 [8-45] | 10 [9-11] | 10 [9-10] | 1 [1-1] | 3 [2-6] |
| 4 | 300 | 398 | 29 [27-40] | 286 [168-443] | 30 [9-53] | 9 [7-14] | 9 [8-9] | 1 [1-1] | 3 [2-5] |
| 5 | 300 | 506 | 29 [26-40] | 312 [161-480] | 33 [12-62] | 11 [6-12] | 8 [8-9] | 1 [0-1] | 3 [3-5] |
| 6 | 298 | 614 | 28 [25-35] | 423 [239-620] | 48 [20-88] | 9 [4-12] | 7 [7-9] | 0 [0-1] | 3 [2-4] |
| 7 | 298 | 705 | 27 [25-34] | 468 [199-784] | 57 [26-108] | 9 [2-13] | 6 [6-8] | 0 [0-1] | 3 [2-4] |
| 8 | 284 | 796 | 28 [25-34] | 394 [181-750] | 65 [24-118] | 11 [5-14] | 5 [5-7] | 1 [0-1] | 3 [2-4] |
| 9 | 280 | 890 | 32 [26-35] | 394 [182-670] | 69 [29-113] | 11 [7-14] | 4 [4-6] | 1 [0-1] | 3 [2-4] |
| 10 | 274 | 999 | 31 [23-34] | 520 [311-828] | 80 [38-135] | 9 [5-13] | 3 [3-5] | 0 [0-1] | 3 [2-4] |
| 11 | 265 | 1097 | 32 [23-37] | 493 [222-946] | 78 [35-144] | 10 [3-14] | 3 [2-5] | 0 [0-1] | 3 [2-7] |
| 12 | 248 | 1197 | 35 [25-40] | 440 [228-868] | 82 [37-138] | 11 [5-14] | 2 [1-4] | 1 [0-1] | 3 [2-6] |
| 13 | 236 | 1289 | 37 [29-40] | 460 [241-706] | 83 [35-140] | 11 [7-14] | 1 [0-3] | 1 [0-1] | 3 [2-6] |

## Events (all bots)

900 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 181 | 201 |
| byrd_signal | 273 | 303 |
| cold_spring | 142 | 158 |
| gas_pocket | 165 | 183 |
| green_gallery | 180 | 200 |
| knocking_pipe | 197 | 219 |
| kola_tapes | 228 | 253 |
| listening_post | 162 | 180 |
| mohole_core | 185 | 206 |
| rival_claim | 185 | 206 |
| shaft_nine | 210 | 233 |
| zarya_wreck | 193 | 214 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 81 | braced: 81 |
| blind_aquifer/intro/1 | 63 | grouted: 63 |
| blind_aquifer/intro/2 | 37 | burst: 23, rode: 14 |
| byrd_signal/intro/0 | 2 | answer: 2 |
| byrd_signal/intro/1 | 165 | mast: 165 |
| byrd_signal/intro/2 | 106 | silence: 106 |
| cold_spring/intro/1 | 98 | filtered: 98 |
| cold_spring/intro/3 | 44 | drained: 44 |
| gas_pocket/intro/0 | 165 | vented: 165 |
| green_gallery/intro/0 | 128 | amber: 128 |
| green_gallery/intro/1 | 52 | deep: 42, spores: 10 |
| knocking_pipe/intro/0 | 197 | clean: 197 |
| kola_tapes/intro/1 | 228 | strip: 228 |
| listening_post/intro/1 | 6 | trace: 6 |
| listening_post/intro/2 | 156 | decoy: 156 |
| mohole_core/intro/0 | 119 | gas: 20, recovered: 99 |
| mohole_core/intro/2 | 66 | leave: 66 |
| rival_claim/intro/0 | 117 | paid: 117 |
| rival_claim/intro/2 | 68 | fight: 68 |
| shaft_nine/intro/0 | 67 | carts: 67 |
| shaft_nine/intro/1 | 75 | coolant: 58, sludge: 17 |
| shaft_nine/intro/2 | 68 | cable: 17, cage: 51 |
| zarya_wreck/intro/0 | 142 | logs: 142 |
| zarya_wreck/intro/2 | 51 | bits: 34, derrick: 17 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1016 | 17/17 | 0 | 4721 | 285 |
| cautious | 1017..1033 | 17/17 | 0 | 4754 | 279 |
| cautious | 1034..1050 | 17/17 | 0 | 4818 | 278 |
| cautious | 1051..1067 | 17/17 | 0 | 4793 | 284 |
| cautious | 1068..1084 | 17/17 | 0 | 4897 | 267 |
| cautious | 1085..1101 | 17/17 | 0 | 4733 | 284 |
| cautious | 1102..1118 | 17/17 | 0 | 4791 | 276 |
| cautious | 1119..1135 | 17/17 | 0 | 4786 | 289 |
| cautious | 1136..1152 | 17/17 | 0 | 4815 | 272 |
| cautious | 1153..1169 | 17/17 | 0 | 4832 | 281 |
| cautious | 1170..1186 | 17/17 | 0 | 4828 | 281 |
| cautious | 1187..1203 | 17/17 | 0 | 4822 | 287 |
| cautious | 1204..1219 | 16/16 | 0 | 7225 | 174 |
| cautious | 1220..1235 | 16/16 | 0 | 7378 | 170 |
| cautious | 1236..1251 | 16/16 | 0 | 7585 | 161 |
| cautious | 1252..1267 | 16/16 | 0 | 7529 | 174 |
| cautious | 1268..1283 | 16/16 | 0 | 7586 | 168 |
| cautious | 1284..1299 | 16/16 | 0 | 7591 | 164 |
| greedy | 1000..1016 | 17/17 | 0 | 7366 | 147 |
| greedy | 1017..1033 | 17/17 | 0 | 7522 | 139 |
| greedy | 1034..1050 | 17/17 | 0 | 7190 | 151 |
| greedy | 1051..1067 | 17/17 | 0 | 7354 | 150 |
| greedy | 1068..1084 | 17/17 | 0 | 7287 | 149 |
| greedy | 1085..1101 | 17/17 | 0 | 7196 | 153 |
| greedy | 1102..1118 | 17/17 | 0 | 7677 | 140 |
| greedy | 1119..1135 | 17/17 | 0 | 7715 | 146 |
| greedy | 1136..1152 | 17/17 | 0 | 7823 | 138 |
| greedy | 1153..1169 | 17/17 | 0 | 7863 | 145 |
| greedy | 1170..1186 | 17/17 | 0 | 7950 | 134 |
| greedy | 1187..1203 | 17/17 | 0 | 8001 | 139 |
| greedy | 1204..1219 | 16/16 | 0 | 9522 | 105 |
| greedy | 1220..1235 | 16/16 | 0 | 9312 | 114 |
| greedy | 1236..1251 | 16/16 | 0 | 9597 | 101 |
| greedy | 1252..1267 | 16/16 | 0 | 9592 | 103 |
| greedy | 1268..1283 | 16/16 | 0 | 9606 | 104 |
| greedy | 1284..1299 | 16/16 | 0 | 9278 | 112 |
| balanced | 1000..1016 | 17/17 | 0 | 8415 | 163 |
| balanced | 1017..1033 | 17/17 | 0 | 8495 | 161 |
| balanced | 1034..1050 | 17/17 | 0 | 8339 | 158 |
| balanced | 1051..1067 | 17/17 | 0 | 8444 | 160 |
| balanced | 1068..1084 | 17/17 | 0 | 8584 | 159 |
| balanced | 1085..1101 | 17/17 | 0 | 8499 | 159 |
| balanced | 1102..1118 | 17/17 | 0 | 8321 | 159 |
| balanced | 1119..1135 | 17/17 | 0 | 8259 | 164 |
| balanced | 1136..1152 | 17/17 | 0 | 8244 | 157 |
| balanced | 1153..1169 | 17/17 | 0 | 8136 | 169 |
| balanced | 1170..1186 | 17/17 | 0 | 8222 | 169 |
| balanced | 1187..1203 | 17/17 | 0 | 8335 | 166 |
| balanced | 1204..1219 | 16/16 | 0 | 8910 | 143 |
| balanced | 1220..1235 | 16/16 | 0 | 9033 | 134 |
| balanced | 1236..1251 | 16/16 | 0 | 9104 | 138 |
| balanced | 1252..1267 | 16/16 | 0 | 9079 | 139 |
| balanced | 1268..1283 | 16/16 | 0 | 9224 | 139 |
| balanced | 1284..1299 | 16/16 | 0 | 9209 | 140 |
