# Full-run balance report 20261015-205835

1002 runs (334 per bot, seeds 1000..1333), 6 processes, wall 740 s (12.3 min, 12.3 min per 1000 runs). Pack: 20261015-205829-5727fbc.pck
Another Godot was running during the batch: wall time untrusted.

| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 334 | 21.0 | 0 | 9 | 482 | 2.87 | 28 | gate 44% |
| greedy | 334 | 12.9 | 0 | 9 | 464 | 3.28 | 21 | gate 38% |
| balanced | 334 | 25.4 | 0 | 9 | 477 | 2.94 | 34 | gate 42% |

## cautious (334 runs)

- results: dead 264 (79.0%), won 70 (21.0%)
- run end causes (hull, crew_<cause>, flooded): hull 257, crew_heat 3, crew_combat 2, crew_fire 1, flooded 1
- killers (share of all runs): gate 148 (44.3%), pursuer 65 (19.5%), gate_pursued 28 (8.4%), rival_pursued 21 (6.3%), rival 2 (0.6%)
- rows reached: 2: 2, 3: 7, 4: 6, 5: 20, 6: 15, 7: 16, 8: 17, 9: 251
- death row (non-wins): 2: 2, 3: 7, 4: 6, 5: 20, 6: 15, 7: 16, 8: 17, 9: 181
- run length s: median 482, p10 365, p90 532
- fights per run: 1: 4, 2: 62, 3: 243, 4: 25
- fight results: died 23, fled 7, gate died 176, gate won 70, won 681
- fight length s: rivals median 49, gate median 76
- gate reached 246 times, won 70 (28%)
- pursuer strikes on overtaken nodes: mean 0.19, runs with any 16%
- pursuer strikes while caught: mean 2.61, runs with any 48%
- pursuer catches: mean 0.61, runs with any 54%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.05, runs with any 5%
- crew lost: mean 0.88, runs with any 45%
- fires started: mean 3.11, runs with any 96%
- nodes overtaken: mean 11.49, runs with any 100%
- crew death causes: heat@gate 105, combat@gate 96, combat@combat 51, fire@gate 35, fire@combat 3, fire@drill 3
- all: gems gained median 64, ore gained median 108
- winners: gems gained median 93, ore gained median 130
- losers: gems gained median 58, ore gained median 103
- store lines bought (store line: count): crust_trader 0: 340, crust_trader 1: 256, crust_trader 2: 196, crust_trader 3: 211, crust_trader 4: 190, crust_trader 7: 1

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 334 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 334 | 26 | 30 [30-30] | 20 [10-35] | 20 [15-25] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 334 | 58 | 30 [30-30] | 33 [12-55] | 24 [6-33] | 14 [14-19] | 6 [6-8] | 2 [2-2] | 4 [4-4] |
| 3 | 332 | 97 | 30 [28-30] | 47 [23-73] | 25 [7-41] | 13 [12-18] | 6 [5-7] | 2 [2-2] | 4 [2-4] |
| 4 | 325 | 174 | 30 [27-30] | 58 [33-91] | 28 [7-47] | 12 [11-17] | 6 [4-6] | 1 [1-1] | 4 [2-6] |
| 5 | 319 | 207 | 29 [26-30] | 71 [43-108] | 30 [9-56] | 14 [9-16] | 5 [3-6] | 1 [1-2] | 4 [2-6] |
| 6 | 299 | 245 | 29 [25-30] | 80 [52-118] | 27 [7-60] | 14 [8-19] | 4 [2-5] | 1 [1-2] | 3 [2-6] |
| 7 | 284 | 315 | 28 [22-30] | 94 [60-135] | 31 [7-65] | 12 [6-18] | 3 [1-5] | 1 [0-1] | 3 [2-7] |
| 8 | 268 | 359 | 28 [20-30] | 105 [69-151] | 35 [11-62] | 13 [6-17] | 2 [1-4] | 1 [0-1] | 3 [2-7] |
| 9 | 251 | 403 | 28 [19-30] | 119 [76-162] | 36 [10-67] | 14 [5-19] | 1 [1-3] | 1 [0-2] | 3 [1-8] |

## greedy (334 runs)

