# Full-run balance report 20261022-232832

300 runs (100 per bot, seeds 1000..1099), 6 processes, wall 874 s (14.6 min, 48.6 min per 1000 runs). Pack: 20261022-232824-c1a127e.pck
Another Godot was running during the batch: wall time untrusted.

| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 100 | 29.0 | 0 | 13 | 1347 | 3.01 | 34 | gate 57% |
| greedy | 100 | 26.0 | 0 | 13 | 1071 | 3.03 | 39 | gate 32% |
| balanced | 100 | 50.0 | 0 | 13 | 1366 | 3.07 | 57 | gate 38% |

Dig verbs, means per run:

| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.44 | 5.14 | 0.44 | 2.76 | 1.24 | 0.13 | 2.82 | 0 |
| greedy | 5.43 | 7.02 | 5.43 | 10.47 | 82.59 | 13.58 | 3.15 | 0 |
| balanced | 2.72 | 7.54 | 2.72 | 4.53 | 25.76 | 4.78 | 2.73 | 0 |

Buried structures, means per run:

| bot | on the way | entered | crates opened | loot units | traders met | structure events |
|---|---|---|---|---|---|---|
| cautious | 5.90 | 4.14 | 4.79 | 23.77 | 0.45 | 1.58 |
| greedy | 6.05 | 5.74 | 11.52 | 64.85 | 0.64 | 2.25 |
| balanced | 6.07 | 5.15 | 7.30 | 39.68 | 0.66 | 1.93 |

Away miner, means per run (haul share: miner ore over all ore gained, summed over the runs):

| bot | sorties | runs with any % | back | deaths | haul ore | haul gems | lost units | haul share of ore % |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.10 | 6 | 0.10 | 0.00 | 4.5 | 0.0 | 0.0 | 0.3 |
| greedy | 0.31 | 18 | 0.31 | 0.00 | 8.5 | 0.3 | 0.0 | 0.4 |
| balanced | 1.79 | 76 | 1.79 | 0.00 | 57.2 | 3.4 | 0.0 | 2.7 |

## cautious (100 runs)

