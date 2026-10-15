# Balance report 20261015-152553

runs per bot 700, processes 6, seeds from 1000

## Bot: auto

- runs: 700
- survival: 99.4% (696/700)
- death causes: crew_fire 4 (0.6%)
- ticks: median 7200, mean 7178
- mean first_fire_out_s: 15.4 (over 696 runs)
- mean max_water_m3: 2.35

## Bot: idle

- runs: 700
- survival: 50.6% (354/700)
- death causes: crew_fire 217 (31.0%), crew_heat 129 (18.4%)
- ticks: median 7200, mean 6320
- mean first_fire_out_s: 44.5 (over 368 runs)
- mean max_water_m3: 31.33

## Bot: random

- runs: 700
- survival: 40.6% (284/700)
- death causes: crew_fire 315 (45.0%), crew_heat 79 (11.3%), crew_drowned 22 (3.1%)
- ticks: median 6238, mean 5866
- mean first_fire_out_s: 39.1 (over 348 runs)
- mean max_water_m3: 22.11

## Processes

| bot | seeds | lines | exit | ticks/s | secs |
|---|---|---|---|---|---|
| auto | 1000..1116 | 117/117 | 0 | 31056 | 28 |
| auto | 1117..1233 | 117/117 | 0 | 29870 | 29 |
| auto | 1234..1350 | 117/117 | 0 | 29669 | 29 |
| auto | 1351..1467 | 117/117 | 0 | 30452 | 28 |
| auto | 1468..1583 | 116/116 | 0 | 30971 | 28 |
| auto | 1584..1699 | 116/116 | 0 | 31010 | 27 |
| idle | 1000..1116 | 117/117 | 0 | 45423 | 17 |
| idle | 1117..1233 | 117/117 | 0 | 46456 | 17 |
| idle | 1234..1350 | 117/117 | 0 | 47392 | 16 |
| idle | 1351..1467 | 117/117 | 0 | 45843 | 17 |
| idle | 1468..1583 | 116/116 | 0 | 46243 | 16 |
| idle | 1584..1699 | 116/116 | 0 | 45104 | 17 |
| random | 1000..1116 | 117/117 | 0 | 38846 | 19 |
| random | 1117..1233 | 117/117 | 0 | 40482 | 17 |
| random | 1234..1350 | 117/117 | 0 | 42302 | 17 |
| random | 1351..1467 | 117/117 | 0 | 42827 | 16 |
| random | 1468..1583 | 116/116 | 0 | 46038 | 15 |
| random | 1584..1699 | 116/116 | 0 | 46713 | 15 |

Total wall time: 71 s.

## M1-scale estimate

Measured mean 39816 ticks/s per process with 6 processes busy. At M1 scale a tick is assumed 4x as costly and a run 30000 ticks, so one M1 layer-run takes about 3 s per process, and 1000 runs on 6 processes take about 502 s (8.4 min).
