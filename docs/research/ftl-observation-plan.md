# Observation plan: watching FTL for what nobody wrote down

Written 2026-10-22 (FTL parity side track, D052 to D055). Companion files: `ftl-reference.md` (what the
community documents), `behavior-ledger.md` (where observations end up), `ftl-difftest-plan.md`.

Most of what we need is documented (`ftl-reference.md` marks each system). This plan covers the rest:
the rows marked OBSERVE, the feel questions no wiki answers (how long a fight lasts, how often a
crisis lands, how many decisions a minute the player makes), and checks on documented numbers that
look doubtful. Nothing here runs until Stewart has picked his systems from the inventory; the
observation sessions then cover only the picked systems.

## Ground rules

1. **Read only.** The install folder (`C:\Program Files (x86)\Steam\steamapps\common\FTL Faster Than Light`)
   is never written to, never modded, never patched. No Hyperspace or other mod goes into it.
2. **Everything we capture stays in `research_private/`** (git-ignored): recordings, frames, CSVs,
   exact numbers. The committed repo only ever gets behavior rows in our own words with Inner Sun
   targets (`behavior-ledger.md`).
3. **Stewart's FTL profile is real.** FTL keeps its saves in
   `C:\Users\stewa\Documents\My Games\FasterThanLight\` (`ae_prof.sav` with his unlocks and
   achievements, `continue.sav`, a run saved on 2020-12-04). Before the first observation session,
   copy that folder to `research_private\ftl_profile_backup_<date>\` and tell him that starting a new
   FTL run replaces his saved run. Never delete or edit his save files.
4. **Process rules (CLAUDE.md, GODOT-SIDE-BY-SIDE.md).** Launch `FTLGame.exe` only through a Windows
   job object (the same machinery as `tools/proc.py`; a small `tools/ftl_session.py` would wrap it, not
   built yet), with the install folder as the working directory, so nothing outlives the session.
   Never kill anything by name. Quit through the game's own menu; the job is the fallback.
   FTL runs on its own when started directly (its log says the Steam API is absent and it plays on),
   which also keeps Steam Cloud out of it.
5. **No Inner Sun perf, capture or balance runs during an FTL session.** Anything measured while FTL
   renders is marked untrusted. Black Diamond may be running: check before starting and keep the
   session short.
6. **The firewall holds for observers too.** Whoever watches FTL writes ledger rows in Inner Sun's
   words and puts the exact readings in `research_private/ledger_evidence.md` under the row's
   evidence ID. Builders never get the recordings, frames or that file.

## Three ways to watch, in the order to use them

### A. Stewart plays, the game is recorded, we sample frames (first choice)
Costs him only FTL play time. He plays normally (any ship, Easy or Normal) with a screen recorder
running: Xbox Game Bar (Win+Alt+R) records the game window to `C:\Users\stewa\Videos\Captures\`.
Each session gets one line of notes (ship, difficulty, anything odd). We move the files into
`research_private\ftl_obs\recordings\`, then:
- sample at 2 fps for the overview (ffmpeg), and at the full frame rate around marked moments
  (a fire starting, a breach, a jump, a store visit);
- read the HUD in frames: FTL prints most of its state on screen (evasion and oxygen as numbers,
  weapon charge bars, power bars per system, crew health and skill bars, scrap, fuel, missiles,
  the pursuit line on the map);
- time processes by frame count (30 fps gives about 33 ms, plenty for processes of seconds);
- write one CSV per observation into `research_private\ftl_obs\` and delete the bulky frames once
  the CSV is checked (C: space).
A real run gives natural fights, fires, breaches and stores, which covers most rows without any setup.

### B. The lead plays with computer use, a recorder runs alongside (when Stewart is present)
For rows that need a particular situation or a tooltip read. Stewart approves computer-use access for
`FTLGame.exe` at the start (he must be there to click the dialog). The lead pauses with the space
bar, takes screenshots, reads tooltips, sets doors and power, then unpauses. Computer-use timing is
too loose (about a second per action) to time anything, so a recorder captures the window at the
same time (ffmpeg `gdigrab` on the window title into `research_private\ftl_obs\`) and timings come
from the video, not from the agent's clock. Sessions are short (20 to 40 minutes) and planned ahead
as a list of setups. Unverified and to check in the first session: whether Save and Quit followed by
Continue restores a fight exactly, which would let us repeat one setup several times.

### C. Last resorts (each needs Stewart's yes first)
- A modded COPY of FTL inside `research_private\` (never the install) with the community hook mod
  for its debug console, to stage exact situations. It means downloading and running third-party
  code: ask first, and only if A and B leave a row the inventory ranks high.
- A one-off, read-only look at one function in a disassembler, by a human-run session, writing
  down only the number and the rule. Only for a single constant that cannot be watched. Expected
  never (`ftl-reference.md`, "REA").

## Observation protocols

Each protocol has an ID (O-xx), the ledger rows it serves, how to get the situation in normal play,
what to read, how many repeats, and what the CSV holds. The list below covers the gaps the survey
found; rows are added for whatever Stewart picks.

| ID | Serves | Situation | Read from the screen | Repeats | CSV columns |
|---|---|---|---|---|---|
| O-01 | Fire spread and growth | Any fight where a fire starts in a room with an open or closed door to a neighbour | fire tiles per room every 0.5 s, door state, crew in room | 6 fires | t, room, tiles, neighbour_tiles, door, crew |
| O-02 | Firefighting by hand | A fire that crew fight: one crew, then two | fire tiles over time, crew skill bars | 4 each | t, tiles, crew_count, skill |
| O-03 | Starving a fire | Open the doors and the airlock to the room (method B) | oxygen % and fire tiles over time | 3 | t, oxygen, tiles |
| O-04 | Repair pace | Any damaged system repaired by one crew, then two, by skill | repair bar progress, time per bar | 6 | t, bars, crew, skill |
| O-05 | Skill growth | One long run: the skill bars of each crew member at every jump | skill bar fill per crew per station | 1 run | jump, crew, station, fill |
| O-06 | Fight pacing (feel) | Every fight in a recorded run | fight start, first hit taken, first system down, end, outcome | all fights | fight, t_start, t_first_hit, t_first_down, t_end, outcome |
| O-07 | Crisis rhythm (feel) | A recorded run | every fire, breach, system down, crew injury, with time | 1 run | t, kind, room |
| O-08 | Decisions per minute (feel) | A recorded run, paused moments counted | power changes, crew orders, door changes, target changes, pauses | 1 run | t, kind |
| O-09 | Pursuit pressure | A recorded run | the pursuit line on the map at each jump, jumps per sector, fights forced by it | 1 run | jump, sector, pursuit_pos, forced_fight |
| O-10 | Store contents | Every store visited in recorded runs | categories offered, prices, what Stewart bought | all stores | sector, item_kind, price, bought |
| O-11 | Enemy behaviour | Fights in a recorded run | what the enemy targets first, when it moves power, when it runs or offers terms | all fights | fight, t, enemy_action |

O-06 to O-08 are the feel half: they give the human pacing that bots cannot, and they are compared
with Stewart's own Inner Sun run records (the input diary in `summary.ui`, `tools/run_report.py`).

## From frames to ledger rows

1. The observer reads the CSV, works out the shape (a rate, a ratio, a curve, a threshold) and
   writes the exact readings under the row's evidence ID in `research_private/ledger_evidence.md`.
2. The observer then writes or updates the row in `behavior-ledger.md`: the behavior in Inner Sun's
   terms and an Inner Sun target band in Inner Sun's units, never FTL's numbers.
3. Where a documented number and an observation disagree, the observation wins and the row says
   "observed" as its source kind.

## Budget

- Method A: one or two of Stewart's normal FTL runs, recorded (an hour or two of his time he would
  enjoy anyway), plus about an hour of lead time per run to sample and log.
- Method B: one session of 20 to 40 minutes per two or three rows, with Stewart present.
- Disk: a 1080p recording is about 3 to 6 GB an hour; keep only CSVs and a few key stills after
  logging (C: had 189 GB free on 2026-10-22).
