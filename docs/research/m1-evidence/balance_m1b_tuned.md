# M1b: longer, mining-first runs, balance check (300 runs)

Ask (lead, after Stewart's "way longer"): the Crust at 14 rows with three store windows and 2 fights
per path, median runs of 17 to 25 min, wins about 15 to 30% for balanced and 8 to 20% for cautious and
greedy, deaths spread over the descent instead of a wall at the gate. Decisions: D029 to D033.
Command: `python tools/balance.py --full --runs 300 --procs 6 --pack` (pack of the branch, seeds
1000..1099, 100 runs per policy bot). The generated report of the final pass follows the headline.

## Headline (final pass)

| policy | won | median run | ore gained / spent | gems gained / spent | gear + upgrades bought per run | killers of all runs |
|---|---|---|---|---|---|---|
| cautious | 10% | 21.0 min | 992 / 710 | 91 / 77 | 2.99 + 0.90 = 3.9 | rival 30%, gate 31%, pursuer 15%, drill heat/fire 13% |
| greedy | 12% | 17.2 min | 1751 / 1340 | 181 / 112 | 2.36 + 3.15 = 5.5 | gate 33%, drill heat 24%, rival 13%, pursuer 11%, drill fire 7% |
| balanced | 23% | 21.4 min | 1507 / 1190 | 146 / 84 | 3.36 + 2.63 = 6.0 | gate 45%, drill heat 16%, rival 11%, pursuer 2% |

What each policy buys (per run): cautious tungsten head 0.94, plating 1.24, pumps 0.81, helm 0.53,
bracing 0.30; greedy tungsten 0.95 then diamond 0.85, plating 0.56, weapons 0.93, drill 0.85,
reactor 0.84, lance 0.53; balanced tungsten 0.95, plating 1.47, pumps 0.84, bracing 0.93, reactor
0.79, helm 0.48, lance 0.28. Rival fights per run 2.0 to 2.2 (of about 12 middle nodes on a path,
so about one node in six), of which about a third are the deeper Seam Raider. Gate reached by 41
(cautious), 45 (greedy) and 68 (balanced) runs of 100; the gate's share of all deaths fell from 73%
(balanced, 10 rows) to 58% (balanced), 38% (greedy) and 34% (cautious). Death rows now spread from
row 7 to 13 for every policy (see "death row" below). Coolant outs 8 to 11% of runs; bit breaks
0.05 to 0.33 per run.

## The four passes

| pass | change | cautious | greedy | balanced |
|---|---|---|---|---|
| 1 | 14 rows, 3 store windows, 2 fights per path, event rows mapped, Seam Raider tier, deeper gas and water, 12 start cells, pursuer 0.0075 + 0.00025 per row | 5%, 17.1 min | 16%, 13.3 min | 29%, 16.7 min |
| 2 | base cut speed 0.85 -> 0.68, bar 4 factor 1.65 -> 1.55, pursuer 0.0050 / noise 0.0038 / 0.0002 per row, gate hull 13 -> 16 -> 15 | 4%, 20.8 min | 10%, 16.0 min | 22%, 20.1 min |
| 3 | pursuer time term 0.0044, cautious buys the tungsten head first, gate hull 14 | 10%, 20.4 min | 14%, 16.4 min | 26%, 20.2 min |
| 4 (final) | base cut speed 0.64, pursuer 0.0041 + 0.00028 per row, gate hull back to 13 | 10%, 21.0 min | 12%, 17.2 min | 23%, 21.4 min |

Between passes, 90-run probes (30 per bot, seeds 1000..1029) tried the levers one at a time; the ones
worth recording: the pursuer at its 10-row rates (0.0100 / 0.0028) killed 93% of cautious runs on 14
rows (it keeps pace with a ship that takes 75 s a row, so more rows only gives it more time); a
noise-heavy pursuer (0.0045 per unit) wiped out greedy (0 wins, pursuer 57%); a 16-hull Seam Raider
from row 6 made rivals cautious's top killer (37%).

## Known limits

- Balanced still loses most often at the gate (58% of its deaths); it reaches it 68% of the time
  because it buys bracing and plating. Levers that hit balanced alone are scarce in data; a gate
  weapon that pierces bracing would, but changes the gate's character (lead's call).