- results: dead 291 (87.1%), won 43 (12.9%)
- run end causes (hull, crew_<cause>, flooded): hull 281, flooded 5, crew_fire 3, crew_combat 2
- killers (share of all runs): gate 127 (38.0%), rival_pursued 69 (20.7%), pursuer 58 (17.4%), gate_pursued 34 (10.2%), event 1 (0.3%), rival 1 (0.3%), drill_crew_fire 1 (0.3%)
- rows reached: 1: 2, 2: 5, 3: 15, 4: 18, 5: 12, 6: 26, 7: 18, 8: 21, 9: 217
- death row (non-wins): 1: 2, 2: 5, 3: 15, 4: 18, 5: 12, 6: 26, 7: 18, 8: 21, 9: 174
- run length s: median 464, p10 319, p90 513
- fights per run: 1: 7, 2: 14, 3: 198, 4: 107, 5: 8
- fight results: died 70, fled 1, gate died 161, gate won 43, won 822
- fight length s: rivals median 41, gate median 67
- gate reached 204 times, won 43 (21%)
- pursuer strikes on overtaken nodes: mean 0.25, runs with any 19%
- pursuer strikes while caught: mean 3.98, runs with any 67%
- pursuer catches: mean 0.99, runs with any 73%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.05, runs with any 5%
- crew lost: mean 0.61, runs with any 32%
- fires started: mean 3.10, runs with any 95%
- nodes overtaken: mean 11.15, runs with any 100%
- crew death causes: combat@gate 68, heat@gate 44, combat@combat 43, fire@gate 20, event@dialog 18, fire@combat 9, fire@drill 2, heat@combat 1
- all: gems gained median 75, ore gained median 121
- winners: gems gained median 103, ore gained median 154
- losers: gems gained median 72, ore gained median 118
- store lines bought (store line: count): crust_trader 0: 59, crust_trader 1: 188, crust_trader 10: 78, crust_trader 11: 48, crust_trader 2: 162, crust_trader 3: 224, crust_trader 4: 22, crust_trader 9: 5

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 334 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 334 | 27 | 30 [30-30] | 20 [10-38] | 21 [15-26] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 332 | 62 | 30 [28-30] | 36 [17-58] | 30 [17-39] | 14 [13-14] | 6 [6-7] | 2 [2-2] | 4 [1-4] |
| 3 | 327 | 133 | 28 [26-30] | 51 [30-79] | 36 [17-52] | 12 [11-13] | 6 [5-7] | 2 [2-2] | 3 [1-4] |
| 4 | 312 | 176 | 28 [24-30] | 68 [41-96] | 42 [12-60] | 11 [10-12] | 5 [4-7] | 1 [1-1] | 2 [1-5] |
| 5 | 294 | 213 | 27 [23-30] | 82 [53-116] | 44 [15-68] | 10 [9-11] | 4 [3-6] | 1 [1-2] | 2 [0-5] |
| 6 | 282 | 278 | 26 [20-29] | 97 [64-138] | 42 [16-71] | 8 [7-10] | 4 [3-5] | 1 [1-2] | 2 [0-5] |
| 7 | 256 | 329 | 25 [16-28] | 113 [77-156] | 43 [15-78] | 7 [5-14] | 3 [2-5] | 1 [0-1] | 2 [0-6] |
| 8 | 238 | 365 | 25 [15-28] | 127 [91-170] | 46 [16-83] | 6 [4-13] | 2 [1-4] | 1 [0-2] | 2 [0-6] |
| 9 | 217 | 416 | 24 [13-27] | 141 [103-185] | 46 [14-88] | 7 [3-12] | 1 [0-3] | 1 [0-2] | 2 [0-6] |

## balanced (334 runs)

