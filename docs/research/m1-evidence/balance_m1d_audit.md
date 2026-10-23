# Full-run balance report 20261022-173741

300 runs (100 per bot, seeds 1000..1099), 6 processes, wall 2222 s (37.0 min, 123.5 min per 1000 runs). Pack: 20261022-173718-f421564.pck
Another Godot was running during the batch: wall time untrusted.

| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 100 | 24.0 | 0 | 13 | 1354 | 2.77 | 33 | gate 47% |
| greedy | 100 | 12.0 | 0 | 12 | 1071 | 2.66 | 29 | pursuer 44% |
| balanced | 100 | 47.0 | 0 | 13 | 1384 | 3.04 | 55 | gate 34% |

Dig verbs, means per run:

| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.48 | 4.91 | 0.48 | 2.47 | 1.28 | 0.19 | 2.68 | 0 |
| greedy | 5.81 | 7.49 | 5.81 | 9.48 | 59.79 | 9.75 | 2.78 | 98 |
| balanced | 2.93 | 7.43 | 2.93 | 4.15 | 21.46 | 4.02 | 3.00 | 0 |

Buried structures, means per run:

| bot | on the way | entered | crates opened | loot units | traders met | structure events |
|---|---|---|---|---|---|---|
| cautious | 5.75 | 4.06 | 4.70 | 23.64 | 0.42 | 1.56 |
| greedy | 5.78 | 5.46 | 11.40 | 65.52 | 0.55 | 2.15 |
| balanced | 5.98 | 5.05 | 7.27 | 41.76 | 0.68 | 1.98 |

Away miner, means per run (haul share: miner ore over all ore gained, summed over the runs):

| bot | sorties | runs with any % | back | deaths | haul ore | haul gems | lost units | haul share of ore % |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.06 | 4 | 0.06 | 0.00 | 3.3 | 0.0 | 0.0 | 0.3 |
| greedy | 0.10 | 4 | 0.10 | 0.00 | 3.5 | 0.1 | 0.0 | 0.2 |
| balanced | 1.45 | 58 | 1.45 | 0.00 | 40.2 | 4.3 | 0.0 | 2.4 |

## cautious (100 runs)