- results: dead 71 (71.0%), won 29 (29.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 37, crew_combat 19, crew_fire 9, hull 6
- killers (share of all runs): gate 57 (57.0%), rival 11 (11.0%), pursuer 2 (2.0%), drill_crew_heat 1 (1.0%)
- rows reached: 7: 2, 9: 1, 10: 4, 11: 4, 12: 3, 13: 86
- death row (non-wins): 7: 2, 9: 1, 10: 4, 11: 4, 12: 3, 13: 57
- run length s: median 1347, p10 1219, p90 1433
- fights per run: 1: 2, 2: 11, 3: 71, 4: 16
- fight results: died 11, fled 1, gate died 57, gate won 29, won 203
- fight length s: rivals median 49, gate median 64
- gate reached 86 times, won 29 (34%)
- pursuer strikes on overtaken nodes: mean 0.01, runs with any 1%
- pursuer strikes while caught: mean 0.24, runs with any 2%
- pursuer catches: mean 0.03, runs with any 3%
- bit breaks: mean 0.06, runs with any 6%
- coolant outs: mean 0.01, runs with any 1%
- crew lost: mean 2.59, runs with any 94%
- fires started: mean 6.44, runs with any 100%
- nodes overtaken: mean 16.85, runs with any 100%
- rockfalls hit: mean 0.44, runs with any 32%
- rockfalls absorbed: mean 5.14, runs with any 99%
- hull lost to rockfalls: mean 0.44, runs with any 32%
- blasts: mean 2.76, runs with any 99%
- ore from blasts: mean 1.24, runs with any 25%
- gems from blasts: mean 0.13, runs with any 6%
- douses: mean 2.82, runs with any 88%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 5.90, runs with any 100%
- structures entered: mean 4.14, runs with any 100%
- crates opened: mean 4.79, runs with any 94%
- loot units from crates: mean 23.77, runs with any 94%
- hollow traders met: mean 0.45, runs with any 34%
- structure events: mean 1.58, runs with any 83%
- miner sorties: mean 0.10, runs with any 6%
- miners back aboard: mean 0.10, runs with any 6%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 4.52, runs with any 6%
- gems from the miner: mean 0.00, runs with any 0%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@gate 142, combat@gate 56, heat@combat 19, combat@combat 18, fire@gate 12, fire@combat 8, heat@drill 4
- all: gems gained median 186, ore gained median 1634
- winners: gems gained median 196, ore gained median 1684
- losers: gems gained median 181, ore gained median 1628
- store lines bought (store line: count): crust_trader 0: 235, crust_trader 1: 107, crust_trader 13: 99, crust_trader 15: 183, crust_trader 16: 95, crust_trader 2: 184, crust_trader 3: 189, crust_trader 4: 158, crust_trader 7: 87, crust_trader 8: 86, crust_trader 9: 57, hollow_trader 0: 23, hollow_trader 1: 25, hollow_trader 2: 28

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 82 | 30 [30-30] | 70 [24-137] | 16 [15-25] | 14 [13-18] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 100 | 185 | 30 [29-30] | 172 [86-252] | 23 [5-32] | 12 [11-17] | 10 [10-11] | 2 [2-3] | 4 [3-5] |
| 3 | 100 | 296 | 30 [29-30] | 230 [124-317] | 25 [4-46] | 14 [10-16] | 10 [9-11] | 1 [1-2] | 4 [3-6] |
| 4 | 100 | 391 | 30 [28-30] | 264 [159-413] | 25 [4-58] | 13 [8-19] | 10 [8-10] | 1 [1-2] | 4 [3-6] |
| 5 | 100 | 491 | 30 [28-30] | 302 [177-535] | 24 [10-59] | 15 [9-18] | 9 [9-11] | 1 [0-2] | 4 [3-7] |
| 6 | 100 | 605 | 30 [27-30] | 422 [253-639] | 43 [13-80] | 13 [7-16] | 8 [8-10] | 1 [0-2] | 4 [2-6] |
| 7 | 100 | 692 | 30 [27-35] | 450 [166-743] | 52 [13-102] | 14 [7-18] | 7 [7-10] | 1 [0-2] | 5 [2-7] |
| 8 | 98 | 780 | 35 [27-35] | 382 [178-764] | 50 [14-105] | 15 [10-19] | 6 [6-10] | 1 [0-2] | 5 [2-7] |
| 9 | 98 | 882 | 35 [30-40] | 358 [177-624] | 63 [16-115] | 16 [12-20] | 6 [5-10] | 2 [1-2] | 6 [3-7] |
| 10 | 97 | 993 | 35 [27-38] | 521 [282-800] | 79 [32-129] | 14 [9-22] | 6 [4-10] | 1 [1-2] | 4 [2-7] |
| 11 | 93 | 1084 | 35 [27-40] | 551 [164-1056] | 88 [32-144] | 15 [8-21] | 5 [3-9] | 1 [1-2] | 5 [2-9] |
| 12 | 89 | 1190 | 40 [28-40] | 440 [214-897] | 90 [34-154] | 16 [12-23] | 5 [2-9] | 2 [1-2] | 7 [3-9] |
| 13 | 86 | 1289 | 40 [32-40] | 439 [279-832] | 97 [35-169] | 16 [12-23] | 5 [1-10] | 2 [1-2] | 8 [4-9] |

## greedy (100 runs)

- results: dead 74 (74.0%), won 26 (26.0%)
- run end causes (hull, crew_<cause>, flooded): hull 32, crew_heat 20, crew_fire 17, crew_combat 4, flooded 1
- killers (share of all runs): gate 32 (32.0%), pursuer 16 (16.0%), rival 8 (8.0%), gate_pursued 8 (8.0%), drill_crew_fire 4 (4.0%), drill_crew_heat 4 (4.0%), drill_crew_combat 2 (2.0%)
- rows reached: 6: 1, 8: 3, 10: 7, 11: 12, 12: 11, 13: 66
- death row (non-wins): 6: 1, 8: 3, 10: 7, 11: 12, 12: 11, 13: 40
- run length s: median 1071, p10 916, p90 1160
- fights per run: 0: 1, 1: 2, 2: 19, 3: 51, 4: 26, 6: 1
- fight results: died 8, fled 5, gate died 40, gate won 26, won 224
- fight length s: rivals median 41, gate median 49
- gate reached 66 times, won 26 (39%)
- pursuer strikes on overtaken nodes: mean 0.17, runs with any 14%
- pursuer strikes while caught: mean 2.23, runs with any 37%
- pursuer catches: mean 0.49, runs with any 40%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.03, runs with any 3%
- crew lost: mean 1.96, runs with any 82%
- fires started: mean 7.12, runs with any 100%
- nodes overtaken: mean 17.40, runs with any 100%
- rockfalls hit: mean 5.43, runs with any 99%
- rockfalls absorbed: mean 7.02, runs with any 100%
- hull lost to rockfalls: mean 5.43, runs with any 99%
- blasts: mean 10.47, runs with any 100%
- ore from blasts: mean 82.59, runs with any 94%
- gems from blasts: mean 13.58, runs with any 73%
- douses: mean 3.15, runs with any 92%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 6.05, runs with any 100%
- structures entered: mean 5.74, runs with any 100%
- crates opened: mean 11.52, runs with any 99%
- loot units from crates: mean 64.85, runs with any 99%
- hollow traders met: mean 0.64, runs with any 49%
- structure events: mean 2.25, runs with any 95%
- miner sorties: mean 0.31, runs with any 18%
- miners back aboard: mean 0.31, runs with any 18%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 8.54, runs with any 17%
- gems from the miner: mean 0.32, runs with any 3%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@gate 68, heat@drill 56, combat@gate 21, fire@gate 16, fire@combat 11, combat@combat 10, heat@combat 5, fire@drill 5, event@dialog 4
- all: gems gained median 298, ore gained median 2331
- winners: gems gained median 349, ore gained median 2672
- losers: gems gained median 284, ore gained median 2232
- store lines bought (store line: count): crust_trader 0: 38, crust_trader 1: 79, crust_trader 10: 99, crust_trader 11: 99, crust_trader 13: 100, crust_trader 14: 95, crust_trader 15: 112, crust_trader 2: 97, crust_trader 3: 257, crust_trader 4: 70, crust_trader 5: 79, crust_trader 9: 144, hollow_trader 0: 8, hollow_trader 1: 15, hollow_trader 2: 47

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 74 | 30 [28-30] | 122 [78-184] | 19 [15-26] | 14 [13-22] | 11 [11-11] | 2 [2-3] | 4 [3-5] |
| 2 | 100 | 175 | 29 [24-30] | 276 [173-364] | 26 [15-37] | 14 [11-21] | 10 [10-11] | 2 [2-4] | 3 [2-5] |
| 3 | 100 | 274 | 28 [23-30] | 326 [158-498] | 33 [16-55] | 14 [9-22] | 10 [9-10] | 2 [1-3] | 3 [1-7] |
| 4 | 100 | 355 | 27 [22-29] | 382 [221-629] | 40 [15-70] | 13 [8-22] | 9 [8-13] | 2 [1-3] | 4 [2-7] |
| 5 | 100 | 440 | 26 [21-29] | 422 [252-672] | 43 [16-74] | 12 [7-24] | 8 [8-13] | 2 [1-3] | 4 [3-7] |
| 6 | 100 | 543 | 24 [18-28] | 562 [321-814] | 71 [33-105] | 12 [6-23] | 8 [7-13] | 2 [1-3] | 4 [1-7] |
| 7 | 99 | 614 | 23 [17-27] | 627 [244-998] | 86 [40-134] | 14 [6-22] | 7 [6-13] | 2 [1-3] | 4 [2-7] |
| 8 | 99 | 692 | 22 [18-26] | 547 [259-1072] | 104 [50-151] | 13 [6-25] | 8 [5-14] | 2 [1-3] | 5 [2-7] |
| 9 | 96 | 758 | 22 [16-28] | 522 [250-840] | 102 [48-165] | 14 [8-27] | 9 [4-15] | 2 [2-3] | 5 [3-7] |
| 10 | 96 | 835 | 20 [13-26] | 686 [389-1071] | 126 [82-199] | 15 [6-27] | 9 [5-17] | 2 [1-3] | 3 [2-7] |
| 11 | 89 | 910 | 22 [12-29] | 798 [430-1309] | 155 [84-229] | 15 [6-26] | 9 [4-16] | 2 [1-3] | 4 [2-7] |
| 12 | 77 | 981 | 24 [14-33] | 808 [435-1335] | 168 [98-236] | 17 [8-31] | 11 [4-17] | 2 [1-3] | 5 [3-7] |
| 13 | 66 | 1046 | 29 [17-33] | 912 [600-1467] | 178 [121-260] | 16 [7-30] | 11 [3-18] | 2 [1-3] | 6 [3-8] |

## balanced (100 runs)

- results: won 50 (50.0%), dead 50 (50.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 23, crew_combat 14, crew_fire 8, hull 5
- killers (share of all runs): gate 38 (38.0%), rival 5 (5.0%), drill_crew_heat 3 (3.0%), pursuer 2 (2.0%), drill_crew_combat 1 (1.0%), drill_crew_fire 1 (1.0%)
- rows reached: 8: 1, 10: 4, 11: 6, 12: 1, 13: 88
- death row (non-wins): 8: 1, 10: 4, 11: 6, 12: 1, 13: 38
- run length s: median 1366, p10 1275, p90 1480
- fights per run: 1: 1, 2: 7, 3: 76, 4: 16
- fight results: died 5, fled 3, gate died 38, gate won 50, won 211
- fight length s: rivals median 48, gate median 63
- gate reached 88 times, won 50 (57%)
- pursuer strikes on overtaken nodes: mean 0.00, runs with any 0%
- pursuer strikes while caught: mean 0.27, runs with any 8%
- pursuer catches: mean 0.14, runs with any 13%
- bit breaks: mean 0.04, runs with any 4%
- coolant outs: mean 0.08, runs with any 8%
- crew lost: mean 1.93, runs with any 77%
- fires started: mean 5.98, runs with any 100%
- nodes overtaken: mean 17.41, runs with any 100%
- rockfalls hit: mean 2.72, runs with any 95%
- rockfalls absorbed: mean 7.54, runs with any 99%
- hull lost to rockfalls: mean 2.72, runs with any 95%
- blasts: mean 4.53, runs with any 100%
- ore from blasts: mean 25.76, runs with any 71%
- gems from blasts: mean 4.78, runs with any 34%
- douses: mean 2.73, runs with any 94%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 6.07, runs with any 100%
- structures entered: mean 5.15, runs with any 99%
- crates opened: mean 7.30, runs with any 98%
- loot units from crates: mean 39.68, runs with any 98%
- hollow traders met: mean 0.66, runs with any 51%
- structure events: mean 1.93, runs with any 90%
- miner sorties: mean 1.79, runs with any 76%
- miners back aboard: mean 1.79, runs with any 76%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 57.21, runs with any 70%
- gems from the miner: mean 3.35, runs with any 28%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@gate 103, combat@gate 44, combat@combat 13, heat@drill 12, fire@combat 9, fire@gate 8, heat@combat 3, heat@idle 1
- all: gems gained median 248, ore gained median 2106
- winners: gems gained median 289, ore gained median 2118
- losers: gems gained median 220, ore gained median 2040
- store lines bought (store line: count): crust_trader 0: 154, crust_trader 1: 90, crust_trader 10: 43, crust_trader 13: 100, crust_trader 14: 35, crust_trader 15: 188, crust_trader 16: 88, crust_trader 2: 115, crust_trader 3: 201, crust_trader 4: 136, crust_trader 5: 36, crust_trader 7: 74, crust_trader 8: 100, crust_trader 9: 150, hollow_trader 0: 24, hollow_trader 1: 27, hollow_trader 2: 41

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 82 | 30 [29-30] | 108 [59-164] | 19 [15-25] | 14 [13-18] | 11 [11-11] | 2 [2-2] | 4 [3-6] |
| 2 | 100 | 193 | 30 [28-30] | 228 [151-334] | 25 [15-34] | 12 [11-16] | 10 [10-11] | 2 [2-3] | 4 [3-7] |
| 3 | 100 | 299 | 29 [27-30] | 284 [132-464] | 32 [14-54] | 10 [9-17] | 10 [9-10] | 1 [1-2] | 5 [3-8] |
| 4 | 100 | 408 | 29 [26-30] | 342 [190-565] | 38 [16-63] | 12 [8-17] | 9 [8-10] | 1 [1-2] | 5 [3-8] |
| 5 | 100 | 516 | 29 [26-32] | 370 [192-598] | 46 [21-75] | 12 [7-18] | 8 [8-12] | 1 [1-2] | 5 [3-8] |
| 6 | 100 | 633 | 28 [25-32] | 498 [297-764] | 64 [33-101] | 10 [5-17] | 7 [7-12] | 1 [0-1] | 5 [3-7] |
| 7 | 100 | 724 | 28 [24-34] | 535 [224-922] | 86 [42-123] | 12 [6-17] | 6 [6-12] | 0 [0-1] | 5 [3-8] |
| 8 | 100 | 827 | 32 [24-34] | 482 [214-955] | 97 [60-151] | 12 [7-18] | 7 [5-12] | 1 [0-1] | 4 [3-7] |
| 9 | 99 | 927 | 32 [29-37] | 426 [201-716] | 114 [59-179] | 13 [8-20] | 7 [4-13] | 1 [0-1] | 5 [3-7] |
| 10 | 99 | 1028 | 32 [28-37] | 593 [282-888] | 141 [89-198] | 12 [6-21] | 7 [3-13] | 0 [0-1] | 4 [2-7] |
| 11 | 95 | 1123 | 32 [26-37] | 649 [214-1055] | 146 [78-222] | 13 [6-24] | 7 [2-13] | 0 [0-1] | 5 [2-8] |
| 12 | 89 | 1216 | 37 [26-40] | 444 [238-969] | 152 [82-252] | 14 [10-23] | 7 [1-14] | 1 [0-1] | 7 [3-8] |
| 13 | 88 | 1309 | 39 [31-40] | 484 [227-753] | 166 [78-261] | 15 [10-25] | 7 [1-14] | 1 [0-1] | 7 [4-8] |

## Events (all bots)

300 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 74 | 247 |
| byrd_signal | 87 | 290 |
| cold_spring | 61 | 203 |
| gas_pocket | 53 | 177 |
| green_gallery | 77 | 257 |
| hollow_knocking | 82 | 273 |
| hollow_pool | 67 | 223 |
| knocking_pipe | 41 | 137 |
| kola_tapes | 77 | 257 |
| listening_post | 61 | 203 |
| mine_cage | 172 | 573 |
| mohole_core | 78 | 260 |
| rig_hatch | 127 | 423 |
| rig_teleprinter | 128 | 427 |
| rival_claim | 44 | 147 |
| shaft_nine | 80 | 267 |
| zarya_wreck | 60 | 200 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 31 | braced: 31 |
| blind_aquifer/intro/1 | 31 | grouted: 31 |
| blind_aquifer/intro/2 | 12 | burst: 9, rode: 3 |
| byrd_signal/intro/1 | 45 | mast: 45 |
| byrd_signal/intro/2 | 42 | silence: 42 |
| cold_spring/intro/1 | 35 | filtered: 35 |
| cold_spring/intro/3 | 26 | drained: 26 |
| gas_pocket/intro/0 | 53 | vented: 53 |
| green_gallery/intro/0 | 53 | amber: 53 |
| green_gallery/intro/1 | 24 | deep: 21, spores: 3 |
| hollow_knocking/intro/0 | 31 | answer: 18, wall: 13 |
| hollow_knocking/intro/2 | 51 | quiet: 51 |
| hollow_pool/intro/0 | 39 | pump_bad: 8, pumped: 31 |
| hollow_pool/intro/1 | 28 | deep: 13, lamp: 15 |
| knocking_pipe/intro/0 | 41 | clean: 41 |
| kola_tapes/intro/1 | 77 | strip: 77 |
| listening_post/intro/1 | 1 | trace: 1 |
| listening_post/intro/2 | 60 | decoy: 60 |
| mine_cage/intro/0 | 59 | fall: 13, haul: 46 |
| mine_cage/intro/1 | 64 | dropped: 19, winched: 45 |
| mine_cage/intro/2 | 49 | tag: 29, tag_back: 20 |
| mohole_core/intro/0 | 48 | gas: 5, recovered: 43 |
| mohole_core/intro/2 | 30 | leave: 30 |
| rig_hatch/intro/0 | 91 | gas: 24, stores: 67 |
| rig_hatch/intro/2 | 36 | leave: 36 |
| rig_teleprinter/intro/0 | 32 | tape: 32 |
| rig_teleprinter/intro/2 | 96 | salvage: 70, shock: 26 |
| rival_claim/intro/0 | 28 | paid: 28 |
| rival_claim/intro/2 | 16 | fight: 16 |
| shaft_nine/intro/0 | 27 | carts: 27 |
| shaft_nine/intro/1 | 31 | coolant: 25, sludge: 6 |
| shaft_nine/intro/2 | 22 | cable: 4, cage: 18 |
| zarya_wreck/intro/0 | 43 | logs: 43 |
| zarya_wreck/intro/2 | 17 | bits: 10, derrick: 7 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1009 | 10/10 | 0 | 4670 | 171 |
| cautious | 1010..1019 | 10/10 | 0 | 4634 | 174 |
| cautious | 1020..1029 | 10/10 | 0 | 5136 | 155 |
| cautious | 1030..1039 | 10/10 | 0 | 4906 | 163 |
| cautious | 1040..1049 | 10/10 | 0 | 4677 | 172 |
| cautious | 1050..1059 | 10/10 | 0 | 4465 | 182 |
| cautious | 1060..1069 | 10/10 | 0 | 5773 | 152 |
| cautious | 1070..1079 | 10/10 | 0 | 5608 | 147 |
| cautious | 1080..1089 | 10/10 | 0 | 5888 | 142 |
| cautious | 1090..1099 | 10/10 | 0 | 5743 | 141 |
| greedy | 1000..1009 | 10/10 | 0 | 5460 | 120 |
| greedy | 1010..1019 | 10/10 | 0 | 4968 | 129 |
| greedy | 1020..1029 | 10/10 | 0 | 5895 | 102 |
| greedy | 1030..1039 | 10/10 | 0 | 5904 | 114 |
| greedy | 1040..1049 | 10/10 | 0 | 6359 | 110 |
| greedy | 1050..1059 | 10/10 | 0 | 6259 | 107 |
| greedy | 1060..1069 | 10/10 | 0 | 6376 | 101 |
| greedy | 1070..1079 | 10/10 | 0 | 6399 | 101 |
| greedy | 1080..1089 | 10/10 | 0 | 3755 | 173 |
| greedy | 1090..1099 | 10/10 | 0 | 3511 | 182 |
| balanced | 1000..1009 | 10/10 | 0 | 3613 | 230 |
| balanced | 1010..1019 | 10/10 | 0 | 3625 | 227 |
| balanced | 1020..1029 | 10/10 | 0 | 3066 | 262 |
| balanced | 1030..1039 | 10/10 | 0 | 3689 | 225 |
| balanced | 1040..1049 | 10/10 | 0 | 3808 | 220 |
| balanced | 1050..1059 | 10/10 | 0 | 3582 | 234 |
| balanced | 1060..1069 | 10/10 | 0 | 3823 | 218 |
| balanced | 1070..1079 | 10/10 | 0 | 3784 | 216 |
| balanced | 1080..1089 | 10/10 | 0 | 3851 | 229 |
| balanced | 1090..1099 | 10/10 | 0 | 4330 | 185 |