- Greedy's crews cook at the drill (heat 24% of runs): 4 bars in rock that warms 0.033 C per meter
  (66 C at the gate; it would be 71 C at the old 0.04) is the descent biting through heat, as
  intended, but it is greedy's biggest killer after the gate.
- Hazard nodes past the two hazard events (both once per run) hold nothing ("no_event"); deeper
  hazard weight would need more hazard events in `data/events` (outside this round's files).

## Full generated report (final pass)


300 runs (100 per bot, seeds 1000..1099), 6 processes, wall 372 s (6.2 min, 20.7 min per 1000 runs). Pack: 20261016-135415-a8965a2.pck
Another Godot was running during the batch: wall time untrusted.

| bot | runs | won % | stuck | median rows | median s | fights/run | gate won % | top death cause |
|---|---|---|---|---|---|---|---|---|
| cautious | 100 | 10.0 | 0 | 12 | 1260 | 2.44 | 24 | rival 30% |
| greedy | 100 | 12.0 | 0 | 12 | 1033 | 2.69 | 27 | gate 30% |
| balanced | 100 | 23.0 | 0 | 13 | 1281 | 2.76 | 34 | gate 43% |

## cautious (100 runs)

- results: dead 90 (90.0%), won 10 (10.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 37, crew_fire 22, crew_combat 18, hull 13
- killers (share of all runs): rival 30 (30.0%), gate 29 (29.0%), pursuer 15 (15.0%), drill_crew_heat 8 (8.0%), drill_crew_fire 3 (3.0%), drill_crew_combat 2 (2.0%), gate_pursued 2 (2.0%), rival_pursued 1 (1.0%)
- rows reached: 7: 5, 8: 9, 9: 8, 10: 12, 11: 11, 12: 14, 13: 41
- death row (non-wins): 7: 5, 8: 9, 9: 8, 10: 12, 11: 11, 12: 14, 13: 31
- run length s: median 1260, p10 984, p90 1445
- fights per run: 0: 1, 1: 9, 2: 42, 3: 41, 4: 7
- fight results: died 31, fled 9, gate died 31, gate won 10, won 163
- fight length s: rivals median 49, gate median 57
- gate reached 41 times, won 10 (24%)
- pursuer strikes on overtaken nodes: mean 0.04, runs with any 4%
- pursuer strikes while caught: mean 2.14, runs with any 20%
- pursuer catches: mean 0.21, runs with any 20%
- bit breaks: mean 0.33, runs with any 33%
- coolant outs: mean 0.11, runs with any 11%
- crew lost: mean 2.65, runs with any 89%
- fires started: mean 8.25, runs with any 100%
- nodes overtaken: mean 15.11, runs with any 100%
- crew death causes: heat@gate 67, heat@drill 45, heat@combat 39, combat@combat 37, fire@combat 30, combat@gate 28, heat@idle 9, fire@gate 8, fire@drill 1, fire@idle 1
- all: gems gained median 91, ore gained median 992
- winners: gems gained median 126, ore gained median 1102
- losers: gems gained median 86, ore gained median 985
- store lines bought (store line: count): crust_trader 0: 241, crust_trader 1: 116, crust_trader 13: 94, crust_trader 15: 124, crust_trader 16: 81, crust_trader 2: 145, crust_trader 3: 106, crust_trader 4: 116, crust_trader 7: 53, crust_trader 8: 30, crust_trader 9: 7

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 35 [30-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 81 | 35 [30-40] | 62 [26-106] | 15 [15-21] | 14 [14-14] | 11 [11-11] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 180 | 35 [29-40] | 130 [71-203] | 19 [4-27] | 12 [12-17] | 10 [10-11] | 2 [2-2] | 4 [4-4] |
| 3 | 100 | 286 | 35 [28-40] | 157 [95-262] | 18 [4-33] | 11 [10-16] | 10 [9-11] | 1 [1-1] | 4 [2-4] |
| 4 | 100 | 380 | 35 [28-40] | 213 [124-327] | 19 [4-41] | 13 [8-18] | 10 [8-10] | 1 [1-1] | 4 [2-4] |
| 5 | 100 | 492 | 30 [28-40] | 234 [132-362] | 16 [3-40] | 12 [7-17] | 9 [8-9] | 1 [0-2] | 4 [2-4] |
| 6 | 100 | 599 | 30 [27-40] | 314 [176-479] | 29 [10-59] | 10 [4-15] | 8 [8-9] | 0 [0-1] | 4 [2-4] |
| 7 | 100 | 697 | 30 [26-35] | 338 [151-581] | 30 [4-67] | 13 [5-18] | 7 [7-8] | 0 [0-1] | 4 [2-6] |
| 8 | 95 | 796 | 33 [27-35] | 282 [127-578] | 23 [4-68] | 15 [4-18] | 6 [6-8] | 1 [0-2] | 4 [2-6] |
| 9 | 86 | 890 | 35 [30-35] | 272 [124-475] | 24 [8-62] | 15 [10-17] | 5 [5-7] | 1 [0-2] | 4 [2-6] |
| 10 | 78 | 997 | 32 [26-35] | 356 [166-559] | 34 [13-75] | 13 [10-17] | 4 [4-6] | 1 [0-1] | 4 [2-6] |
| 11 | 66 | 1103 | 35 [28-40] | 330 [135-649] | 40 [12-91] | 14 [8-17] | 3 [3-5] | 1 [0-2] | 4 [2-9] |
| 12 | 55 | 1207 | 35 [27-40] | 258 [150-680] | 39 [5-88] | 15 [10-17] | 3 [2-5] | 1 [0-2] | 6 [2-9] |
| 13 | 41 | 1300 | 40 [29-40] | 269 [154-433] | 22 [4-74] | 15 [12-18] | 2 [1-4] | 1 [1-2] | 8 [2-9] |

## greedy (100 runs)

- results: dead 88 (88.0%), won 12 (12.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 48, crew_fire 22, hull 13, crew_combat 5
- killers (share of all runs): gate 30 (30.0%), drill_crew_heat 24 (24.0%), rival 13 (13.0%), pursuer 11 (11.0%), drill_crew_fire 7 (7.0%), gate_pursued 3 (3.0%)
- rows reached: 7: 8, 8: 4, 9: 5, 10: 10, 11: 15, 12: 13, 13: 45
- death row (non-wins): 7: 8, 8: 4, 9: 5, 10: 10, 11: 15, 12: 13, 13: 33
- run length s: median 1033, p10 796, p90 1129
- fights per run: 1: 13, 2: 24, 3: 46, 4: 16, 6: 1
- fight results: died 13, fled 5, gate died 33, gate won 12, won 206
- fight length s: rivals median 41, gate median 51
- gate reached 45 times, won 12 (27%)
- pursuer strikes on overtaken nodes: mean 0.07, runs with any 6%
- pursuer strikes while caught: mean 0.85, runs with any 18%
- pursuer catches: mean 0.20, runs with any 19%
- bit breaks: mean 0.05, runs with any 5%
- coolant outs: mean 0.10, runs with any 10%
- crew lost: mean 2.75, runs with any 96%
- fires started: mean 8.55, runs with any 100%
- nodes overtaken: mean 15.79, runs with any 100%
- crew death causes: heat@drill 126, heat@gate 58, fire@combat 26, heat@combat 18, combat@gate 15, fire@gate 15, combat@combat 9, fire@drill 5, event@dialog 3
- all: gems gained median 182, ore gained median 1751
- winners: gems gained median 214, ore gained median 2024
- losers: gems gained median 174, ore gained median 1726
- store lines bought (store line: count): crust_trader 0: 155, crust_trader 1: 86, crust_trader 10: 93, crust_trader 11: 85, crust_trader 13: 95, crust_trader 14: 85, crust_trader 15: 56, crust_trader 2: 193, crust_trader 3: 152, crust_trader 4: 22, crust_trader 5: 53, crust_trader 9: 84

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 35 [30-35] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 73 | 35 [30-35] | 91 [56-130] | 15 [15-26] | 14 [14-14] | 11 [11-11] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 170 | 30 [28-35] | 198 [134-269] | 22 [15-34] | 12 [12-12] | 10 [10-11] | 2 [2-2] | 4 [1-4] |
| 3 | 100 | 264 | 30 [28-35] | 256 [134-373] | 30 [15-49] | 10 [10-11] | 10 [9-10] | 1 [1-1] | 4 [1-4] |
| 4 | 100 | 351 | 30 [27-35] | 332 [163-459] | 38 [15-61] | 9 [8-10] | 9 [8-9] | 1 [1-2] | 4 [1-5] |
| 5 | 100 | 441 | 29 [26-35] | 316 [166-543] | 40 [15-77] | 7 [7-8] | 8 [8-9] | 2 [0-2] | 4 [1-5] |
| 6 | 100 | 529 | 28 [25-35] | 432 [270-699] | 58 [33-101] | 6 [5-6] | 7 [7-9] | 1 [0-1] | 4 [1-5] |
| 7 | 100 | 601 | 28 [25-35] | 556 [243-860] | 71 [22-118] | 4 [3-10] | 6 [6-8] | 1 [0-2] | 4 [1-5] |
| 8 | 92 | 679 | 28 [24-35] | 482 [212-838] | 67 [24-127] | 7 [2-9] | 5 [5-7] | 1 [1-2] | 4 [1-5] |
| 9 | 88 | 746 | 27 [23-29] | 440 [229-714] | 72 [29-114] | 7 [5-11] | 4 [4-7] | 2 [1-2] | 4 [2-5] |
| 10 | 83 | 829 | 26 [20-29] | 603 [340-929] | 87 [46-155] | 5 [3-9] | 4 [3-6] | 2 [1-2] | 4 [1-5] |
| 11 | 73 | 902 | 25 [18-32] | 639 [255-1112] | 100 [44-149] | 7 [2-10] | 3 [2-5] | 2 [1-2] | 4 [0-6] |
| 12 | 58 | 970 | 28 [19-32] | 526 [313-944] | 90 [51-150] | 7 [2-11] | 2 [1-4] | 2 [1-2] | 5 [1-6] |
| 13 | 45 | 1019 | 29 [21-31] | 596 [398-1034] | 95 [51-154] | 9 [6-14] | 1 [0-3] | 2 [1-2] | 5 [3-6] |

## balanced (100 runs)

- results: dead 77 (77.0%), won 23 (23.0%)
- run end causes (hull, crew_<cause>, flooded): crew_heat 45, crew_fire 18, crew_combat 10, hull 4
- killers (share of all runs): gate 43 (43.0%), drill_crew_heat 16 (16.0%), rival 11 (11.0%), drill_crew_fire 2 (2.0%), gate_pursued 2 (2.0%), pursuer 2 (2.0%), drill_crew_combat 1 (1.0%)
- rows reached: 6: 1, 7: 5, 9: 2, 10: 3, 11: 11, 12: 10, 13: 68
- death row (non-wins): 6: 1, 7: 5, 9: 2, 10: 3, 11: 11, 12: 10, 13: 45
- run length s: median 1281, p10 1020, p90 1391
- fights per run: 1: 7, 2: 24, 3: 57, 4: 11, 6: 1
- fight results: died 11, fled 2, gate died 45, gate won 23, won 195
- fight length s: rivals median 48, gate median 58
- gate reached 68 times, won 23 (34%)
- pursuer strikes on overtaken nodes: mean 0.02, runs with any 2%
- pursuer strikes while caught: mean 0.39, runs with any 6%
- pursuer catches: mean 0.11, runs with any 6%
- bit breaks: mean 0.11, runs with any 11%
- coolant outs: mean 0.08, runs with any 8%
- crew lost: mean 2.70, runs with any 94%
- fires started: mean 7.83, runs with any 100%
- nodes overtaken: mean 16.20, runs with any 100%
- crew death causes: heat@gate 93, heat@drill 59, combat@gate 36, heat@combat 22, fire@gate 20, combat@combat 17, fire@combat 12, heat@idle 5, fire@drill 4, fire@idle 2
- all: gems gained median 146, ore gained median 1508
- winners: gems gained median 176, ore gained median 1523
- losers: gems gained median 129, ore gained median 1498
- store lines bought (store line: count): crust_trader 0: 236, crust_trader 1: 94, crust_trader 10: 15, crust_trader 13: 95, crust_trader 14: 10, crust_trader 15: 147, crust_trader 16: 84, crust_trader 2: 165, crust_trader 3: 228, crust_trader 4: 91, crust_trader 5: 28, crust_trader 7: 48, crust_trader 8: 93, crust_trader 9: 79

Resources on arrival per row (median [p10-p90]):

| row | runs | t s | hull | ore | gems | coolant | cells | bits | charges |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 100 | 0 | 40 [30-40] | 10 [10-10] | 15 [15-15] | 14 [14-14] | 12 [12-12] | 2 [2-2] | 4 [4-4] |
| 1 | 100 | 82 | 40 [30-40] | 81 [40-125] | 15 [15-25] | 14 [14-14] | 11 [11-11] | 2 [2-2] | 4 [4-4] |
| 2 | 100 | 186 | 38 [29-40] | 174 [102-240] | 21 [11-30] | 12 [12-12] | 10 [10-11] | 2 [2-2] | 4 [2-4] |
| 3 | 100 | 290 | 35 [28-40] | 203 [118-312] | 23 [7-42] | 10 [10-11] | 10 [9-10] | 1 [1-1] | 4 [3-6] |
| 4 | 100 | 385 | 35 [27-40] | 272 [140-396] | 30 [10-49] | 9 [8-14] | 9 [8-9] | 1 [1-1] | 4 [3-6] |
| 5 | 100 | 491 | 30 [27-40] | 258 [153-444] | 32 [15-59] | 12 [7-13] | 8 [8-9] | 1 [0-1] | 6 [3-6] |
| 6 | 100 | 593 | 29 [27-40] | 366 [215-569] | 46 [26-82] | 10 [5-11] | 7 [7-9] | 0 [0-1] | 5 [3-6] |
| 7 | 99 | 673 | 29 [27-40] | 433 [173-717] | 51 [17-94] | 9 [4-14] | 6 [6-8] | 0 [0-1] | 5 [3-6] |
| 8 | 94 | 764 | 30 [27-37] | 356 [170-696] | 52 [18-108] | 11 [7-13] | 5 [5-7] | 0 [0-1] | 5 [3-6] |
| 9 | 94 | 853 | 32 [27-35] | 357 [148-585] | 56 [25-102] | 10 [9-14] | 4 [4-6] | 1 [0-1] | 6 [3-6] |
| 10 | 92 | 961 | 32 [25-35] | 461 [222-766] | 70 [35-126] | 9 [7-13] | 3 [3-5] | 0 [0-1] | 5 [2-6] |
| 11 | 89 | 1049 | 32 [25-37] | 497 [179-849] | 73 [35-148] | 10 [5-12] | 2 [2-4] | 0 [0-1] | 5 [2-8] |
| 12 | 78 | 1146 | 32 [25-40] | 344 [185-877] | 70 [35-109] | 10 [4-15] | 2 [1-4] | 0 [0-1] | 7 [2-8] |
| 13 | 68 | 1245 | 40 [30-40] | 313 [158-537] | 64 [26-102] | 12 [8-14] | 1 [0-3] | 1 [0-1] | 7 [4-8] |

## Events (all bots)

300 runs.

| event | started | per 1000 runs |
|---|---|---|
| blind_aquifer | 68 | 227 |
| byrd_signal | 91 | 303 |
| cold_spring | 51 | 170 |
| gas_pocket | 44 | 147 |
| green_gallery | 72 | 240 |
| knocking_pipe | 50 | 167 |
| kola_tapes | 58 | 193 |
| listening_post | 56 | 187 |
| mohole_core | 70 | 233 |
| rival_claim | 52 | 173 |
| shaft_nine | 73 | 243 |
| zarya_wreck | 51 | 170 |

Events never seen: none

| choice (event/page/option) | times | outcomes (next page: times) |
|---|---|---|
| blind_aquifer/intro/0 | 2 | braced: 2 |
| blind_aquifer/intro/1 | 49 | grouted: 49 |
| blind_aquifer/intro/2 | 17 | burst: 9, rode: 8 |
| byrd_signal/intro/1 | 91 | mast: 91 |
| cold_spring/intro/1 | 35 | filtered: 35 |
| cold_spring/intro/3 | 16 | drained: 16 |
| gas_pocket/intro/0 | 44 | vented: 44 |
| green_gallery/intro/0 | 51 | amber: 51 |
| green_gallery/intro/1 | 21 | deep: 16, spores: 5 |
| knocking_pipe/intro/0 | 50 | clean: 50 |
| kola_tapes/intro/1 | 58 | strip: 58 |
| listening_post/intro/2 | 56 | decoy: 56 |
| mohole_core/intro/0 | 45 | gas: 9, recovered: 36 |
| mohole_core/intro/2 | 25 | leave: 25 |
| rival_claim/intro/0 | 30 | paid: 30 |
| rival_claim/intro/2 | 22 | fight: 22 |
| shaft_nine/intro/0 | 22 | carts: 22 |
| shaft_nine/intro/1 | 27 | coolant: 24, sludge: 3 |
| shaft_nine/intro/2 | 24 | cable: 3, cage: 21 |
| zarya_wreck/intro/0 | 38 | logs: 38 |
| zarya_wreck/intro/2 | 13 | bits: 8, derrick: 5 |

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| cautious | 1000..1009 | 10/10 | 0 | 7380 | 102 |
| cautious | 1010..1019 | 10/10 | 0 | 7204 | 105 |
| cautious | 1020..1029 | 10/10 | 0 | 7031 | 98 |
| cautious | 1030..1039 | 10/10 | 0 | 7317 | 102 |
| cautious | 1040..1049 | 10/10 | 0 | 7393 | 103 |
| cautious | 1050..1059 | 10/10 | 0 | 7331 | 105 |
| cautious | 1060..1069 | 10/10 | 0 | 11427 | 66 |
| cautious | 1070..1079 | 10/10 | 0 | 11083 | 71 |
| cautious | 1080..1089 | 10/10 | 0 | 10990 | 69 |
| cautious | 1090..1099 | 10/10 | 0 | 11212 | 66 |
| greedy | 1000..1009 | 10/10 | 0 | 10832 | 58 |
| greedy | 1010..1019 | 10/10 | 0 | 11000 | 54 |
| greedy | 1020..1029 | 10/10 | 0 | 9469 | 61 |
| greedy | 1030..1039 | 10/10 | 0 | 9240 | 63 |
| greedy | 1040..1049 | 10/10 | 0 | 9350 | 66 |
| greedy | 1050..1059 | 10/10 | 0 | 9235 | 64 |
| greedy | 1060..1069 | 10/10 | 0 | 9516 | 66 |
| greedy | 1070..1079 | 10/10 | 0 | 9349 | 62 |
| greedy | 1080..1089 | 10/10 | 0 | 12043 | 52 |
| greedy | 1090..1099 | 10/10 | 0 | 12580 | 48 |
| balanced | 1000..1009 | 10/10 | 0 | 12539 | 61 |
| balanced | 1010..1019 | 10/10 | 0 | 12373 | 59 |
| balanced | 1020..1029 | 10/10 | 0 | 12536 | 62 |
| balanced | 1030..1039 | 10/10 | 0 | 12084 | 64 |
| balanced | 1040..1049 | 10/10 | 0 | 10768 | 70 |
| balanced | 1050..1059 | 10/10 | 0 | 10935 | 66 |
| balanced | 1060..1069 | 10/10 | 0 | 10988 | 74 |
| balanced | 1070..1079 | 10/10 | 0 | 10755 | 66 |
| balanced | 1080..1089 | 10/10 | 0 | 10858 | 69 |
| balanced | 1090..1099 | 10/10 | 0 | 11203 | 70 |
