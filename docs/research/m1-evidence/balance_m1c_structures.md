# Full-run balance report 20261016-201955

900 runs (300 per bot, seeds 1000..1299), 6 processes, wall 1239 s (20.6 min, 22.9 min per 1000 runs). Pack: 20261016-201950-06b0067.pck


| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 300 | 25.7 | 0 | 13 | 1339 | 2.95 | 34 | gate 49% |
| greedy | 300 | 15.0 | 0 | 12 | 1084 | 2.79 | 31 | pursuer 35% |
| balanced | 300 | 37.7 | 0 | 13 | 1328 | 3.01 | 45 | gate 43% |

Dig verbs, means per run:

| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.40 | 4.81 | 0.40 | 2.47 | 0.90 | 0.17 | 3.16 | 0 |
| greedy | 5.94 | 7.43 | 5.94 | 13.90 | 158.17 | 22.37 | 3.25 | 94 |
| balanced | 2.94 | 7.53 | 2.94 | 9.41 | 152.01 | 20.47 | 3.44 | 0 |

Buried structures, means per run:

| bot | on the way | entered | crates opened | loot units | traders met | structure events |
|---|---|---|---|---|---|---|
| cautious | 5.86 | 4.08 | 4.99 | 25.54 | 0.39 | 1.35 |
| greedy | 5.97 | 5.66 | 12.14 | 71.46 | 0.47 | 1.75 |
| balanced | 6.12 | 5.25 | 7.94 | 44.54 | 0.52 | 1.63 |

## cautious (300 runs)