- results: dead 249 (74.6%), won 85 (25.4%)
- run end causes (hull, crew_<cause>, flooded): hull 239, crew_fire 4, crew_heat 3, flooded 2, crew_combat 1
- killers (share of all runs): gate 140 (41.9%), pursuer 58 (17.4%), rival_pursued 26 (7.8%), gate_pursued 24 (7.2%), rival 1 (0.3%)
- rows reached: 2: 3, 3: 3, 4: 7, 5: 10, 6: 14, 7: 14, 8: 18, 9: 265
- death row (non-wins): 2: 3, 3: 3, 4: 7, 5: 10, 6: 14, 7: 14, 8: 18, 9: 180
- run length s: median 477, p10 410, p90 532
- fights per run: 1: 5, 2: 48, 3: 244, 4: 36, 5: 1
- fight results: died 27, fled 4, gate died 164, gate won 85, won 702
- fight length s: rivals median 48, gate median 72
- gate reached 249 times, won 85 (34%)
- pursuer strikes on overtaken nodes: mean 0.19, runs with any 15%
- pursuer strikes while caught: mean 2.58, runs with any 45%
- pursuer catches: mean 0.56, runs with any 51%
- bit breaks: mean 0.00, runs with any 0%
- coolant outs: mean 0.08, runs with any 8%
- crew lost: mean 0.81, runs with any 41%
- fires started: mean 3.11, runs with any 93%
- nodes overtaken: mean 11.59, runs with any 100%
- crew death causes: heat@gate 110, combat@gate 78, fire@gate 38, combat@combat 34, fire@combat 8, fire@drill 2
- all: gems gained median 70, ore gained median 119
- winners: gems gained median 92, ore gained median 140
- losers: gems gained median 64, ore gained median 113
- store lines bought (store line: count): crust_trader 0: 194, crust_trader 1: 242, crust_trader 2: 76, crust_trader 3: 401, crust_trader 4: 115, crust_trader 7: 31, crust_trader 8: 7, crust_trader 9: 9

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 334 | 0 | 30 [30-30] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 8 [8-8] | 2 [2-2] | 4 [4-4] |
| 1 | 334 | 26 | 30 [30-30] | 20 [10-35] | 20 [15-26] | 14 [14-14] | 7 [7-7] | 2 [2-2] | 4 [4-4] |
| 2 | 334 | 58 | 30 [29-30] | 34 [15-58] | 24 [9-34] | 14 [13-14] | 6 [6-7] | 2 [2-2] | 4 [3-6] |
| 3 | 331 | 100 | 30 [27-30] | 49 [24-75] | 27 [12-43] | 13 [12-13] | 6 [5-7] | 2 [2-2] | 4 [3-6] |
| 4 | 328 | 174 | 29 [27-30] | 62 [35-92] | 32 [16-50] | 11 [11-12] | 5 [4-6] | 1 [1-1] | 4 [2-6] |
| 5 | 321 | 207 | 28 [25-30] | 75 [47-111] | 36 [19-58] | 10 [9-14] | 4 [3-6] | 1 [1-1] | 4 [2-6] |
| 6 | 311 | 246 | 28 [25-30] | 90 [59-129] | 38 [16-61] | 9 [8-14] | 3 [2-5] | 1 [1-1] | 4 [2-8] |
| 7 | 297 | 323 | 27 [24-29] | 102 [72-144] | 42 [19-69] | 9 [6-13] | 2 [2-4] | 0 [0-1] | 4 [2-8] |
| 8 | 283 | 358 | 27 [22-30] | 117 [80-159] | 41 [16-71] | 10 [5-14] | 2 [1-3] | 0 [0-1] | 4 [2-8] |
| 9 | 265 | 400 | 27 [20-30] | 130 [90-175] | 45 [16-78] | 9 [3-15] | 1 [0-3] | 0 [0-1] | 4 [2-8] |

## Events (all bots)

