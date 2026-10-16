# Full-run balance report 20261015-213524

300 runs (100 per bot, seeds 1000..1099), 3 processes, wall 277 s (4.6 min, 15.4 min per 1000 runs). Pack: 20261015-213517-111cc42.pck


| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 100 | 16.0 | 0 | 9 | 484 | 2.93 | 23 | gate 42% |
| greedy | 100 | 12.0 | 0 | 9 | 456 | 3.32 | 21 | gate 40% |
| balanced | 100 | 19.0 | 0 | 9 | 474 | 2.96 | 29 | gate 42% |

## cautious (100 runs)

- results: dead 84 (84.0%), won 16 (16.0%)
- run end causes (hull, crew_<cause>, flooded): hull 78, crew_heat 5, crew_combat 1
- killers (share of all runs): gate 42 (42.0%), pursuer 22 (22.0%), gate_pursued 11 (11.0%), rival_pursued 7 (7.0%), rival 2 (2.0%)
- rows reached: 2: 1, 3: 3, 4: 3, 5: 4, 6: 5, 7: 6, 8: 6, 9: 72
- death row (non-wins): 2: 1, 3: 3, 4: 3, 5: 4, 6: 5, 7: 6, 8: 6, 9: 56
- run length s: median 484, p10 365, p90 532
- fights per run: 1: 1, 2: 20, 3: 64, 4: 15
- fight results: died 9, fled 3, gate died 53, gate won 16, won 212
- fight length s: rivals median 48, gate median 74
- gate reached 69 times, won 16 (23%)
- pursuer strikes on overtaken nodes: mean 0.18, runs with any 17%
- pursuer strikes while caught: mean 3.14, runs with any 53%
- pursuer catches: mean 0.61, runs with any 57%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.06, runs with any 6%
- crew lost: mean 1.31, runs with any 61%
- fires started: mean 5.47, runs with any 99%
- nodes overtaken: mean 11.52, runs with any 100%
- crew death causes: combat@gate 44, heat@gate 40, fire@gate 27, combat@combat 15, fire@combat 3, fire@drill 2
- all: gems gained median 64, ore gained median 108
- winners: gems gained median 89, ore gained median 108
- losers: gems gained median 57, ore gained median 106
- store lines bought (store line: count): crust_trader 0: 115, crust_trader 1: 80, crust_trader 2: 58, crust_trader 3: 69, crust_trader 4: 73

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 26 | 30 [30-30] | 22 [10-35] | 19 [15-25] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 58 | 30 [30-30] | 35 [14-58] | 24 [6-33] | 14 [13-19] | 6 [6-8] | 2 [2-2] | 4 [4-4] |
| 3 | 99 | 99 | 30 [28-30] | 49 [24-74] | 24 [7-41] | 13 [12-18] | 6 [5-7] | 2 [2-2] | 4 [2-4] |
| 4 | 96 | 175 | 30 [27-30] | 59 [35-90] | 28 [7-46] | 12 [11-17] | 6 [4-6] | 1 [1-1] | 4 [2-6] |
| 5 | 93 | 210 | 29 [27-30] | 73 [44-109] | 28 [8-50] | 15 [10-16] | 5 [3-6] | 1 [1-2] | 4 [2-6] |
| 6 | 89 | 249 | 29 [26-30] | 79 [53-115] | 25 [7-55] | 13 [8-19] | 4 [2-6] | 1 [1-2] | 3 [2-6] |
| 7 | 84 | 322 | 28 [25-30] | 95 [58-133] | 29 [10-59] | 12 [7-17] | 3 [1-5] | 1 [0-1] | 3 [2-8] |
| 8 | 78 | 361 | 28 [25-30] | 106 [71-148] | 34 [12-59] | 14 [6-16] | 2 [1-4] | 1 [0-1] | 3 [2-8] |
| 9 | 72 | 404 | 28 [21-30] | 118 [81-163] | 39 [10-65] | 14 [5-19] | 2 [0-3] | 1 [0-2] | 3 [1-8] |

## greedy (100 runs)

