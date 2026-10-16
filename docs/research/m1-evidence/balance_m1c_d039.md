# Full-run balance report 20261016-193749

300 runs (100 per bot, seeds 1000..1099), 6 processes, wall 398 s (6.6 min, 22.1 min per 1000 runs). Pack: 20261016-193745-4e0281d.pck


| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 100 | 16.0 | 0 | 13 | 1351 | 2.74 | 23 | gate 54% |
| greedy | 100 | 9.0 | 0 | 11 | 1076 | 2.67 | 21 | pursuer 26% |
| balanced | 100 | 39.0 | 0 | 13 | 1358 | 2.95 | 49 | gate 35% |

Dig verbs, means per run:

| bot | rockfalls hit | absorbed | hull lost to them | blasts | blast ore | blast gems | douses | s past 60 deg |
|---|---|---|---|---|---|---|---|---|
| cautious | 0.31 | 4.16 | 0.31 | 1.84 | 1.28 | 0.13 | 3.31 | 0 |
| greedy | 4.47 | 6.81 | 4.47 | 7.80 | 121.56 | 17.62 | 2.71 | 94 |
| balanced | 2.35 | 6.22 | 2.35 | 6.61 | 114.51 | 15.68 | 3.61 | 0 |

## cautious (100 runs)

- results: dead 84 (84.0%), won 16 (16.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 47, crew_combat 20, crew_fire 9, hull 8
- killers (share of all runs): gate 54 (54.0%), rival 18 (18.0%), drill_crew_heat 6 (6.0%), pursuer 3 (3.0%), drill_crew_fire 2 (2.0%), drill_crew_combat 1 (1.0%)
- rows reached: 6: 1, 7: 4, 8: 3, 9: 3, 10: 8, 11: 7, 12: 4, 13: 70
- death row (non-wins): 6: 1, 7: 4, 8: 3, 9: 3, 10: 8, 11: 7, 12: 4, 13: 54
- run length s: median 1351, p10 1018, p90 1443
- fights per run: 1: 9, 2: 19, 3: 61, 4: 11
- fight results: died 18, fled 3, gate died 54, gate won 16, won 183
- fight length s: rivals median 53, gate median 58
- gate reached 70 times, won 16 (23%)
- pursuer strikes on overtaken nodes: mean 0.03, runs with any 3%
- pursuer strikes while caught: mean 0.36, runs with any 5%
- pursuer catches: mean 0.09, runs with any 7%
- bit breaks: mean 0.12, runs with any 12%
- coolant outs: mean 0.15, runs with any 15%
- crew lost: mean 2.83, runs with any 94%
- fires started: mean 6.76, runs with any 100%
- nodes overtaken: mean 16.19, runs with any 100%
- rockfalls hit: mean 0.31, runs with any 28%
- rockfalls absorbed: mean 4.16, runs with any 95%
- hull lost to rockfalls: mean 0.31, runs with any 28%
- blasts: mean 1.84, runs with any 89%
- ore from blasts: mean 1.28, runs with any 19%
- gems from blasts: mean 0.13, runs with any 5%
- douses: mean 3.31, runs with any 92%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- crew death causes: heat@gate 126, combat@gate 46, heat@combat 30, heat@drill 26, combat@combat 25, fire@combat 13, fire@gate 10, fire@drill 5, heat@idle 2
- all: gems gained median 138, ore gained median 1222
- winners: gems gained median 170, ore gained median 1390
- losers: gems gained median 133, ore gained median 1208
- store lines bought (store line: count): crust_trader 0: 271, crust_trader 1: 114, crust_trader 13: 94, crust_trader 15: 146, crust_trader 16: 89, crust_trader 2: 182, crust_trader 3: 170, crust_trader 4: 139, crust_trader 7: 64, crust_trader 8: 60, crust_trader 9: 20

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 40 [35-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 81 | 40 [30-40] | 56 [22-102] | 15 [15-23] | 14 [14-14] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 100 | 188 | 35 [29-40] | 126 [63-202] | 21 [4-30] | 12 [11-17] | 10 [10-11] | 2 [2-2] | 4 [3-4] |
| 3 | 100 | 296 | 35 [29-40] | 174 [103-269] | 23 [3-43] | 11 [10-15] | 10 [9-11] | 1 [1-1] | 4 [2-4] |
| 4 | 100 | 396 | 35 [28-40] | 235 [144-338] | 22 [5-47] | 13 [8-18] | 10 [8-10] | 1 [1-1] | 3 [2-4] |
| 5 | 100 | 512 | 30 [28-40] | 250 [135-399] | 21 [5-48] | 12 [7-17] | 9 [9-10] | 1 [0-2] | 3 [2-5] |
| 6 | 100 | 618 | 30 [27-40] | 344 [187-510] | 30 [9-66] | 10 [5-15] | 8 [8-9] | 0 [0-1] | 3 [2-4] |
| 7 | 99 | 721 | 30 [26-40] | 370 [166-706] | 36 [6-77] | 12 [4-17] | 7 [7-9] | 1 [0-2] | 3 [2-6] |
| 8 | 95 | 824 | 30 [25-35] | 337 [164-642] | 37 [8-79] | 14 [6-17] | 6 [6-8] | 1 [0-2] | 4 [2-6] |
| 9 | 92 | 920 | 35 [28-35] | 333 [179-598] | 39 [14-74] | 14 [11-17] | 5 [5-7] | 1 [0-2] | 4 [2-7] |
| 10 | 89 | 1025 | 33 [25-35] | 440 [258-766] | 56 [22-90] | 12 [8-16] | 4 [4-6] | 1 [0-2] | 3 [2-6] |
| 11 | 81 | 1119 | 35 [25-40] | 482 [142-809] | 58 [15-101] | 13 [7-18] | 3 [3-5] | 1 [0-2] | 4 [2-8] |
| 12 | 74 | 1225 | 35 [25-40] | 345 [163-842] | 58 [9-97] | 14 [6-17] | 3 [2-5] | 1 [0-2] | 6 [2-8] |
| 13 | 70 | 1312 | 35 [32-40] | 350 [146-539] | 52 [10-101] | 15 [10-19] | 2 [1-4] | 1 [1-2] | 7 [3-9] |

## greedy (100 runs)

- results: dead 91 (91.0%), won 9 (9.0%)
- run end causes (hull, crew_<cause>, flooded): hull 47, crew_heat 29, crew_fire 10, crew_combat 5
- killers (share of all runs): pursuer 26 (26.0%), gate 24 (24.0%), drill_crew_heat 15 (15.0%), gate_pursued 9 (9.0%), rival 9 (9.0%), rival_pursued 4 (4.0%), drill_crew_combat 2 (2.0%), drill_crew_fire 2 (2.0%)
- rows reached: 7: 6, 8: 8, 9: 7, 10: 12, 11: 18, 12: 7, 13: 42
- death row (non-wins): 7: 6, 8: 8, 9: 7, 10: 12, 11: 18, 12: 7, 13: 33
- run length s: median 1076, p10 862, p90 1172
- fights per run: 1: 7, 2: 31, 3: 50, 4: 12
- fight results: died 13, fled 3, gate died 33, gate won 9, won 209
- fight length s: rivals median 41, gate median 47
- gate reached 42 times, won 9 (21%)
- pursuer strikes on overtaken nodes: mean 0.19, runs with any 17%
- pursuer strikes while caught: mean 3.07, runs with any 57%
- pursuer catches: mean 0.75, runs with any 60%
- bit breaks: mean 0.02, runs with any 2%
- coolant outs: mean 0.30, runs with any 30%
- crew lost: mean 2.01, runs with any 81%
- fires started: mean 7.96, runs with any 100%
- nodes overtaken: mean 16.24, runs with any 100%
- rockfalls hit: mean 4.47, runs with any 97%
- rockfalls absorbed: mean 6.81, runs with any 100%
- hull lost to rockfalls: mean 4.47, runs with any 97%
- blasts: mean 7.80, runs with any 98%
- ore from blasts: mean 121.56, runs with any 98%
- gems from blasts: mean 17.62, runs with any 88%
- douses: mean 2.71, runs with any 89%
- drilling s past 60 degrees: mean 94.29, runs with any 100%
- crew death causes: heat@drill 87, heat@gate 41, combat@combat 20, combat@gate 17, fire@gate 14, fire@drill 8, heat@combat 6, event@dialog 5, fire@combat 3
- all: gems gained median 191, ore gained median 1972
- winners: gems gained median 239, ore gained median 2327
- losers: gems gained median 182, ore gained median 1918
- store lines bought (store line: count): crust_trader 0: 163, crust_trader 1: 84, crust_trader 10: 95, crust_trader 11: 89, crust_trader 13: 97, crust_trader 14: 85, crust_trader 15: 65, crust_trader 2: 181, crust_trader 3: 246, crust_trader 4: 31, crust_trader 5: 36, crust_trader 9: 100

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 35 [30-35] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 78 | 35 [29-35] | 98 [63-161] | 19 [15-27] | 14 [13-14] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 100 | 186 | 29 [27-35] | 230 [161-302] | 23 [17-35] | 12 [11-12] | 10 [10-11] | 2 [2-2] | 3 [1-4] |
| 3 | 100 | 284 | 29 [26-35] | 297 [125-434] | 32 [13-48] | 10 [9-11] | 10 [9-10] | 1 [1-1] | 3 [1-6] |
| 4 | 100 | 370 | 28 [25-35] | 352 [212-545] | 32 [12-57] | 8 [6-9] | 9 [8-9] | 1 [1-2] | 3 [2-5] |
| 5 | 100 | 468 | 27 [24-29] | 400 [213-579] | 30 [14-62] | 7 [5-10] | 8 [8-9] | 1 [1-2] | 3 [2-5] |
| 6 | 100 | 567 | 26 [22-29] | 509 [331-758] | 56 [25-92] | 5 [3-9] | 7 [7-8] | 1 [1-2] | 3 [0-3] |
| 7 | 100 | 650 | 25 [20-28] | 600 [189-939] | 68 [27-110] | 5 [1-9] | 6 [6-8] | 1 [0-2] | 3 [0-4] |
| 8 | 94 | 727 | 24 [19-28] | 446 [207-954] | 68 [36-125] | 6 [0-10] | 5 [5-7] | 2 [1-2] | 3 [1-4] |
| 9 | 86 | 804 | 23 [18-28] | 490 [274-815] | 74 [36-118] | 7 [3-10] | 4 [4-7] | 2 [1-2] | 3 [1-4] |
| 10 | 79 | 884 | 23 [17-28] | 665 [388-941] | 93 [38-150] | 6 [2-8] | 4 [3-6] | 2 [1-2] | 3 [1-3] |
| 11 | 67 | 956 | 23 [12-29] | 653 [321-1069] | 98 [37-150] | 6 [2-11] | 3 [2-5] | 2 [1-2] | 3 [1-5] |
| 12 | 49 | 1017 | 23 [13-31] | 589 [419-1015] | 92 [31-156] | 7 [2-10] | 2 [1-4] | 2 [1-2] | 3 [1-5] |
| 13 | 42 | 1100 | 26 [13-31] | 788 [517-1137] | 88 [45-162] | 7 [2-11] | 1 [0-3] | 2 [1-2] | 3 [1-5] |

## balanced (100 runs)

- results: dead 61 (61.0%), won 39 (39.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 33, hull 10, crew_combat 10, crew_fire 8
- killers (share of all runs): gate 35 (35.0%), rival 10 (10.0%), drill_crew_heat 7 (7.0%), gate_pursued 6 (6.0%), drill_crew_fire 1 (1.0%), drill_crew_combat 1 (1.0%), pursuer 1 (1.0%)
- rows reached: 7: 6, 8: 1, 9: 2, 10: 2, 11: 6, 12: 3, 13: 80
- death row (non-wins): 7: 6, 8: 1, 9: 2, 10: 2, 11: 6, 12: 3, 13: 41
- run length s: median 1358, p10 1106, p90 1451
- fights per run: 1: 5, 2: 13, 3: 64, 4: 18
- fight results: died 10, fled 4, gate died 41, gate won 39, won 201
- fight length s: rivals median 57, gate median 66
- gate reached 80 times, won 39 (49%)
- pursuer strikes on overtaken nodes: mean 0.00, runs with any 0%
- pursuer strikes while caught: mean 0.47, runs with any 14%
- pursuer catches: mean 0.17, runs with any 17%
- bit breaks: mean 0.08, runs with any 8%
- coolant outs: mean 0.15, runs with any 15%
- crew lost: mean 2.23, runs with any 85%
- fires started: mean 7.57, runs with any 100%
- nodes overtaken: mean 16.67, runs with any 100%
- rockfalls hit: mean 2.35, runs with any 88%
- rockfalls absorbed: mean 6.22, runs with any 100%
- hull lost to rockfalls: mean 2.35, runs with any 88%
- blasts: mean 6.61, runs with any 100%
- ore from blasts: mean 114.51, runs with any 100%
- gems from blasts: mean 15.68, runs with any 79%
- douses: mean 3.61, runs with any 93%
- drilling s past 60 degrees: mean 0.00, runs with any 0%
- crew death causes: heat@gate 99, combat@gate 41, heat@drill 23, combat@combat 20, heat@combat 15, fire@gate 15, fire@combat 6, heat@idle 3, fire@drill 1
- all: gems gained median 168, ore gained median 1723
- winners: gems gained median 191, ore gained median 1802
- losers: gems gained median 153, ore gained median 1589
- store lines bought (store line: count): crust_trader 0: 250, crust_trader 1: 92, crust_trader 10: 20, crust_trader 13: 95, crust_trader 14: 15, crust_trader 15: 155, crust_trader 16: 89, crust_trader 2: 169, crust_trader 3: 277, crust_trader 4: 125, crust_trader 5: 28, crust_trader 7: 64, crust_trader 8: 93, crust_trader 9: 109

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 40 [35-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 84 | 38 [29-40] | 81 [44-129] | 17 [15-23] | 14 [13-14] | 11 [11-11] | 2 [2-2] | 4 [3-4] |
| 2 | 100 | 192 | 35 [28-40] | 184 [123-256] | 21 [15-31] | 12 [11-12] | 10 [10-11] | 2 [2-2] | 4 [2-4] |
| 3 | 100 | 301 | 29 [26-40] | 237 [137-349] | 27 [10-48] | 10 [9-11] | 10 [9-10] | 1 [1-1] | 4 [2-6] |
| 4 | 100 | 400 | 29 [27-40] | 282 [173-422] | 30 [9-50] | 9 [7-14] | 9 [8-9] | 1 [1-1] | 3 [3-5] |
| 5 | 100 | 506 | 29 [27-40] | 304 [154-473] | 29 [11-56] | 11 [6-12] | 8 [8-9] | 1 [0-1] | 3 [3-5] |
| 6 | 100 | 616 | 28 [25-35] | 394 [243-600] | 48 [20-78] | 9 [3-11] | 7 [7-9] | 0 [0-1] | 3 [2-4] |
| 7 | 100 | 706 | 27 [25-33] | 460 [175-791] | 56 [22-103] | 8 [2-13] | 6 [6-8] | 0 [0-1] | 3 [2-4] |
| 8 | 94 | 795 | 28 [25-33] | 358 [160-785] | 57 [22-111] | 10 [4-14] | 5 [5-7] | 0 [0-1] | 3 [2-4] |
| 9 | 93 | 887 | 32 [25-34] | 345 [155-626] | 61 [25-103] | 10 [7-13] | 4 [4-6] | 1 [0-1] | 3 [2-4] |
| 10 | 91 | 1005 | 31 [23-33] | 459 [307-751] | 74 [36-125] | 9 [5-12] | 3 [3-5] | 0 [0-1] | 3 [2-3] |
| 11 | 89 | 1096 | 32 [23-37] | 504 [203-924] | 75 [30-135] | 10 [4-13] | 2 [2-4] | 0 [0-1] | 3 [2-6] |
| 12 | 83 | 1205 | 32 [23-40] | 376 [184-881] | 69 [39-121] | 11 [3-14] | 2 [1-4] | 0 [0-1] | 3 [2-7] |
| 13 | 80 | 1301 | 38 [31-40] | 355 [196-596] | 73 [35-119] | 11 [7-14] | 1 [0-3] | 1 [0-1] | 3 [2-6] |

## Events (all bots)

300 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 75 | 250 |
| byrd_signal | 85 | 283 |
| cold_spring | 44 | 147 |
| gas_pocket | 54 | 180 |
| green_gallery | 74 | 247 |
| knocking_pipe | 56 | 187 |
| kola_tapes | 65 | 217 |
| listening_post | 44 | 147 |
| mohole_core | 70 | 233 |
| rival_claim | 51 | 170 |
| shaft_nine | 82 | 273 |
| zarya_wreck | 67 | 223 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 35 | braced: 35 |
| blind_aquifer/intro/1 | 24 | grouted: 24 |
| blind_aquifer/intro/2 | 16 | burst: 12, rode: 4 |
| byrd_signal/intro/0 | 1 | answer: 1 |
| byrd_signal/intro/1 | 47 | mast: 47 |
| byrd_signal/intro/2 | 37 | silence: 37 |
| cold_spring/intro/1 | 32 | filtered: 32 |
| cold_spring/intro/3 | 12 | drained: 12 |
| gas_pocket/intro/0 | 54 | vented: 54 |
| green_gallery/intro/0 | 51 | amber: 51 |
| green_gallery/intro/1 | 23 | deep: 19, spores: 4 |
| knocking_pipe/intro/0 | 56 | clean: 56 |
| kola_tapes/intro/1 | 65 | strip: 65 |
| listening_post/intro/1 | 1 | trace: 1 |
| listening_post/intro/2 | 43 | decoy: 43 |
| mohole_core/intro/0 | 42 | gas: 5, recovered: 37 |
| mohole_core/intro/2 | 28 | leave: 28 |
| rival_claim/intro/0 | 30 | paid: 30 |
| rival_claim/intro/2 | 21 | fight: 21 |
| shaft_nine/intro/0 | 26 | carts: 26 |
| shaft_nine/intro/1 | 32 | coolant: 26, sludge: 6 |
| shaft_nine/intro/2 | 24 | cable: 5, cage: 19 |
| zarya_wreck/intro/0 | 47 | logs: 47 |
| zarya_wreck/intro/2 | 20 | bits: 13, derrick: 7 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1009 | 10/10 | 0 | 9221 | 90 |
| cautious | 1010..1019 | 10/10 | 0 | 8869 | 84 |
| cautious | 1020..1029 | 10/10 | 0 | 8997 | 87 |
| cautious | 1030..1039 | 10/10 | 0 | 9056 | 91 |
| cautious | 1040..1049 | 10/10 | 0 | 9021 | 88 |
| cautious | 1050..1059 | 10/10 | 0 | 9136 | 87 |
| cautious | 1060..1069 | 10/10 | 0 | 11006 | 73 |
| cautious | 1070..1079 | 10/10 | 0 | 10833 | 74 |
| cautious | 1080..1089 | 10/10 | 0 | 10834 | 70 |
| cautious | 1090..1099 | 10/10 | 0 | 10921 | 71 |
| greedy | 1000..1009 | 10/10 | 0 | 9915 | 64 |
| greedy | 1010..1019 | 10/10 | 0 | 9891 | 66 |
| greedy | 1020..1029 | 10/10 | 0 | 9536 | 63 |
| greedy | 1030..1039 | 10/10 | 0 | 9292 | 70 |
| greedy | 1040..1049 | 10/10 | 0 | 9416 | 67 |
| greedy | 1050..1059 | 10/10 | 0 | 9462 | 66 |
| greedy | 1060..1069 | 10/10 | 0 | 9622 | 70 |
| greedy | 1070..1079 | 10/10 | 0 | 9621 | 66 |
| greedy | 1080..1089 | 10/10 | 0 | 9062 | 73 |
| greedy | 1090..1099 | 10/10 | 0 | 9279 | 68 |
| balanced | 1000..1009 | 10/10 | 0 | 9421 | 86 |
| balanced | 1010..1019 | 10/10 | 0 | 9502 | 87 |
| balanced | 1020..1029 | 10/10 | 0 | 9529 | 85 |
| balanced | 1030..1039 | 10/10 | 0 | 9277 | 85 |
| balanced | 1040..1049 | 10/10 | 0 | 10020 | 79 |
| balanced | 1050..1059 | 10/10 | 0 | 10058 | 78 |
| balanced | 1060..1069 | 10/10 | 0 | 9657 | 86 |
| balanced | 1070..1079 | 10/10 | 0 | 9809 | 80 |
| balanced | 1080..1089 | 10/10 | 0 | 9542 | 85 |
| balanced | 1090..1099 | 10/10 | 0 | 9908 | 80 |