1002 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 227 | 227 |
| byrd_signal | 446 | 445 |
| cold_spring | 230 | 230 |
| gas_pocket | 163 | 163 |
| green_gallery | 304 | 303 |
| knocking_pipe | 304 | 303 |
| kola_tapes | 412 | 411 |
| listening_post | 386 | 385 |
| mohole_core | 272 | 271 |
| rival_claim | 287 | 286 |
| shaft_nine | 232 | 232 |
| zarya_wreck | 400 | 399 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 227 | braced: 227 |
| byrd_signal/intro/0 | 1 | answer: 1 |
| byrd_signal/intro/1 | 445 | mast: 445 |
| cold_spring/intro/1 | 160 | filtered: 160 |
| cold_spring/intro/3 | 70 | drained: 70 |
| gas_pocket/intro/0 | 163 | vented: 163 |
| green_gallery/intro/0 | 197 | amber: 197 |
| green_gallery/intro/1 | 107 | deep: 82, spores: 25 |
| knocking_pipe/intro/0 | 304 | clean: 304 |
| kola_tapes/intro/1 | 412 | strip: 412 |
| listening_post/intro/1 | 27 | trace: 27 |
| listening_post/intro/2 | 359 | decoy: 359 |
| mohole_core/intro/0 | 187 | gas: 32, recovered: 155 |
| mohole_core/intro/2 | 85 | leave: 85 |
| rival_claim/intro/0 | 200 | paid: 200 |
| rival_claim/intro/2 | 52 | fight: 52 |
| rival_claim/intro/3 | 35 | rammed: 23, rammed_bad: 12 |
| shaft_nine/intro/0 | 160 | carts: 160 |
| shaft_nine/intro/2 | 72 | cable: 18, cage: 54 |
| zarya_wreck/intro/0 | 287 | logs: 287 |
| zarya_wreck/intro/2 | 113 | bits: 86, derrick: 27 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1018 | 19/19 | 0 | 7922 | 69 |
| cautious | 1019..1037 | 19/19 | 0 | 8054 | 68 |
| cautious | 1038..1056 | 19/19 | 0 | 7986 | 69 |
| cautious | 1057..1075 | 19/19 | 0 | 8016 | 68 |
| cautious | 1076..1094 | 19/19 | 0 | 7948 | 66 |
| cautious | 1095..1113 | 19/19 | 0 | 7957 | 65 |
| cautious | 1114..1132 | 19/19 | 0 | 8171 | 67 |
| cautious | 1133..1151 | 19/19 | 0 | 8074 | 67 |
| cautious | 1152..1170 | 19/19 | 0 | 8164 | 65 |
| cautious | 1171..1189 | 19/19 | 0 | 8084 | 66 |
| cautious | 1190..1207 | 18/18 | 0 | 8044 | 64 |
| cautious | 1208..1225 | 18/18 | 0 | 8120 | 63 |
| cautious | 1226..1243 | 18/18 | 0 | 5678 | 92 |
| cautious | 1244..1261 | 18/18 | 0 | 5935 | 87 |
| cautious | 1262..1279 | 18/18 | 0 | 5947 | 85 |
| cautious | 1280..1297 | 18/18 | 0 | 5712 | 91 |
| cautious | 1298..1315 | 18/18 | 0 | 5907 | 90 |
| cautious | 1316..1333 | 18/18 | 0 | 5716 | 88 |
| greedy | 1000..1018 | 19/19 | 0 | 7584 | 67 |
| greedy | 1019..1037 | 19/19 | 0 | 7399 | 73 |
| greedy | 1038..1056 | 19/19 | 0 | 7353 | 74 |
| greedy | 1057..1075 | 19/19 | 0 | 7357 | 68 |
| greedy | 1076..1094 | 19/19 | 0 | 7429 | 68 |
| greedy | 1095..1113 | 19/19 | 0 | 7528 | 65 |
| greedy | 1114..1132 | 19/19 | 0 | 5623 | 88 |
| greedy | 1133..1151 | 19/19 | 0 | 5790 | 90 |
| greedy | 1152..1170 | 19/19 | 0 | 5867 | 87 |
| greedy | 1171..1189 | 19/19 | 0 | 5775 | 92 |
| greedy | 1190..1207 | 18/18 | 0 | 5737 | 87 |
| greedy | 1208..1225 | 18/18 | 0 | 5783 | 87 |
| greedy | 1226..1243 | 18/18 | 0 | 5968 | 84 |
| greedy | 1244..1261 | 18/18 | 0 | 5752 | 86 |
| greedy | 1262..1279 | 18/18 | 0 | 5688 | 83 |
| greedy | 1280..1297 | 18/18 | 0 | 5679 | 86 |
| greedy | 1298..1315 | 18/18 | 0 | 5751 | 79 |
| greedy | 1316..1333 | 18/18 | 0 | 5747 | 82 |
| balanced | 1000..1018 | 19/19 | 0 | 6519 | 85 |
| balanced | 1019..1037 | 19/19 | 0 | 6813 | 82 |
| balanced | 1038..1056 | 19/19 | 0 | 6744 | 81 |
| balanced | 1057..1075 | 19/19 | 0 | 6761 | 80 |
| balanced | 1076..1094 | 19/19 | 0 | 6791 | 77 |
| balanced | 1095..1113 | 19/19 | 0 | 6685 | 79 |
| balanced | 1114..1132 | 19/19 | 0 | 4781 | 112 |
| balanced | 1133..1151 | 19/19 | 0 | 4796 | 115 |
| balanced | 1152..1170 | 19/19 | 0 | 4806 | 114 |
| balanced | 1171..1189 | 19/19 | 0 | 4807 | 114 |
| balanced | 1190..1207 | 18/18 | 0 | 4772 | 108 |
| balanced | 1208..1225 | 18/18 | 0 | 4691 | 108 |
| balanced | 1226..1243 | 18/18 | 0 | 6113 | 86 |
| balanced | 1244..1261 | 18/18 | 0 | 6153 | 82 |
| balanced | 1262..1279 | 18/18 | 0 | 6122 | 85 |
| balanced | 1280..1297 | 18/18 | 0 | 6265 | 83 |
| balanced | 1298..1315 | 18/18 | 0 | 6402 | 81 |
| balanced | 1316..1333 | 18/18 | 0 | 6415 | 82 |