- results: dead 88 (88.0%), won 12 (12.0%)
- run end causes (hull, crew_<cause>, flooded): hull 81, crew_fire 3, flooded 3, crew_combat 1
- killers (share of all runs): gate 40 (40.0%), rival_pursued 24 (24.0%), pursuer 16 (16.0%), gate_pursued 6 (6.0%), rival 2 (2.0%)
- rows reached: 2: 2, 3: 4, 4: 7, 5: 4, 6: 9, 7: 6, 8: 7, 9: 61
- death row (non-wins): 2: 2, 3: 4, 4: 7, 5: 4, 6: 9, 7: 6, 8: 7, 9: 49
- run length s: median 456, p10 325, p90 506
- fights per run: 1: 1, 2: 6, 3: 57, 4: 32, 5: 4
- fight results: died 26, fled 1, gate died 46, gate won 12, won 247
- fight length s: rivals median 41, gate median 64
- gate reached 58 times, won 12 (21%)
- pursuer strikes on overtaken nodes: mean 0.26, runs with any 17%
- pursuer strikes while caught: mean 4.08, runs with any 68%
- pursuer catches: mean 0.88, runs with any 71%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.11, runs with any 11%
- crew lost: mean 0.95, runs with any 47%
- fires started: mean 5.58, runs with any 100%
- nodes overtaken: mean 11.01, runs with any 100%
- crew death causes: combat@gate 30, heat@gate 25, fire@gate 13, fire@combat 11, combat@combat 8, event@dialog 4, heat@combat 2, fire@drill 2
- all: gems gained median 75, ore gained median 116
- winners: gems gained median 104, ore gained median 158
- losers: gems gained median 72, ore gained median 114
- store lines bought (store line: count): crust_trader 0: 19, crust_trader 1: 61, crust_trader 10: 23, crust_trader 11: 11, crust_trader 2: 49, crust_trader 3: 69, crust_trader 4: 8, crust_trader 9: 2

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 27 | 30 [30-30] | 22 [10-36] | 21 [15-26] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 62 | 30 [28-30] | 37 [19-58] | 32 [17-38] | 14 [13-14] | 6 [6-7] | 2 [2-2] | 4 [1-4] |
| 3 | 98 | 134 | 28 [27-30] | 52 [34-79] | 38 [16-52] | 12 [12-13] | 6 [5-7] | 2 [2-2] | 3 [1-5] |
| 4 | 94 | 176 | 27 [24-30] | 69 [43-98] | 40 [9-62] | 11 [10-12] | 5 [4-7] | 1 [1-1] | 2 [0-5] |
| 5 | 87 | 212 | 27 [23-29] | 81 [56-115] | 38 [13-68] | 10 [8-10] | 4 [4-6] | 1 [1-2] | 2 [0-5] |
| 6 | 83 | 280 | 26 [16-29] | 92 [64-132] | 39 [18-76] | 8 [6-9] | 4 [3-5] | 1 [1-2] | 2 [0-5] |
| 7 | 74 | 328 | 25 [16-28] | 112 [77-155] | 41 [19-76] | 6 [5-12] | 3 [2-5] | 1 [0-1] | 2 [0-6] |
| 8 | 68 | 363 | 25 [18-27] | 127 [92-168] | 42 [17-77] | 5 [4-12] | 2 [1-4] | 1 [0-2] | 2 [0-5] |
| 9 | 61 | 421 | 25 [16-27] | 145 [105-184] | 49 [18-83] | 8 [2-12] | 1 [0-3] | 1 [0-2] | 2 [0-5] |

## balanced (100 runs)

- results: dead 81 (81.0%), won 19 (19.0%)
- run end causes (hull, crew_<cause>, flooded): hull 73, crew_heat 4, crew_fire 3, flooded 1
- killers (share of all runs): gate 42 (42.0%), pursuer 21 (21.0%), rival_pursued 10 (10.0%), gate_pursued 5 (5.0%), rival 3 (3.0%)
- rows reached: 2: 1, 3: 1, 4: 2, 5: 3, 6: 5, 7: 7, 8: 6, 9: 75
- death row (non-wins): 2: 1, 3: 1, 4: 2, 5: 3, 6: 5, 7: 7, 8: 6, 9: 56
- run length s: median 474, p10 396, p90 529
- fights per run: 1: 1, 2: 13, 3: 75, 4: 11
- fight results: died 13, fled 4, gate died 47, gate won 19, won 213
- fight length s: rivals median 48, gate median 70
- gate reached 66 times, won 19 (29%)
- pursuer strikes on overtaken nodes: mean 0.18, runs with any 15%
- pursuer strikes while caught: mean 2.88, runs with any 48%
- pursuer catches: mean 0.57, runs with any 50%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.10, runs with any 10%
- crew lost: mean 1.22, runs with any 57%
- fires started: mean 5.14, runs with any 97%
- nodes overtaken: mean 11.47, runs with any 100%
- crew death causes: heat@gate 37, combat@gate 37, combat@combat 21, fire@gate 20, fire@combat 3, fire@drill 3, fire@idle 1
- all: gems gained median 69, ore gained median 114
- winners: gems gained median 85, ore gained median 126
- losers: gems gained median 64, ore gained median 111
- store lines bought (store line: count): crust_trader 0: 64, crust_trader 1: 75, crust_trader 2: 25, crust_trader 3: 124, crust_trader 4: 36, crust_trader 7: 6, crust_trader 8: 2, crust_trader 9: 4

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 26 | 30 [30-30] | 22 [10-35] | 20 [15-26] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 59 | 30 [29-30] | 36 [19-58] | 24 [9-35] | 14 [13-14] | 6 [6-7] | 2 [2-2] | 4 [3-6] |
| 3 | 99 | 101 | 30 [28-30] | 49 [27-74] | 27 [12-42] | 13 [12-13] | 6 [5-7] | 2 [2-2] | 4 [3-6] |
| 4 | 98 | 175 | 29 [27-30] | 64 [39-88] | 31 [14-46] | 11 [10-12] | 5 [4-6] | 1 [1-1] | 4 [2-6] |
| 5 | 96 | 209 | 28 [26-30] | 75 [51-110] | 34 [19-55] | 10 [9-14] | 4 [3-6] | 1 [1-1] | 4 [2-6] |
| 6 | 93 | 251 | 28 [26-30] | 89 [60-127] | 37 [14-64] | 9 [7-14] | 3 [2-5] | 1 [1-1] | 4 [2-7] |
| 7 | 88 | 326 | 27 [25-29] | 100 [75-138] | 42 [22-70] | 8 [6-12] | 2 [1-4] | 0 [0-1] | 3 [2-7] |
| 8 | 81 | 360 | 27 [24-30] | 110 [81-151] | 40 [15-68] | 10 [5-15] | 2 [1-4] | 0 [0-1] | 4 [2-8] |
| 9 | 75 | 400 | 27 [17-30] | 123 [88-168] | 46 [13-76] | 9 [2-14] | 1 [0-3] | 0 [0-1] | 4 [2-7] |