- results: dead 223 (74.3%), won 77 (25.7%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 123, crew_combat 41, crew_fire 32, hull 27
- killers (share of all runs): gate 146 (48.7%), rival 39 (13.0%), pursuer 16 (5.3%), drill_crew_heat 13 (4.3%), gate_pursued 6 (2.0%), drill_crew_fire 2 (0.7%), drill_crew_combat 1 (0.3%)
- rows reached: 7: 10, 8: 6, 9: 8, 10: 15, 11: 17, 12: 15, 13: 229
- death row (non-wins): 7: 10, 8: 6, 9: 8, 10: 15, 11: 17, 12: 15, 13: 152
- run length s: median 1339, p10 1165, p90 1455
- fights per run: 1: 11, 2: 43, 3: 200, 4: 44, 5: 1, 7: 1
- fight results: died 39, fled 15, gate died 152, gate won 77, won 602
- fight length s: rivals median 49, gate median 60
- gate reached 229 times, won 77 (34%)
- pursuer strikes on overtaken nodes: mean 0.03, runs with any 3%
- pursuer strikes while caught: mean 0.74, runs with any 9%
- pursuer catches: mean 0.10, runs with any 10%
- bit breaks: mean 0.13, runs with any 13%
- coolant outs: mean 0.07, runs with any 7%
- crew lost: mean 2.63, runs with any 91%
- fires started: mean 6.67, runs with any 100%
- nodes overtaken: mean 16.47, runs with any 100%
- rockfalls hit: mean 0.40, runs with any 32%
- rockfalls absorbed: mean 4.81, runs with any 98%
- hull lost to rockfalls: mean 0.40, runs with any 32%
- blasts: mean 2.47, runs with any 92%
- ore from blasts: mean 0.90, runs with any 20%
- gems from blasts: mean 0.17, runs with any 6%
- douses: mean 3.16, runs with any 93%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 5.86, runs with any 100%
- structures entered: mean 4.08, runs with any 99%
- crates opened: mean 4.99, runs with any 94%
- loot units from crates: mean 25.54, runs with any 94%
- hollow traders met: mean 0.39, runs with any 32%
- structure events: mean 1.35, runs with any 83%
- crew death causes: heat@gate 369, combat@gate 157, heat@combat 78, combat@combat 58, heat@drill 44, fire@gate 36, fire@combat 31, fire@drill 8, heat@idle 4, fire@idle 3
- all: gems gained median 146, ore gained median 1254
- winners: gems gained median 166, ore gained median 1368
- losers: gems gained median 137, ore gained median 1217
- store lines bought (store line: count): crust_trader 0: 670, crust_trader 1: 334, crust_trader 13: 285, crust_trader 15: 492, crust_trader 16: 263, crust_trader 2: 500, crust_trader 3: 506, crust_trader 4: 472, crust_trader 7: 181, crust_trader 8: 167, crust_trader 9: 49, hollow_trader 0: 56, hollow_trader 1: 57, hollow_trader 2: 65

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 40 [35-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 82 | 40 [30-40] | 61 [24-118] | 15 [15-22] | 14 [14-18] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 300 | 185 | 40 [29-40] | 142 [68-218] | 21 [5-30] | 12 [11-17] | 10 [10-11] | 2 [2-2] | 4 [3-6] |
| 3 | 300 | 295 | 35 [28-40] | 187 [107-291] | 19 [2-39] | 14 [10-16] | 10 [9-11] | 1 [1-2] | 4 [3-6] |
| 4 | 300 | 392 | 35 [28-40] | 234 [129-360] | 19 [4-41] | 13 [9-18] | 10 [8-11] | 1 [1-2] | 4 [2-6] |
| 5 | 300 | 513 | 30 [28-40] | 258 [138-413] | 19 [4-41] | 14 [9-19] | 9 [8-12] | 1 [0-2] | 4 [2-7] |
| 6 | 300 | 615 | 30 [27-40] | 340 [196-522] | 31 [7-62] | 13 [7-18] | 8 [8-12] | 1 [0-2] | 4 [2-6] |
| 7 | 300 | 714 | 30 [26-35] | 359 [154-619] | 34 [7-71] | 14 [6-19] | 7 [7-12] | 1 [0-2] | 4 [2-7] |
| 8 | 290 | 813 | 34 [26-35] | 312 [153-619] | 36 [10-77] | 15 [8-20] | 7 [6-12] | 1 [0-2] | 5 [2-7] |
| 9 | 284 | 906 | 35 [30-35] | 302 [155-570] | 42 [12-81] | 16 [12-22] | 7 [5-12] | 1 [0-2] | 5 [2-7] |
| 10 | 276 | 1008 | 34 [26-35] | 407 [230-735] | 58 [19-108] | 15 [10-21] | 6 [4-12] | 1 [0-2] | 4 [2-7] |
| 11 | 261 | 1102 | 35 [27-40] | 395 [167-796] | 60 [17-115] | 15 [9-24] | 6 [3-12] | 1 [0-2] | 6 [2-9] |
| 12 | 244 | 1196 | 40 [28-40] | 328 [154-741] | 63 [19-119] | 17 [12-24] | 6 [2-12] | 1 [1-2] | 7 [3-9] |
| 13 | 229 | 1293 | 40 [31-40] | 318 [176-546] | 65 [23-123] | 16 [13-23] | 6 [1-12] | 2 [1-2] | 8 [4-9] |

## greedy (300 runs)

- results: dead 255 (85.0%), won 45 (15.0%)
- run end causes (hull, crew_<cause>, flooded): hull 149, crew_heat 51, crew_fire 32, crew_combat 14, rockfall 5, flooded 4
- killers (share of all runs): pursuer 106 (35.3%), gate 77 (25.7%), gate_pursued 25 (8.3%), rival 21 (7.0%), drill_crew_heat 14 (4.7%), drill_crew_fire 5 (1.7%), drill_crew_combat 4 (1.3%), rival_pursued 3 (1.0%)
- rows reached: 5: 1, 6: 2, 7: 6, 8: 17, 9: 19, 10: 37, 11: 37, 12: 34, 13: 147
- death row (non-wins): 5: 1, 6: 2, 7: 6, 8: 17, 9: 19, 10: 37, 11: 37, 12: 34, 13: 102
- run length s: median 1084, p10 891, p90 1164
- fights per run: 0: 2, 1: 15, 2: 77, 3: 161, 4: 41, 5: 3, 6: 1
- fight results: died 24, fled 9, gate died 102, gate won 45, won 657
- fight length s: rivals median 41, gate median 49
- gate reached 147 times, won 45 (31%)
- pursuer strikes on overtaken nodes: mean 0.28, runs with any 26%
- pursuer strikes while caught: mean 4.01, runs with any 65%
- pursuer catches: mean 0.86, runs with any 69%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.06, runs with any 6%
- crew lost: mean 1.70, runs with any 72%
- fires started: mean 8.34, runs with any 100%
- nodes overtaken: mean 16.90, runs with any 100%
- rockfalls hit: mean 5.94, runs with any 98%
- rockfalls absorbed: mean 7.43, runs with any 99%
- hull lost to rockfalls: mean 5.94, runs with any 98%
- blasts: mean 13.90, runs with any 100%
- ore from blasts: mean 158.17, runs with any 99%
- gems from blasts: mean 22.37, runs with any 91%
- douses: mean 3.25, runs with any 94%
- drilling s past 60 degrees: mean 93.60, runs with any 100%
- structures on the way: mean 5.97, runs with any 100%
- structures entered: mean 5.66, runs with any 100%
- crates opened: mean 12.14, runs with any 99%
- loot units from crates: mean 71.46, runs with any 99%
- hollow traders met: mean 0.47, runs with any 39%
- structure events: mean 1.75, runs with any 95%
- crew death causes: heat@drill 166, heat@gate 97, combat@gate 67, fire@gate 44, combat@combat 39, fire@drill 31, fire@combat 29, heat@combat 24, event@dialog 10, drowned@drill 4
- all: gems gained median 237, ore gained median 2010
- winners: gems gained median 309, ore gained median 2214
- losers: gems gained median 226, ore gained median 1940
- store lines bought (store line: count): crust_trader 0: 155, crust_trader 1: 239, crust_trader 10: 286, crust_trader 11: 273, crust_trader 13: 298, crust_trader 14: 265, crust_trader 15: 212, crust_trader 2: 394, crust_trader 3: 756, crust_trader 4: 144, crust_trader 5: 166, crust_trader 9: 328, hollow_trader 0: 18, hollow_trader 1: 36, hollow_trader 2: 121

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 35 [30-35] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 78 | 30 [28-35] | 108 [62-174] | 18 [15-25] | 14 [13-18] | 11 [11-11] | 2 [2-3] | 4 [3-5] |
| 2 | 300 | 183 | 29 [27-35] | 241 [172-323] | 23 [15-33] | 12 [11-20] | 10 [10-11] | 2 [2-3] | 3 [2-6] |
| 3 | 300 | 282 | 28 [25-35] | 318 [153-453] | 29 [10-51] | 13 [9-21] | 9 [9-10] | 1 [1-2] | 3 [2-7] |
| 4 | 300 | 370 | 27 [24-29] | 356 [174-559] | 33 [12-59] | 12 [8-21] | 9 [8-14] | 2 [1-2] | 3 [2-6] |
| 5 | 300 | 464 | 26 [22-29] | 368 [198-557] | 36 [15-64] | 12 [6-22] | 8 [8-14] | 2 [1-3] | 3 [2-6] |
| 6 | 299 | 565 | 25 [20-28] | 505 [317-711] | 58 [25-96] | 11 [5-22] | 8 [7-14] | 1 [1-3] | 3 [0-4] |
| 7 | 297 | 647 | 24 [19-27] | 586 [218-907] | 70 [32-114] | 11 [5-23] | 8 [6-14] | 1 [1-2] | 3 [0-5] |
| 8 | 291 | 726 | 22 [17-27] | 480 [223-958] | 81 [36-138] | 11 [5-23] | 9 [5-15] | 2 [1-2] | 3 [1-5] |
| 9 | 274 | 795 | 22 [16-27] | 441 [223-737] | 85 [39-145] | 12 [6-26] | 10 [4-16] | 2 [1-2] | 3 [2-5] |
| 10 | 255 | 878 | 20 [12-27] | 612 [357-922] | 109 [55-178] | 12 [5-25] | 9 [4-16] | 2 [1-3] | 3 [1-5] |
| 11 | 218 | 952 | 21 [11-28] | 623 [296-1079] | 122 [61-200] | 13 [6-26] | 10 [4-17] | 2 [1-2] | 3 [1-5] |
| 12 | 181 | 1019 | 22 [12-29] | 640 [372-1135] | 137 [64-223] | 15 [7-30] | 10 [5-18] | 2 [1-2] | 3 [2-6] |
| 13 | 147 | 1088 | 26 [11-31] | 745 [417-1087] | 144 [68-233] | 15 [7-29] | 10 [4-19] | 2 [1-2] | 3 [2-6] |

## balanced (300 runs)

- results: dead 187 (62.3%), won 113 (37.7%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 85, crew_combat 48, hull 35, crew_fire 19
- killers (share of all runs): gate 130 (43.3%), rival 33 (11.0%), pursuer 9 (3.0%), gate_pursued 7 (2.3%), drill_crew_heat 4 (1.3%), drill_crew_fire 4 (1.3%)
- rows reached: 1: 1, 5: 1, 6: 1, 7: 6, 8: 4, 9: 6, 10: 10, 11: 14, 12: 7, 13: 250
- death row (non-wins): 1: 1, 5: 1, 6: 1, 7: 6, 8: 4, 9: 6, 10: 10, 11: 14, 12: 7, 13: 137
- run length s: median 1328, p10 1158, p90 1430
- fights per run: 1: 8, 2: 29, 3: 217, 4: 45, 7: 1
- fight results: died 33, fled 5, gate died 137, gate won 113, won 616
- fight length s: rivals median 52, gate median 63
- gate reached 250 times, won 113 (45%)
- pursuer strikes on overtaken nodes: mean 0.02, runs with any 2%
- pursuer strikes while caught: mean 0.60, runs with any 12%
- pursuer catches: mean 0.14, runs with any 14%
- bit breaks: mean 0.05, runs with any 5%
- coolant outs: mean 0.05, runs with any 5%
- crew lost: mean 2.19, runs with any 79%
- fires started: mean 7.07, runs with any 100%
- nodes overtaken: mean 16.85, runs with any 100%
- rockfalls hit: mean 2.94, runs with any 94%
- rockfalls absorbed: mean 7.53, runs with any 99%
- hull lost to rockfalls: mean 2.94, runs with any 94%
- blasts: mean 9.41, runs with any 100%
- ore from blasts: mean 152.01, runs with any 99%
- gems from blasts: mean 20.47, runs with any 89%
- douses: mean 3.44, runs with any 94%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- structures on the way: mean 6.12, runs with any 100%
- structures entered: mean 5.25, runs with any 100%
- crates opened: mean 7.94, runs with any 98%
- loot units from crates: mean 44.54, runs with any 98%
- hollow traders met: mean 0.52, runs with any 41%
- structure events: mean 1.63, runs with any 91%
- crew death causes: heat@gate 327, combat@gate 154, combat@combat 58, heat@combat 36, fire@gate 34, fire@combat 21, heat@drill 18, fire@drill 4, heat@idle 3, fire@idle 1
- all: gems gained median 204, ore gained median 1682
- winners: gems gained median 217, ore gained median 1756
- losers: gems gained median 194, ore gained median 1618
- store lines bought (store line: count): crust_trader 0: 431, crust_trader 1: 269, crust_trader 10: 63, crust_trader 13: 292, crust_trader 14: 36, crust_trader 15: 489, crust_trader 16: 265, crust_trader 2: 344, crust_trader 3: 712, crust_trader 4: 440, crust_trader 5: 156, crust_trader 7: 170, crust_trader 8: 288, crust_trader 9: 300, hollow_trader 0: 56, hollow_trader 1: 69, hollow_trader 2: 124

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 300 | 0 | 40 [35-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 300 | 83 | 40 [29-40] | 87 [43-138] | 15 [15-23] | 14 [14-18] | 11 [11-11] | 2 [2-2] | 4 [3-6] |
| 2 | 299 | 189 | 35 [28-40] | 193 [119-271] | 21 [15-30] | 12 [11-16] | 10 [10-11] | 2 [2-3] | 4 [3-7] |
| 3 | 299 | 297 | 29 [27-40] | 242 [123-364] | 25 [8-44] | 11 [9-18] | 10 [9-10] | 1 [1-2] | 5 [3-8] |
| 4 | 299 | 393 | 29 [26-40] | 288 [162-441] | 29 [11-53] | 13 [8-18] | 9 [8-11] | 1 [1-2] | 4 [3-7] |
| 5 | 299 | 500 | 28 [26-35] | 307 [134-465] | 35 [15-63] | 12 [8-19] | 8 [8-12] | 1 [0-2] | 4 [3-7] |
| 6 | 298 | 605 | 27 [25-32] | 394 [220-598] | 51 [23-88] | 11 [6-20] | 7 [7-12] | 1 [0-2] | 3 [2-6] |
| 7 | 297 | 695 | 27 [24-33] | 444 [176-750] | 61 [29-105] | 12 [5-21] | 7 [6-12] | 1 [0-1] | 3 [2-5] |
| 8 | 291 | 787 | 28 [24-33] | 380 [167-788] | 71 [34-120] | 13 [6-21] | 7 [5-12] | 1 [0-1] | 3 [2-5] |
| 9 | 287 | 881 | 31 [26-34] | 326 [170-603] | 75 [37-123] | 13 [9-22] | 7 [4-13] | 1 [0-1] | 3 [3-5] |
| 10 | 281 | 988 | 31 [23-34] | 461 [268-759] | 93 [48-147] | 12 [7-22] | 7 [3-13] | 0 [0-1] | 3 [2-5] |
| 11 | 271 | 1080 | 31 [24-37] | 453 [199-885] | 96 [41-165] | 13 [7-23] | 7 [2-13] | 0 [0-1] | 3 [2-7] |
| 12 | 257 | 1172 | 34 [25-40] | 393 [206-855] | 101 [41-163] | 13 [8-22] | 7 [2-14] | 1 [0-1] | 4 [3-7] |
| 13 | 250 | 1274 | 37 [30-40] | 386 [177-590] | 98 [44-167] | 14 [9-24] | 6 [1-14] | 1 [0-1] | 4 [2-7] |

## Events (all bots)

900 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 182 | 202 |
| byrd_signal | 266 | 296 |
| cold_spring | 145 | 161 |
| gas_pocket | 169 | 188 |
| green_gallery | 184 | 204 |
| hollow_knocking | 316 | 351 |
| knocking_pipe | 171 | 190 |
| kola_tapes | 226 | 251 |
| listening_post | 192 | 213 |
| mine_cage | 552 | 613 |
| mohole_core | 195 | 217 |
| rig_hatch | 553 | 614 |
| rival_claim | 193 | 214 |
| shaft_nine | 198 | 220 |
| zarya_wreck | 196 | 218 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 68 | braced: 68 |
| blind_aquifer/intro/1 | 81 | grouted: 81 |
| blind_aquifer/intro/2 | 33 | burst: 21, rode: 12 |
| byrd_signal/intro/0 | 2 | answer: 2 |
| byrd_signal/intro/1 | 153 | mast: 153 |
| byrd_signal/intro/2 | 111 | silence: 111 |
| cold_spring/intro/1 | 102 | filtered: 102 |
| cold_spring/intro/3 | 43 | drained: 43 |
| gas_pocket/intro/0 | 169 | vented: 169 |
| green_gallery/intro/0 | 131 | amber: 131 |
| green_gallery/intro/1 | 53 | deep: 43, spores: 10 |
| hollow_knocking/intro/0 | 125 | answer: 73, wall: 52 |
| hollow_knocking/intro/1 | 191 | quiet: 191 |
| knocking_pipe/intro/0 | 171 | clean: 171 |
| kola_tapes/intro/1 | 226 | strip: 226 |
| listening_post/intro/1 | 5 | trace: 5 |
| listening_post/intro/2 | 187 | decoy: 187 |
| mine_cage/intro/0 | 384 | fall: 116, haul: 268 |
| mine_cage/intro/1 | 168 | end: 168 |
| mohole_core/intro/0 | 123 | gas: 21, recovered: 102 |
| mohole_core/intro/2 | 72 | leave: 72 |
| rig_hatch/intro/0 | 553 | gas: 161, stores: 392 |
| rival_claim/intro/0 | 125 | paid: 125 |
| rival_claim/intro/2 | 68 | fight: 68 |
| shaft_nine/intro/0 | 65 | carts: 65 |
| shaft_nine/intro/1 | 70 | coolant: 57, sludge: 13 |
| shaft_nine/intro/2 | 63 | cable: 10, cage: 53 |
| zarya_wreck/intro/0 | 139 | logs: 139 |
| zarya_wreck/intro/2 | 57 | bits: 38, derrick: 19 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1016 | 17/17 | 0 | 9946 | 137 |
| cautious | 1017..1033 | 17/17 | 0 | 9905 | 135 |
| cautious | 1034..1050 | 17/17 | 0 | 9937 | 132 |
| cautious | 1051..1067 | 17/17 | 0 | 10044 | 139 |
| cautious | 1068..1084 | 17/17 | 0 | 10060 | 132 |
| cautious | 1085..1101 | 17/17 | 0 | 10016 | 137 |
| cautious | 1102..1118 | 17/17 | 0 | 10050 | 133 |
| cautious | 1119..1135 | 17/17 | 0 | 9922 | 139 |
| cautious | 1136..1152 | 17/17 | 0 | 10005 | 137 |
| cautious | 1153..1169 | 17/17 | 0 | 9934 | 135 |
| cautious | 1170..1186 | 17/17 | 0 | 9877 | 138 |
| cautious | 1187..1203 | 17/17 | 0 | 9881 | 137 |
| cautious | 1204..1219 | 16/16 | 0 | 9899 | 128 |
| cautious | 1220..1235 | 16/16 | 0 | 9978 | 129 |
| cautious | 1236..1251 | 16/16 | 0 | 9952 | 129 |
| cautious | 1252..1267 | 16/16 | 0 | 9903 | 128 |
| cautious | 1268..1283 | 16/16 | 0 | 9986 | 128 |
| cautious | 1284..1299 | 16/16 | 0 | 9862 | 126 |
| greedy | 1000..1016 | 17/17 | 0 | 8677 | 129 |
| greedy | 1017..1033 | 17/17 | 0 | 8673 | 121 |
| greedy | 1034..1050 | 17/17 | 0 | 8696 | 124 |
| greedy | 1051..1067 | 17/17 | 0 | 8683 | 125 |
| greedy | 1068..1084 | 17/17 | 0 | 8749 | 124 |
| greedy | 1085..1101 | 17/17 | 0 | 8719 | 124 |
| greedy | 1102..1118 | 17/17 | 0 | 8823 | 124 |
| greedy | 1119..1135 | 17/17 | 0 | 9006 | 121 |
| greedy | 1136..1152 | 17/17 | 0 | 8819 | 120 |
| greedy | 1153..1169 | 17/17 | 0 | 8846 | 121 |
| greedy | 1170..1186 | 17/17 | 0 | 8849 | 122 |
| greedy | 1187..1203 | 17/17 | 0 | 8736 | 123 |
| greedy | 1204..1219 | 16/16 | 0 | 8710 | 116 |
| greedy | 1220..1235 | 16/16 | 0 | 8746 | 114 |
| greedy | 1236..1251 | 16/16 | 0 | 8796 | 112 |
| greedy | 1252..1267 | 16/16 | 0 | 8748 | 118 |
| greedy | 1268..1283 | 16/16 | 0 | 8793 | 118 |
| greedy | 1284..1299 | 16/16 | 0 | 8725 | 117 |
| balanced | 1000..1016 | 17/17 | 0 | 8546 | 157 |
| balanced | 1017..1033 | 17/17 | 0 | 8577 | 154 |
| balanced | 1034..1050 | 17/17 | 0 | 8426 | 159 |
| balanced | 1051..1067 | 17/17 | 0 | 8488 | 158 |
| balanced | 1068..1084 | 17/17 | 0 | 8601 | 153 |
| balanced | 1085..1101 | 17/17 | 0 | 8592 | 153 |
| balanced | 1102..1118 | 17/17 | 0 | 8094 | 167 |
| balanced | 1119..1135 | 17/17 | 0 | 8222 | 161 |
| balanced | 1136..1152 | 17/17 | 0 | 8125 | 163 |
| balanced | 1153..1169 | 17/17 | 0 | 8054 | 164 |
| balanced | 1170..1186 | 17/17 | 0 | 8046 | 168 |
| balanced | 1187..1203 | 17/17 | 0 | 8028 | 165 |
| balanced | 1204..1219 | 16/16 | 0 | 8810 | 145 |
| balanced | 1220..1235 | 16/16 | 0 | 8698 | 148 |
| balanced | 1236..1251 | 16/16 | 0 | 8720 | 134 |
| balanced | 1252..1267 | 16/16 | 0 | 8715 | 144 |
| balanced | 1268..1283 | 16/16 | 0 | 8714 | 149 |
| balanced | 1284..1299 | 16/16 | 0 | 8653 | 150 |
