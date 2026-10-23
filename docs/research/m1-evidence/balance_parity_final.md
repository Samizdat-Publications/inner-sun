# Full-run balance report 20261023-004510

Parity branch after rounds 1 to 6a and main's build 6 triage (commit bc43e48), 2026-10-23. Before parity (balance_m1c_miner.md) the balanced bot won 38%; after round 4 alone 52%; with environments and main's richer ore (D060) 58%.

900 runs (300 per bot, seeds 1000..1299), 6 processes, wall 1333 s (22.2 min, 24.7 min per 1000 runs). Pack: 20261023-004504-bc43e48.pck


| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 300 | 48.3 | 0 | 13 | 1376 | 2.86 | 67 | gate 21% |
| greedy | 300 | 19.0 | 0 | 11 | 1070 | 2.49 | 55 | pursuer 53% |
| balanced | 300 | 58.0 | 0 | 13 | 1380 | 2.91 | 86 | pursuer 22% |

Economy measures (L-UPG-03 spend_share: upgrade ore over all ore spent in stores, band 40 to 65%, median bars 5 to 10; L-RWD-05 income_share: fight plus event value over all value gained, value = ore + 6 x gems, band 15 to 35%; the bands apply to the balanced bot):

| bot | spend_share % | band | median bars | band | income_share % | band | ore spent by kind (per run) | value gained by source (per run) |
|---|---|---|---|---|---|---|---|---|
| cautious | 59.8 | in | 7 | in | 21.9 | in | upgrade 572, gear 364, res 0, hull 21, weapon 0, crew 0 | fight 616, event 76, sale 0, dig 2473 |
| greedy | 61.4 | in | 8 | in | 14.0 | OUT | upgrade 568, gear 348, res 0, hull 10, weapon 0, crew 0 | fight 400, event 137, sale 0, dig 3288 |
| balanced | 64.0 | in | 9 | in | 21.5 | in | upgrade 793, gear 424, res 0, hull 23, weapon 0, crew 0 | fight 709, event 133, sale 0, dig 3080 |

Dig verbs, means per run:

| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|
| cautious | 1.22 | 6.92 | 1.22 | 2.57 | 1.40 | 0.15 | 2.52 | 0 |
| greedy | 5.56 | 8.41 | 5.56 | 9.40 | 65.84 | 10.46 | 2.74 | 0 |
| balanced | 3.79 | 8.60 | 3.79 | 4.20 | 24.12 | 5.09 | 2.04 | 0 |

Buried structures, means per run:

| bot | on the way | entered | crates opened | loot units | traders met | structure events |
|---|---|---|---|---|---|---|
| cautious | 5.81 | 4.15 | 5.02 | 25.53 | 0.36 | 1.59 |
| greedy | 5.70 | 5.36 | 11.40 | 67.16 | 0.42 | 2.06 |
| balanced | 5.86 | 4.89 | 7.53 | 42.03 | 0.46 | 1.84 |

Away miner, means per run (haul share: miner ore over all ore gained, summed over the runs):

| bot | sorties | runs with any % | back | deaths | haul ore | haul gems | lost units | haul share of ore % |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.07 | 4 | 0.07 | 0.00 | 2.1 | 0.3 | 0.0 | 0.1 |
| greedy | 0.15 | 8 | 0.15 | 0.00 | 4.2 | 0.2 | 0.0 | 0.2 |
| balanced | 1.18 | 52 | 1.18 | 0.00 | 35.5 | 2.5 | 0.0 | 1.6 |

## cautious (300 runs)