## Events (all bots)

300 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 74 | 247 |
| byrd_signal | 134 | 447 |
| cold_spring | 61 | 203 |
| gas_pocket | 40 | 133 |
| green_gallery | 80 | 267 |
| knocking_pipe | 82 | 273 |
| kola_tapes | 121 | 403 |
| listening_post | 115 | 383 |
| mohole_core | 64 | 213 |
| rival_claim | 92 | 307 |
| shaft_nine | 62 | 207 |
| zarya_wreck | 111 | 370 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 74 | braced: 74 |
| byrd_signal/intro/1 | 134 | mast: 134 |
| cold_spring/intro/1 | 42 | filtered: 42 |
| cold_spring/intro/3 | 19 | drained: 19 |
| gas_pocket/intro/0 | 40 | vented: 40 |
| green_gallery/intro/0 | 48 | amber: 48 |
| green_gallery/intro/1 | 32 | deep: 26, spores: 6 |
| knocking_pipe/intro/0 | 82 | clean: 82 |
| kola_tapes/intro/1 | 121 | strip: 121 |
| listening_post/intro/1 | 10 | trace: 10 |
| listening_post/intro/2 | 105 | decoy: 105 |
| mohole_core/intro/0 | 44 | gas: 6, recovered: 38 |
| mohole_core/intro/2 | 20 | leave: 20 |
| rival_claim/intro/0 | 65 | paid: 65 |
| rival_claim/intro/2 | 15 | fight: 15 |
| rival_claim/intro/3 | 12 | rammed: 9, rammed_bad: 3 |
| shaft_nine/intro/0 | 44 | carts: 44 |
| shaft_nine/intro/2 | 18 | cable: 4, cage: 14 |
| zarya_wreck/intro/0 | 80 | logs: 80 |
| zarya_wreck/intro/2 | 31 | bits: 21, derrick: 10 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1011 | 12/12 | 0 | 11208 | 33 |
| cautious | 1012..1022 | 11/11 | 0 | 11324 | 25 |
| cautious | 1023..1033 | 11/11 | 0 | 11182 | 29 |
| cautious | 1034..1044 | 11/11 | 0 | 10425 | 31 |
| cautious | 1045..1055 | 11/11 | 0 | 10293 | 30 |
| cautious | 1056..1066 | 11/11 | 0 | 10017 | 33 |
| cautious | 1067..1077 | 11/11 | 0 | 8563 | 35 |
| cautious | 1078..1088 | 11/11 | 0 | 8666 | 35 |
| cautious | 1089..1099 | 11/11 | 0 | 9080 | 35 |
| greedy | 1000..1011 | 12/12 | 0 | 11204 | 28 |
| greedy | 1012..1022 | 11/11 | 0 | 11048 | 28 |
| greedy | 1023..1033 | 11/11 | 0 | 10847 | 28 |
| greedy | 1034..1044 | 11/11 | 0 | 10161 | 29 |
| greedy | 1045..1055 | 11/11 | 0 | 10312 | 30 |
| greedy | 1056..1066 | 11/11 | 0 | 10571 | 28 |
| greedy | 1067..1077 | 11/11 | 0 | 11270 | 26 |
| greedy | 1078..1088 | 11/11 | 0 | 11386 | 26 |
| greedy | 1089..1099 | 11/11 | 0 | 11338 | 26 |
| balanced | 1000..1011 | 12/12 | 0 | 10755 | 34 |
| balanced | 1012..1022 | 11/11 | 0 | 10620 | 29 |
| balanced | 1023..1033 | 11/11 | 0 | 10510 | 30 |
| balanced | 1034..1044 | 11/11 | 0 | 9990 | 31 |
| balanced | 1045..1055 | 11/11 | 0 | 9701 | 33 |
| balanced | 1056..1066 | 11/11 | 0 | 9589 | 33 |
| balanced | 1067..1077 | 11/11 | 0 | 10452 | 30 |
| balanced | 1078..1088 | 11/11 | 0 | 10438 | 30 |
| balanced | 1089..1099 | 11/11 | 0 | 10861 | 30 |