- results: dead 76 (76.0%), won 24 (24.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 42, crew_combat 15, hull 10, crew_fire 8, rockfall 1
- killers (share of all runs): gate 47 (47.0%), rival 16 (16.0%), pursuer 9 (9.0%), drill_crew_heat 3 (3.0%), gate_pursued 1 (1.0%)
- rows reached: 7: 5, 8: 1, 9: 1, 10: 6, 11: 8, 12: 7, 13: 72
- death row (non-wins): 7: 5, 8: 1, 9: 1, 10: 6, 11: 8, 12: 7, 13: 48
- run length s: median 1354, p10 1158, p90 1441
- fights per run: 1: 9, 2: 17, 3: 62, 4: 12
- fight results: died 16, fled 2, gate died 48, gate won 24, won 187
- fight length s: rivals median 49, gate median 58
- gate reached 72 times, won 24 (33%)
- pursuer strikes on overtaken nodes: mean 0.04, runs with any 4%
- pursuer strikes while caught: mean 1.00, runs with any 11%
- pursuer catches: mean 0.13, runs with any 12%
- bit breaks: mean 0.13, runs with any 13%
- coolant outs: mean 0.06, runs with any 6%
- crew lost: mean 2.50, runs with any 89%
- fires started: mean 6.28, runs with any 100%
- nodes overtaken: mean 16.53, runs with any 100%
- rockfalls hit: mean 0.48, runs with any 35%
- rockfalls absorbed: mean 4.91, runs with any 98%
- hull lost to rockfalls: mean 0.48, runs with any 35%
- blasts: mean 2.47, runs with any 93%
- ore from blasts: mean 1.28, runs with any 22%
- gems from blasts: mean 0.19, runs with any 7%
- douses: mean 2.68, runs with any 91%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 5.75, runs with any 100%
- structures entered: mean 4.06, runs with any 98%
- crates opened: mean 4.70, runs with any 90%
- loot units from crates: mean 23.64, runs with any 90%
- hollow traders met: mean 0.42, runs with any 34%
- structure events: mean 1.56, runs with any 81%
- miner sorties: mean 0.06, runs with any 4%
- miners back aboard: mean 0.06, runs with any 4%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 3.30, runs with any 4%
- gems from the miner: mean 0.00, runs with any 0%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@gate 109, combat@gate 49, heat@combat 27, combat@combat 25, heat@drill 15, fire@gate 12, fire@combat 11, fire@idle 1, fire@drill 1
- all: gems gained median 150, ore gained median 1238
- winners: gems gained median 160, ore gained median 1284
- losers: gems gained median 147, ore gained median 1208
- store lines bought (store line: count): crust_trader 0: 225, crust_trader 1: 112, crust_trader 13: 95, crust_trader 15: 158, crust_trader 16: 91, crust_trader 2: 154, crust_trader 3: 174, crust_trader 4: 151, crust_trader 7: 62, crust_trader 8: 55, crust_trader 9: 19, hollow_trader 0: 20, hollow_trader 1: 26, hollow_trader 2: 21

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 82 | 30 [30-30] | 57 [23-102] | 15 [15-22] | 14 [14-18] | 11 [11-11] | 2 [2-2] | 4 [3-6] |
| 2 | 100 | 186 | 30 [29-30] | 128 [66-202] | 21 [6-30] | 12 [12-17] | 10 [10-11] | 2 [2-3] | 4 [3-6] |
| 3 | 100 | 296 | 30 [29-30] | 181 [116-266] | 23 [3-43] | 14 [10-16] | 10 [9-11] | 1 [1-2] | 4 [3-6] |
| 4 | 100 | 391 | 30 [28-30] | 244 [130-356] | 22 [4-47] | 13 [8-18] | 10 [8-10] | 1 [1-2] | 4 [3-6] |
| 5 | 100 | 512 | 30 [28-30] | 254 [146-410] | 21 [5-44] | 14 [10-18] | 9 [9-10] | 1 [0-2] | 4 [2-6] |
| 6 | 100 | 615 | 30 [27-30] | 360 [201-530] | 32 [10-65] | 13 [8-17] | 8 [8-10] | 1 [0-2] | 4 [2-6] |
| 7 | 100 | 713 | 30 [27-35] | 375 [176-686] | 36 [6-77] | 14 [6-18] | 7 [7-10] | 1 [0-2] | 4 [2-7] |
| 8 | 95 | 813 | 31 [25-35] | 320 [159-636] | 36 [15-86] | 15 [9-20] | 6 [6-10] | 1 [0-2] | 5 [2-7] |
| 9 | 94 | 906 | 35 [29-35] | 298 [168-540] | 44 [17-77] | 16 [11-21] | 6 [5-10] | 1 [0-2] | 6 [3-7] |
| 10 | 93 | 1010 | 34 [25-35] | 438 [236-740] | 63 [19-108] | 15 [10-21] | 6 [4-10] | 1 [0-2] | 4 [2-7] |
| 11 | 87 | 1106 | 35 [25-40] | 473 [169-799] | 66 [26-116] | 15 [10-23] | 5 [3-10] | 1 [0-2] | 5 [2-8] |
| 12 | 79 | 1209 | 40 [25-40] | 308 [118-771] | 73 [19-128] | 17 [12-24] | 5 [2-10] | 2 [1-2] | 7 [3-9] |
| 13 | 72 | 1299 | 40 [32-40] | 344 [175-518] | 74 [11-134] | 17 [12-25] | 5 [1-9] | 2 [1-2] | 8 [6-9] |

## greedy (100 runs)

- results: dead 88 (88.0%), won 12 (12.0%)
- run end causes (hull, crew_<cause>, flooded): hull 49, crew_heat 17, crew_fire 13, rockfall 4, crew_combat 4, flooded 1
- killers (share of all runs): pursuer 44 (44.0%), gate 19 (19.0%), gate_pursued 11 (11.0%), rival 8 (8.0%), drill_crew_combat 2 (2.0%), drill_crew_heat 2 (2.0%), rival_pursued 1 (1.0%), drill_crew_fire 1 (1.0%)
- rows reached: 7: 2, 8: 10, 9: 2, 10: 14, 11: 13, 12: 17, 13: 42
- death row (non-wins): 7: 2, 8: 10, 9: 2, 10: 14, 11: 13, 12: 17, 13: 30
- run length s: median 1071, p10 872, p90 1179
- fights per run: 0: 1, 1: 9, 2: 29, 3: 47, 4: 13, 6: 1
- fight results: died 9, fled 3, gate died 30, gate won 12, won 212
- fight length s: rivals median 41, gate median 49
- gate reached 42 times, won 12 (29%)
- pursuer strikes on overtaken nodes: mean 0.40, runs with any 34%
- pursuer strikes while caught: mean 4.27, runs with any 70%
- pursuer catches: mean 0.92, runs with any 71%
- bit breaks: mean 0.01, runs with any 1%
- coolant outs: mean 0.04, runs with any 4%
- crew lost: mean 1.54, runs with any 64%
- fires started: mean 7.42, runs with any 100%
- nodes overtaken: mean 17.09, runs with any 100%
- rockfalls hit: mean 5.81, runs with any 98%
- rockfalls absorbed: mean 7.49, runs with any 100%
- hull lost to rockfalls: mean 5.81, runs with any 98%
- blasts: mean 9.48, runs with any 100%
- ore from blasts: mean 59.79, runs with any 86%
- gems from blasts: mean 9.75, runs with any 51%
- douses: mean 2.78, runs with any 84%
- drilling s past 60 degrees: mean 98.42, runs with any 100%
- structures on the way: mean 5.78, runs with any 100%
- structures entered: mean 5.46, runs with any 100%
- crates opened: mean 11.40, runs with any 99%
- loot units from crates: mean 65.52, runs with any 99%
- hollow traders met: mean 0.55, runs with any 44%
- structure events: mean 2.15, runs with any 95%
- miner sorties: mean 0.10, runs with any 4%
- miners back aboard: mean 0.10, runs with any 4%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 3.52, runs with any 4%
- gems from the miner: mean 0.05, runs with any 1%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@drill 56, heat@gate 31, combat@gate 15, fire@gate 13, combat@combat 11, fire@drill 9, heat@combat 8, fire@combat 7, event@dialog 4
- all: gems gained median 249, ore gained median 2006
- winners: gems gained median 296, ore gained median 2262
- losers: gems gained median 240, ore gained median 1974
- store lines bought (store line: count): crust_trader 0: 45, crust_trader 1: 78, crust_trader 10: 95, crust_trader 11: 87, crust_trader 13: 99, crust_trader 14: 87, crust_trader 15: 69, crust_trader 2: 98, crust_trader 3: 236, crust_trader 4: 58, crust_trader 5: 61, crust_trader 9: 111, hollow_trader 0: 6, hollow_trader 1: 10, hollow_trader 2: 31

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 77 | 30 [28-30] | 102 [58-171] | 19 [15-27] | 14 [13-22] | 11 [11-11] | 2 [2-3] | 4 [3-5] |
| 2 | 100 | 188 | 29 [25-30] | 230 [167-320] | 24 [15-35] | 14 [12-21] | 10 [10-11] | 2 [2-4] | 3 [2-5] |
| 3 | 100 | 289 | 28 [23-30] | 298 [144-413] | 32 [13-49] | 14 [9-22] | 10 [9-10] | 2 [1-3] | 4 [1-7] |
| 4 | 100 | 376 | 27 [22-29] | 362 [200-548] | 36 [13-59] | 13 [8-23] | 9 [8-13] | 2 [1-3] | 4 [2-7] |
| 5 | 100 | 472 | 26 [20-29] | 403 [219-593] | 38 [20-66] | 12 [7-22] | 8 [8-13] | 2 [1-3] | 4 [3-7] |
| 6 | 100 | 571 | 24 [18-28] | 517 [330-744] | 60 [31-103] | 12 [6-24] | 7 [7-13] | 2 [1-3] | 3 [1-6] |
| 7 | 100 | 648 | 23 [17-27] | 576 [200-897] | 82 [38-135] | 12 [6-23] | 7 [6-13] | 2 [1-3] | 3 [2-7] |
| 8 | 98 | 726 | 22 [16-26] | 496 [233-1006] | 95 [45-148] | 12 [6-23] | 8 [5-14] | 2 [1-3] | 4 [2-7] |
| 9 | 88 | 798 | 21 [16-27] | 459 [243-703] | 94 [45-141] | 12 [7-25] | 8 [4-16] | 2 [1-3] | 4 [3-7] |
| 10 | 86 | 885 | 19 [13-26] | 621 [339-979] | 122 [60-181] | 14 [6-27] | 9 [4-17] | 2 [1-3] | 4 [2-7] |
| 11 | 72 | 957 | 20 [12-27] | 656 [307-1083] | 137 [70-222] | 12 [5-27] | 10 [4-19] | 2 [1-3] | 5 [3-7] |
| 12 | 59 | 1029 | 21 [7-31] | 637 [368-1068] | 166 [101-239] | 14 [7-30] | 11 [3-18] | 2 [1-3] | 5 [3-7] |
| 13 | 42 | 1094 | 28 [14-32] | 715 [283-1010] | 162 [102-246] | 18 [8-37] | 11 [3-20] | 2 [1-3] | 6 [3-7] |

## balanced (100 runs)

- results: dead 53 (53.0%), won 47 (47.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 20, crew_fire 13, hull 12, crew_combat 7, flooded 1
- killers (share of all runs): gate 34 (34.0%), rival 7 (7.0%), gate_pursued 5 (5.0%), drill_crew_fire 3 (3.0%), drill_crew_heat 2 (2.0%), pursuer 2 (2.0%)
- rows reached: 7: 4, 8: 1, 10: 2, 11: 4, 12: 3, 13: 86
- death row (non-wins): 7: 4, 8: 1, 10: 2, 11: 4, 12: 3, 13: 39
- run length s: median 1384, p10 1282, p90 1499
- fights per run: 1: 2, 2: 9, 3: 73, 4: 15, 5: 1
- fight results: died 7, fled 2, gate died 39, gate won 47, won 209
- fight length s: rivals median 48, gate median 62
- gate reached 86 times, won 47 (55%)
- pursuer strikes on overtaken nodes: mean 0.01, runs with any 1%
- pursuer strikes while caught: mean 0.78, runs with any 15%
- pursuer catches: mean 0.16, runs with any 15%
- bit breaks: mean 0.07, runs with any 7%
- coolant outs: mean 0.08, runs with any 8%
- crew lost: mean 1.88, runs with any 76%
- fires started: mean 6.20, runs with any 100%
- nodes overtaken: mean 17.35, runs with any 100%
- rockfalls hit: mean 2.93, runs with any 95%
- rockfalls absorbed: mean 7.43, runs with any 100%
- hull lost to rockfalls: mean 2.93, runs with any 95%
- blasts: mean 4.15, runs with any 97%
- ore from blasts: mean 21.46, runs with any 69%
- gems from blasts: mean 4.02, runs with any 31%
- douses: mean 3.00, runs with any 94%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 5.98, runs with any 100%
- structures entered: mean 5.05, runs with any 100%
- crates opened: mean 7.27, runs with any 99%
- loot units from crates: mean 41.76, runs with any 99%
- hollow traders met: mean 0.68, runs with any 50%
- structure events: mean 1.98, runs with any 91%
- miner sorties: mean 1.45, runs with any 58%
- miners back aboard: mean 1.45, runs with any 58%
- miner deaths: mean 0.00, runs with any 0%
- ore from the miner: mean 40.17, runs with any 53%
- gems from the miner: mean 4.33, runs with any 29%
- haul units lost: mean 0.00, runs with any 0%
- crew death causes: heat@gate 85, combat@gate 34, fire@gate 18, heat@drill 14, heat@combat 14, combat@combat 12, fire@combat 8, fire@drill 1, heat@idle 1, fire@idle 1
- all: gems gained median 222, ore gained median 1734
- winners: gems gained median 249, ore gained median 1791
- losers: gems gained median 197, ore gained median 1633
- store lines bought (store line: count): crust_trader 0: 141, crust_trader 1: 90, crust_trader 10: 22, crust_trader 13: 97, crust_trader 14: 11, crust_trader 15: 165, crust_trader 16: 91, crust_trader 2: 115, crust_trader 3: 183, crust_trader 4: 146, crust_trader 5: 17, crust_trader 7: 64, crust_trader 8: 95, crust_trader 9: 113, hollow_trader 0: 25, hollow_trader 1: 33, hollow_trader 2: 36

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 83 | 30 [29-30] | 92 [44-134] | 15 [15-23] | 14 [14-18] | 11 [11-11] | 2 [2-2] | 4 [3-6] |
| 2 | 100 | 193 | 30 [28-30] | 197 [126-272] | 21 [15-30] | 12 [11-16] | 10 [10-11] | 2 [2-3] | 4 [3-7] |
| 3 | 100 | 300 | 29 [26-30] | 244 [123-349] | 28 [13-45] | 11 [9-15] | 10 [9-10] | 1 [1-2] | 5 [3-8] |
| 4 | 100 | 410 | 29 [26-30] | 307 [189-429] | 31 [13-55] | 12 [8-17] | 9 [8-10] | 1 [1-2] | 5 [3-8] |
| 5 | 100 | 525 | 28 [26-33] | 316 [159-497] | 38 [15-62] | 11 [6-18] | 8 [8-11] | 1 [0-2] | 5 [3-8] |
| 6 | 100 | 635 | 28 [26-32] | 428 [255-628] | 54 [22-87] | 10 [4-17] | 7 [7-11] | 1 [0-2] | 5 [2-8] |
| 7 | 100 | 732 | 27 [25-33] | 490 [163-840] | 72 [31-110] | 12 [5-17] | 6 [6-11] | 0 [0-1] | 5 [2-8] |
| 8 | 96 | 824 | 28 [24-33] | 357 [183-854] | 86 [40-132] | 12 [6-20] | 7 [5-11] | 1 [0-1] | 5 [3-8] |
| 9 | 95 | 934 | 32 [26-34] | 339 [166-577] | 95 [51-141] | 12 [8-19] | 6 [4-12] | 1 [0-1] | 5 [3-7] |
| 10 | 95 | 1040 | 31 [24-34] | 470 [263-770] | 115 [70-169] | 12 [7-21] | 7 [3-13] | 0 [0-1] | 4 [3-7] |
| 11 | 93 | 1132 | 32 [24-37] | 467 [186-862] | 128 [70-197] | 14 [9-22] | 8 [2-13] | 0 [0-1] | 6 [2-8] |
| 12 | 89 | 1236 | 34 [24-40] | 381 [204-820] | 135 [82-212] | 13 [10-22] | 7 [1-13] | 1 [0-1] | 7 [3-8] |
| 13 | 86 | 1333 | 37 [30-40] | 376 [231-603] | 148 [69-230] | 14 [9-24] | 6 [0-15] | 1 [0-1] | 7 [4-8] |

## Events (all bots)

300 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 70 | 233 |
| byrd_signal | 85 | 283 |
| cold_spring | 54 | 180 |
| gas_pocket | 54 | 180 |
| green_gallery | 78 | 260 |
| hollow_knocking | 74 | 247 |
| hollow_pool | 66 | 220 |
| knocking_pipe | 41 | 137 |
| kola_tapes | 84 | 280 |
| listening_post | 58 | 193 |
| mine_cage | 176 | 587 |
| mohole_core | 80 | 267 |
| rig_hatch | 124 | 413 |
| rig_teleprinter | 129 | 430 |
| rival_claim | 43 | 143 |
| shaft_nine | 77 | 257 |
| zarya_wreck | 56 | 187 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 28 | braced: 28 |
| blind_aquifer/intro/1 | 31 | grouted: 31 |
| blind_aquifer/intro/2 | 11 | burst: 8, rode: 3 |
| byrd_signal/intro/1 | 45 | mast: 45 |
| byrd_signal/intro/2 | 40 | silence: 40 |
| cold_spring/intro/1 | 33 | filtered: 33 |
| cold_spring/intro/3 | 21 | drained: 21 |
| gas_pocket/intro/0 | 54 | vented: 54 |
| green_gallery/intro/0 | 54 | amber: 54 |
| green_gallery/intro/1 | 24 | deep: 21, spores: 3 |
| hollow_knocking/intro/0 | 30 | answer: 20, wall: 10 |
| hollow_knocking/intro/2 | 44 | quiet: 44 |
| hollow_pool/intro/0 | 40 | pump_bad: 8, pumped: 32 |
| hollow_pool/intro/1 | 26 | deep: 13, lamp: 13 |
| knocking_pipe/intro/0 | 41 | clean: 41 |
| kola_tapes/intro/1 | 84 | strip: 84 |
| listening_post/intro/1 | 1 | trace: 1 |
| listening_post/intro/2 | 57 | decoy: 57 |
| mine_cage/intro/0 | 60 | fall: 12, haul: 48 |
| mine_cage/intro/1 | 64 | dropped: 18, winched: 46 |
| mine_cage/intro/2 | 52 | tag: 29, tag_back: 23 |
| mohole_core/intro/0 | 50 | gas: 5, recovered: 45 |
| mohole_core/intro/2 | 30 | leave: 30 |
| rig_hatch/intro/0 | 88 | gas: 19, stores: 69 |
| rig_hatch/intro/2 | 36 | leave: 36 |
| rig_teleprinter/intro/0 | 32 | tape: 32 |
| rig_teleprinter/intro/2 | 97 | salvage: 72, shock: 25 |
| rival_claim/intro/0 | 27 | paid: 27 |
| rival_claim/intro/2 | 16 | fight: 16 |
| shaft_nine/intro/0 | 27 | carts: 27 |
| shaft_nine/intro/1 | 29 | coolant: 24, sludge: 5 |
| shaft_nine/intro/2 | 21 | cable: 4, cage: 17 |
| zarya_wreck/intro/0 | 43 | logs: 43 |
| zarya_wreck/intro/2 | 13 | bits: 6, derrick: 7 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1009 | 10/10 | 0 | 3348 | 230 |
| cautious | 1010..1019 | 10/10 | 0 | 3183 | 258 |
| cautious | 1020..1029 | 10/10 | 0 | 3109 | 268 |
| cautious | 1030..1039 | 10/10 | 0 | 3132 | 260 |
| cautious | 1040..1049 | 10/10 | 0 | 3225 | 236 |
| cautious | 1050..1059 | 10/10 | 0 | 3304 | 249 |
| cautious | 1060..1069 | 10/10 | 0 | 1933 | 454 |
| cautious | 1070..1079 | 10/10 | 0 | 1818 | 484 |
| cautious | 1080..1089 | 10/10 | 0 | 1924 | 411 |
| cautious | 1090..1099 | 10/10 | 0 | 1713 | 490 |
| greedy | 1000..1009 | 10/10 | 0 | 1722 | 371 |
| greedy | 1010..1019 | 10/10 | 0 | 1594 | 425 |
| greedy | 1020..1029 | 10/10 | 0 | 1193 | 524 |
| greedy | 1030..1039 | 10/10 | 0 | 1161 | 590 |
| greedy | 1040..1049 | 10/10 | 0 | 1248 | 534 |
| greedy | 1050..1059 | 10/10 | 0 | 1168 | 569 |
| greedy | 1060..1069 | 10/10 | 0 | 1205 | 584 |
| greedy | 1070..1079 | 10/10 | 0 | 1236 | 517 |
| greedy | 1080..1089 | 10/10 | 0 | 1576 | 413 |
| greedy | 1090..1099 | 10/10 | 0 | 1511 | 417 |
| balanced | 1000..1009 | 10/10 | 0 | 1632 | 525 |
| balanced | 1010..1019 | 10/10 | 0 | 1564 | 563 |
| balanced | 1020..1029 | 10/10 | 0 | 1590 | 499 |
| balanced | 1030..1039 | 10/10 | 0 | 1544 | 551 |
| balanced | 1040..1049 | 10/10 | 0 | 1833 | 468 |
| balanced | 1050..1059 | 10/10 | 0 | 1676 | 508 |
| balanced | 1060..1069 | 10/10 | 0 | 2012 | 449 |
| balanced | 1070..1079 | 10/10 | 0 | 1944 | 435 |
| balanced | 1080..1089 | 10/10 | 0 | 2235 | 398 |
| balanced | 1090..1099 | 10/10 | 0 | 2341 | 354 |