- results: dead 155 (51.7%), won 145 (48.3%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 64, hull 40, crew_combat 26, crew_fire 25
- killers (share of all runs): gate 64 (21.3%), pursuer 36 (12.0%), rival 32 (10.7%), drill_crew_heat 9 (3.0%), gate_pursued 6 (2.0%), drill_crew_combat 5 (1.7%), drill_crew_fire 3 (1.0%)
- rows reached: 5: 1, 6: 1, 7: 7, 8: 12, 9: 10, 10: 22, 11: 14, 12: 18, 13: 215
- death row (non-wins): 5: 1, 6: 1, 7: 7, 8: 12, 9: 10, 10: 22, 11: 14, 12: 18, 13: 70
- run length s: median 1376, p10 1134, p90 1531
- fights per run: 0: 1, 1: 17, 2: 46, 3: 198, 4: 34, 5: 4
- fight results: died 32, fled 15, gate died 70, gate won 145, won 597
- fight length s: rivals median 49, gate median 58
- gate reached 215 times, won 145 (67%)
- pursuer strikes on overtaken nodes: mean 0.07, runs with any 6%
- pursuer strikes while caught: mean 1.85, runs with any 20%
- pursuer catches: mean 0.25, runs with any 23%
- bit breaks: mean 0.14, runs with any 14%
- coolant outs: mean 0.04, runs with any 4%
- crew lost: mean 1.58, runs with any 59%
- fires started: mean 5.61, runs with any 99%
- nodes overtaken: mean 16.61, runs with any 100%
- rockfalls hit: mean 1.22, runs with any 37%
- rockfalls absorbed: mean 6.92, runs with any 99%
- hull lost to rockfalls: mean 1.22, runs with any 37%
- blasts: mean 2.57, runs with any 94%
- ore from blasts: mean 1.40, runs with any 26%
- gems from blasts: mean 0.15, runs with any 6%
- douses: mean 2.52, runs with any 85%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 5.81, runs with any 100%
- structures entered: mean 4.15, runs with any 98%
- crates opened: mean 5.02, runs with any 94%
- loot units from crates: mean 25.53, runs with any 94%
- hollow traders met: mean 0.36, runs with any 29%
- structure events: mean 1.59, runs with any 83%
- miner sorties: mean 0.07, runs with any 4%
- miners back aboard: mean 0.07, runs with any 4%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 2.11, runs with any 3%
- gems from the miner: mean 0.32, runs with any 2%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@gate 162, combat@gate 67, heat@drill 62, heat@combat 51, combat@combat 44, fire@combat 30, fire@gate 26, fire@drill 15, heat@idle 13, fire@idle 4
- all: gems gained median 230, ore gained median 1889
- winners: gems gained median 275, ore gained median 2108
- losers: gems gained median 172, ore gained median 1612
- store lines bought (store line: count): crust_trader 0: 687, crust_trader 1: 316, crust_trader 2: 552, crust_trader 3: 521, crust_trader 4: 427, crust_trader 5: 581, crust_trader 6: 620, crust_trader 7: 556, crust_trader 8: 281, crust_trader 9: 246, hollow_trader 0: 58, hollow_trader 1: 64, hollow_trader 2: 53

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 82 | 30 [30-30] | 75 [25-140] | 17 [15-25] | 14 [14-17] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 300 | 185 | 30 [29-30] | 170 [97-262] | 21 [5-32] | 12 [12-17] | 10 [10-11] | 2 [2-2] | 4 [3-5] |
| 3 | 300 | 296 | 30 [28-30] | 219 [119-355] | 23 [3-43] | 14 [10-16] | 10 [9-11] | 1 [1-2] | 4 [3-6] |
| 4 | 300 | 395 | 30 [28-30] | 274 [154-449] | 21 [3-53] | 13 [8-19] | 10 [8-11] | 1 [1-2] | 4 [3-6] |
| 5 | 300 | 520 | 30 [27-32] | 340 [177-534] | 26 [6-58] | 14 [9-18] | 9 [9-12] | 1 [0-2] | 4 [2-7] |
| 6 | 299 | 629 | 30 [26-32] | 469 [259-695] | 43 [13-81] | 13 [8-18] | 8 [8-11] | 1 [0-2] | 4 [2-7] |
| 7 | 298 | 745 | 30 [26-35] | 486 [181-824] | 51 [11-98] | 15 [7-19] | 7 [7-11] | 1 [0-2] | 4 [2-7] |
| 8 | 291 | 852 | 30 [26-35] | 472 [222-850] | 57 [18-105] | 15 [8-19] | 7 [6-11] | 1 [0-2] | 5 [2-7] |
| 9 | 279 | 948 | 30 [27-35] | 504 [227-847] | 66 [18-121] | 15 [11-20] | 6 [5-11] | 1 [1-2] | 6 [3-7] |
| 10 | 269 | 1066 | 30 [23-35] | 666 [330-1077] | 85 [35-154] | 14 [9-21] | 6 [4-10] | 1 [0-2] | 5 [2-8] |
| 11 | 247 | 1157 | 30 [23-35] | 703 [292-1177] | 99 [35-162] | 15 [9-21] | 6 [3-11] | 1 [0-2] | 7 [2-9] |
| 12 | 233 | 1254 | 30 [24-40] | 700 [289-1179] | 108 [50-175] | 15 [10-22] | 5 [2-10] | 1 [1-2] | 7 [3-9] |
| 13 | 215 | 1336 | 35 [28-40] | 726 [328-1190] | 121 [53-190] | 16 [12-22] | 5 [1-11] | 1 [1-2] | 8 [4-9] |

## greedy (300 runs)

- results: dead 243 (81.0%), won 57 (19.0%)
- run end causes (hull, crew_<cause>, flooded): hull 136, crew_heat 74, crew_fire 21, flooded 5, crew_combat 4, rockfall 3
- killers (share of all runs): pursuer 160 (53.3%), gate 30 (10.0%), drill_crew_heat 21 (7.0%), gate_pursued 16 (5.3%), rival 12 (4.0%), rival_pursued 3 (1.0%), drill_crew_fire 1 (0.3%)
- rows reached: 5: 1, 6: 2, 7: 13, 8: 21, 9: 38, 10: 44, 11: 40, 12: 38, 13: 103
- death row (non-wins): 5: 1, 6: 2, 7: 13, 8: 21, 9: 38, 10: 44, 11: 40, 12: 38, 13: 46
- run length s: median 1070, p10 889, p90 1186
- fights per run: 1: 42, 2: 114, 3: 103, 4: 37, 5: 4
- fight results: died 15, fled 8, gate died 46, gate won 57, won 621
- fight length s: rivals median 40, gate median 40
- gate reached 103 times, won 57 (55%)
- pursuer strikes on overtaken nodes: mean 0.41, runs with any 39%
- pursuer strikes while caught: mean 4.93, runs with any 69%
- pursuer catches: mean 0.84, runs with any 70%
- bit breaks: mean 0.02, runs with any 2%
- coolant outs: mean 0.05, runs with any 5%
- crew lost: mean 1.55, runs with any 65%
- fires started: mean 7.01, runs with any 100%
- nodes overtaken: mean 16.50, runs with any 100%
- rockfalls hit: mean 5.56, runs with any 98%
- rockfalls absorbed: mean 8.41, runs with any 100%
- hull lost to rockfalls: mean 5.56, runs with any 98%
- blasts: mean 9.40, runs with any 100%
- ore from blasts: mean 65.84, runs with any 87%
- gems from blasts: mean 10.46, runs with any 61%
- douses: mean 2.74, runs with any 90%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 5.70, runs with any 100%
- structures entered: mean 5.36, runs with any 100%
- crates opened: mean 11.40, runs with any 100%
- loot units from crates: mean 67.16, runs with any 100%
- hollow traders met: mean 0.42, runs with any 34%
- structure events: mean 2.06, runs with any 93%
- miner sorties: mean 0.15, runs with any 8%
- miners back aboard: mean 0.15, runs with any 8%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 4.20, runs with any 8%
- gems from the miner: mean 0.22, runs with any 3%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@drill 255, heat@gate 47, fire@drill 40, combat@gate 40, heat@combat 34, fire@combat 14, fire@gate 12, combat@combat 11, event@dialog 10, drowned@drill 1, heat@idle 1
- all: gems gained median 250, ore gained median 2306
- winners: gems gained median 380, ore gained median 2953
- losers: gems gained median 228, ore gained median 2120
- store lines bought (store line: count): crust_trader 0: 132, crust_trader 1: 239, crust_trader 10: 43, crust_trader 11: 2, crust_trader 2: 340, crust_trader 3: 690, crust_trader 4: 144, crust_trader 5: 725, crust_trader 6: 746, crust_trader 7: 645, crust_trader 8: 212, crust_trader 9: 169, hollow_trader 0: 19, hollow_trader 1: 39, hollow_trader 2: 95

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 74 | 30 [28-30] | 122 [69-185] | 19 [15-26] | 14 [13-21] | 11 [11-11] | 2 [2-3] | 4 [3-5] |
| 2 | 300 | 173 | 29 [24-30] | 280 [196-370] | 24 [15-35] | 14 [11-20] | 10 [10-11] | 2 [2-3] | 3 [2-5] |
| 3 | 300 | 271 | 28 [22-30] | 362 [154-518] | 32 [10-56] | 14 [9-22] | 9 [9-10] | 1 [1-3] | 3 [2-7] |
| 4 | 300 | 368 | 27 [21-30] | 422 [205-672] | 37 [9-67] | 13 [8-21] | 9 [8-13] | 2 [1-3] | 4 [2-7] |
| 5 | 300 | 471 | 26 [20-29] | 498 [240-760] | 44 [17-73] | 14 [7-23] | 8 [8-14] | 2 [1-3] | 4 [3-7] |
| 6 | 299 | 568 | 24 [18-28] | 676 [395-922] | 69 [34-108] | 13 [5-24] | 8 [7-14] | 2 [1-3] | 3 [1-6] |
| 7 | 297 | 666 | 23 [17-28] | 814 [366-1144] | 85 [41-140] | 12 [5-23] | 8 [6-13] | 2 [0-3] | 3 [1-7] |
| 8 | 284 | 752 | 23 [17-28] | 872 [393-1281] | 104 [43-162] | 12 [6-24] | 9 [5-15] | 2 [1-2] | 4 [2-7] |
| 9 | 263 | 828 | 22 [15-28] | 892 [438-1376] | 116 [55-185] | 13 [6-25] | 10 [4-17] | 2 [1-2] | 4 [3-7] |
| 10 | 225 | 907 | 21 [12-27] | 1121 [649-1571] | 148 [85-222] | 13 [6-25] | 10 [4-18] | 2 [1-3] | 3 [2-7] |
| 11 | 181 | 976 | 20 [11-28] | 1248 [715-1764] | 165 [91-250] | 15 [6-28] | 10 [4-18] | 2 [1-2] | 4 [1-7] |
| 12 | 141 | 1040 | 22 [12-29] | 1282 [800-1896] | 196 [113-285] | 15 [7-29] | 11 [3-18] | 2 [1-2] | 5 [2-7] |
| 13 | 103 | 1102 | 24 [13-29] | 1428 [928-2005] | 218 [118-311] | 14 [8-31] | 12 [4-17] | 2 [1-3] | 5 [3-7] |

## balanced (300 runs)

- results: won 174 (58.0%), dead 126 (42.0%)
- run end causes (hull, crew_<cause>, flooded): hull 64, crew_heat 39, crew_combat 15, crew_fire 8
- killers (share of all runs): pursuer 65 (21.7%), gate 21 (7.0%), drill_crew_heat 15 (5.0%), rival 15 (5.0%), gate_pursued 7 (2.3%), rival_pursued 2 (0.7%), drill_crew_combat 1 (0.3%)
- rows reached: 1: 1, 6: 1, 7: 19, 8: 13, 9: 9, 10: 29, 11: 13, 12: 13, 13: 202
- death row (non-wins): 1: 1, 6: 1, 7: 19, 8: 13, 9: 9, 10: 29, 11: 13, 12: 13, 13: 28
- run length s: median 1380, p10 1161, p90 1512
- fights per run: 0: 1, 1: 16, 2: 56, 3: 170, 4: 52, 5: 4, 6: 1
- fight results: died 17, fled 11, gate died 28, gate won 174, won 642
- fight length s: rivals median 45, gate median 40
- gate reached 202 times, won 174 (86%)
- pursuer strikes on overtaken nodes: mean 0.11, runs with any 11%
- pursuer strikes while caught: mean 2.71, runs with any 30%
- pursuer catches: mean 0.36, runs with any 33%
- bit breaks: mean 0.27, runs with any 26%
- coolant outs: mean 0.13, runs with any 13%
- crew lost: mean 0.84, runs with any 34%
- fires started: mean 5.10, runs with any 97%
- nodes overtaken: mean 16.71, runs with any 100%
- rockfalls hit: mean 3.79, runs with any 90%
- rockfalls absorbed: mean 8.60, runs with any 99%
- hull lost to rockfalls: mean 3.79, runs with any 90%
- blasts: mean 4.20, runs with any 98%
- ore from blasts: mean 24.12, runs with any 68%
- gems from blasts: mean 5.09, runs with any 41%
- douses: mean 2.04, runs with any 82%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 5.86, runs with any 99%
- structures entered: mean 4.89, runs with any 99%
- crates opened: mean 7.53, runs with any 97%
- loot units from crates: mean 42.03, runs with any 97%
- hollow traders met: mean 0.46, runs with any 36%
- structure events: mean 1.84, runs with any 89%
- miner sorties: mean 1.18, runs with any 52%
- miners back aboard: mean 1.18, runs with any 52%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 35.47, runs with any 47%
- gems from the miner: mean 2.50, runs with any 18%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@drill 84, heat@gate 59, combat@combat 30, heat@combat 30, combat@gate 22, fire@gate 10, fire@combat 7, fire@drill 7, heat@idle 3, fire@idle 1
- all: gems gained median 290, ore gained median 2397
- winners: gems gained median 338, ore gained median 2619
- losers: gems gained median 176, ore gained median 1779
- store lines bought (store line: count): crust_trader 0: 457, crust_trader 1: 267, crust_trader 10: 47, crust_trader 11: 8, crust_trader 2: 345, crust_trader 3: 549, crust_trader 4: 373, crust_trader 5: 826, crust_trader 6: 817, crust_trader 7: 734, crust_trader 8: 307, crust_trader 9: 252, hollow_trader 0: 56, hollow_trader 1: 63, hollow_trader 2: 79

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 82 | 30 [29-30] | 109 [52-167] | 19 [15-25] | 14 [13-18] | 11 [11-11] | 2 [2-2] | 4 [3-6] |
| 2 | 299 | 188 | 30 [28-30] | 230 [152-341] | 24 [15-34] | 12 [11-16] | 10 [10-11] | 2 [2-3] | 4 [3-7] |
| 3 | 299 | 296 | 29 [27-30] | 281 [147-453] | 30 [9-50] | 11 [9-17] | 10 [9-10] | 1 [1-2] | 5 [3-8] |
| 4 | 299 | 416 | 29 [26-30] | 346 [187-581] | 38 [14-64] | 12 [8-17] | 9 [8-11] | 1 [1-2] | 5 [3-8] |
| 5 | 299 | 545 | 28 [25-32] | 417 [190-635] | 46 [21-76] | 11 [7-18] | 8 [8-13] | 1 [0-2] | 5 [3-8] |
| 6 | 299 | 650 | 27 [23-32] | 559 [311-806] | 69 [31-106] | 10 [6-18] | 7 [7-13] | 0 [0-2] | 5 [2-8] |
| 7 | 298 | 767 | 27 [23-32] | 662 [222-999] | 82 [38-131] | 11 [4-18] | 7 [6-12] | 1 [0-1] | 5 [3-8] |
| 8 | 279 | 878 | 27 [21-32] | 580 [275-1039] | 94 [41-142] | 12 [5-18] | 8 [5-12] | 0 [0-1] | 5 [3-8] |
| 9 | 266 | 973 | 27 [24-32] | 610 [278-969] | 107 [54-174] | 12 [8-20] | 8 [4-14] | 1 [0-1] | 5 [3-7] |
| 10 | 257 | 1098 | 27 [20-32] | 822 [443-1199] | 131 [77-199] | 11 [5-20] | 8 [3-14] | 0 [0-1] | 4 [2-7] |
| 11 | 228 | 1180 | 27 [19-32] | 810 [295-1270] | 145 [75-237] | 13 [6-21] | 8 [2-15] | 0 [0-1] | 6 [2-8] |
| 12 | 215 | 1264 | 30 [21-37] | 751 [323-1340] | 165 [93-246] | 13 [8-22] | 8 [2-16] | 1 [0-1] | 7 [3-8] |
| 13 | 202 | 1343 | 31 [25-40] | 806 [457-1394] | 180 [98-277] | 13 [9-22] | 7 [1-15] | 1 [0-1] | 7 [4-8] |

## Events (all bots)

900 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 176 | 196 |
| byrd_signal | 256 | 284 |
| cold_spring | 125 | 139 |
| gas_pocket | 162 | 180 |
| green_gallery | 176 | 196 |
| hollow_knocking | 187 | 208 |
| hollow_pool | 188 | 209 |
| knocking_pipe | 167 | 186 |
| kola_tapes | 219 | 243 |
| listening_post | 198 | 220 |
| mine_cage | 539 | 599 |
| mohole_core | 191 | 212 |
| rig_hatch | 359 | 399 |
| rig_teleprinter | 373 | 414 |
| rival_claim | 181 | 201 |
| shaft_nine | 198 | 220 |
| zarya_wreck | 196 | 218 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 116 | braced: 116 |
| blind_aquifer/intro/1 | 45 | grouted: 45 |
| blind_aquifer/intro/2 | 15 | burst: 8, rode: 7 |
| byrd_signal/intro/1 | 183 | mast: 183 |
| byrd_signal/intro/2 | 73 | silence: 73 |
| cold_spring/intro/1 | 89 | filtered: 89 |
| cold_spring/intro/3 | 36 | drained: 36 |
| gas_pocket/intro/0 | 113 | vented: 113 |
| gas_pocket/intro/2 | 49 | flash: 31, punched: 18 |
| green_gallery/intro/0 | 69 | amber: 69 |
| green_gallery/intro/1 | 107 | deep: 82, spores: 25 |
| hollow_knocking/intro/0 | 95 | answer: 50, wall: 45 |
| hollow_knocking/intro/2 | 92 | quiet: 92 |
| hollow_pool/intro/0 | 5 | pump_bad: 1, pumped: 4 |
| hollow_pool/intro/1 | 124 | deep: 36, lamp: 88 |
| hollow_pool/intro/2 | 59 | crystal: 40, shatter: 19 |
| knocking_pipe/intro/0 | 167 | clean: 167 |
| kola_tapes/intro/1 | 219 | strip: 219 |
| listening_post/intro/1 | 5 | trace: 5 |
| listening_post/intro/2 | 193 | decoy: 193 |
| mine_cage/intro/0 | 236 | fall: 49, haul: 187 |
| mine_cage/intro/1 | 194 | dropped: 66, winched: 128 |
| mine_cage/intro/2 | 109 | tag: 55, tag_back: 54 |
| mohole_core/intro/0 | 156 | gas: 30, recovered: 126 |
| mohole_core/intro/2 | 35 | leave: 35 |
| rig_hatch/intro/0 | 259 | gas: 76, stores: 183 |
| rig_hatch/intro/2 | 100 | leave: 100 |
| rig_teleprinter/intro/0 | 102 | tape: 102 |
| rig_teleprinter/intro/2 | 271 | salvage: 185, shock: 86 |
| rival_claim/intro/0 | 77 | paid: 77 |
| rival_claim/intro/2 | 16 | fight: 16 |
| rival_claim/intro/3 | 88 | rammed: 67, rammed_bad: 21 |
| shaft_nine/intro/0 | 148 | carts: 148 |
| shaft_nine/intro/2 | 50 | cable: 9, cage: 41 |
| zarya_wreck/intro/0 | 92 | logs: 92 |
| zarya_wreck/intro/2 | 104 | bits: 72, derrick: 32 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1016 | 17/17 | 0 | 11122 | 123 |
| cautious | 1017..1033 | 17/17 | 0 | 11199 | 125 |
| cautious | 1034..1050 | 17/17 | 0 | 11200 | 124 |
| cautious | 1051..1067 | 17/17 | 0 | 11217 | 126 |
| cautious | 1068..1084 | 17/17 | 0 | 11054 | 129 |
| cautious | 1085..1101 | 17/17 | 0 | 11336 | 120 |
| cautious | 1102..1118 | 17/17 | 0 | 10049 | 138 |
| cautious | 1119..1135 | 17/17 | 0 | 9972 | 142 |
| cautious | 1136..1152 | 17/17 | 0 | 10032 | 140 |
| cautious | 1153..1169 | 17/17 | 0 | 10006 | 136 |
| cautious | 1170..1186 | 17/17 | 0 | 10109 | 145 |
| cautious | 1187..1203 | 17/17 | 0 | 10017 | 134 |
| cautious | 1204..1219 | 16/16 | 0 | 10514 | 123 |
| cautious | 1220..1235 | 16/16 | 0 | 10527 | 125 |
| cautious | 1236..1251 | 16/16 | 0 | 10445 | 126 |
| cautious | 1252..1267 | 16/16 | 0 | 10332 | 127 |
| cautious | 1268..1283 | 16/16 | 0 | 10605 | 127 |
| cautious | 1284..1299 | 16/16 | 0 | 10411 | 125 |
| greedy | 1000..1016 | 17/17 | 0 | 8575 | 132 |
| greedy | 1017..1033 | 17/17 | 0 | 8756 | 118 |
| greedy | 1034..1050 | 17/17 | 0 | 8600 | 125 |
| greedy | 1051..1067 | 17/17 | 0 | 8577 | 133 |
| greedy | 1068..1084 | 17/17 | 0 | 8382 | 132 |
| greedy | 1085..1101 | 17/17 | 0 | 8460 | 129 |
| greedy | 1102..1118 | 17/17 | 0 | 9256 | 116 |
| greedy | 1119..1135 | 17/17 | 0 | 9617 | 118 |
| greedy | 1136..1152 | 17/17 | 0 | 9623 | 112 |
| greedy | 1153..1169 | 17/17 | 0 | 9389 | 111 |
| greedy | 1170..1186 | 17/17 | 0 | 9545 | 114 |
| greedy | 1187..1203 | 17/17 | 0 | 9379 | 114 |
| greedy | 1204..1219 | 16/16 | 0 | 9989 | 104 |
| greedy | 1220..1235 | 16/16 | 0 | 10102 | 97 |
| greedy | 1236..1251 | 16/16 | 0 | 10445 | 103 |
| greedy | 1252..1267 | 16/16 | 0 | 10232 | 97 |
| greedy | 1268..1283 | 16/16 | 0 | 10331 | 95 |
| greedy | 1284..1299 | 16/16 | 0 | 10167 | 98 |
| balanced | 1000..1016 | 17/17 | 0 | 9227 | 146 |
| balanced | 1017..1033 | 17/17 | 0 | 9562 | 143 |
| balanced | 1034..1050 | 17/17 | 0 | 9570 | 147 |
| balanced | 1051..1067 | 17/17 | 0 | 9466 | 152 |
| balanced | 1068..1084 | 17/17 | 0 | 9539 | 147 |
| balanced | 1085..1101 | 17/17 | 0 | 9500 | 142 |
| balanced | 1102..1118 | 17/17 | 0 | 7317 | 190 |
| balanced | 1119..1135 | 17/17 | 0 | 7366 | 192 |
| balanced | 1136..1152 | 17/17 | 0 | 7012 | 195 |
| balanced | 1153..1169 | 17/17 | 0 | 6887 | 212 |
| balanced | 1170..1186 | 17/17 | 0 | 6738 | 214 |
| balanced | 1187..1203 | 17/17 | 0 | 6621 | 214 |
| balanced | 1204..1219 | 16/16 | 0 | 5475 | 246 |
| balanced | 1220..1235 | 16/16 | 0 | 5315 | 235 |
| balanced | 1236..1251 | 16/16 | 0 | 5390 | 233 |
| balanced | 1252..1267 | 16/16 | 0 | 5578 | 233 |
| balanced | 1268..1283 | 16/16 | 0 | 5713 | 235 |
| balanced | 1284..1299 | 16/16 | 0 | 5621 | 234 |
