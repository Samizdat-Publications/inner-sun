# Handoff

From the M1c session (2026-10-16) to the next round, which starts after Stewart plays build 5.

## Next: Stewart plays build 7 (2026-10-22 night)
`builds/InnerSun.exe` is `m1d-playtest-7` (tag, milestone zip in `builds/milestones/m1d-playtest-7/`).
What changed and why: `PROGRESS.md` (top). M1d stays open until his build 7 run: read it with `python
tools/run_report.py --since 2026-10-23`, replay from the `m1d-playtest-7` tag, re-judge difficulty
(the bots win 26 to 50%; he died at row 2 of his only build 6 run), then close M1d and tell the parity
session (`claude/blissful-neumann-c52d9b`) it may merge into main, and review that merge. After the
parity merge: M2 workstream S, the spine tower ship (D061, `PLAN.md` section 11). Gemini has credit
again (about 17 USD on 2026-10-22).
Paste this into a new session (folder `C:\Users\stewa\Documents\Claude\Inner Sun`, Opus 5.5, effort
high, Auto):
```
Continue Inner Sun: M1d, my build 7 notes. Read CLAUDE.md, PROGRESS.md, HANDOFF.md (the newest section) and docs/plans/M1d.md, then my notes at the top of docs/STEWART_FEEDBACK.md. Run python tools/run_report.py --since 2026-10-23 first, replay my runs from the m1d-playtest-7 tag, triage, fix, and decide on difficulty. When M1d closes, tell the FTL parity session it may merge into main and review its merge, then plan M2 workstream S (the spine tower ship, D061). Work autonomously per CLAUDE.md; stop for "checkpoint", a usage limit, or a decision that is genuinely mine.
```

## Where the interim round stands (2026-10-22 evening)
Done on main and pushed: the Gemini audit fixes, the amber PARKED notice, the multiply scorch, the
dead DOUSE button fix, and the zero-change file split (D059; `PROGRESS.md` has the details and
hashes). Open: Stewart's crown pick (Repair A or B in `harness/out/crown_candidates/round2/`), the
critic capture of seed 1061 (the miner goes out at about 85 s), and his build 6 notes. The parity
session works on `claude/blissful-neumann-c52d9b`; it may edit the split files on its branch and
merges into main only when the M1d session says the build 6 triage is done. Gotcha found this round:
after merging a branch that adds `class_name` scripts, run a full `python tools/check.py` (it
re-imports) before any balance run, or `balance.py` hangs to its timeout on a stale class cache.

## Parity branch (2026-10-23): all six picks built, waiting to merge
Branch `claude/blissful-neumann-c52d9b` (worktree `C:\Users\stewa\Documents\Claude\Inner Sun\.claude\worktrees\blissful-neumann-c52d9b`) holds the
FTL parity work: ledger rows for all six picks, every sim row passing (`python tools/ledger.py`), the
views, the bots and balance measures, main merged in through M1d's build 6 triage. Playtest build
`m2p-parity-1` sits in that worktree's `builds\`, apart from main's build. Next:
1. Stewart plays it and answers, per system (upgrades, rewards, manning, doors and purging, stores,
   environments), the three A/B questions from `docs/research/ftl-difftest-plan.md` layer 5 (as
   tense? as readable? as many real choices? 1 to 5), at the top of `docs/STEWART_FEEDBACK.md`.
   His view on difficulty decides D082 (the balanced bot wins 58%).
2. When the M1d session says M1d is closed: merge main into the branch once more, full check, then
   merge the branch into main (`git merge --no-ff`), re-record determinism, and only then export over
   `builds\InnerSun.exe`. D061 (the spine tower ship) is planned to start after that merge.
3. Open on the ledger: the feel row L-DOR-F1. Three blind stills checks (`tools/critic_stills.py`,
   `review/critiques/stills_dor_f1_*`): fire and purge read right; shut doors now read (amber frame and
   lamp) but an open doorway still reads as a wall, because each room's art runs to the wall. Left for
   the spine-tower ship art (D061) and Stewart's A/B.
   Known gaps: a rival keeps its ship file's rock heat in a fight (42 C) instead of the layer's, so
   deep fights are cooler for it than for the player (older than parity; magma adds the same +25 C to
   both); the DOUSE button covers the doorway of the room it sits on; crew stay selected after an order
   (as in FTL).

## Next session (start now, 2026-10-22): M1d interim round, then build 6 notes tonight
Stewart cannot play build 6 until the evening and wants the most done meanwhile (D058). This session:
starts the FTL parity workstream at once as a separate session in its own worktree (the side-track
prompt below), does the M1d work that needs no notes plus the verified Gemini audit bugs
(`docs/BACKLOG.md`, "Gemini audit"), and triages his build 6 notes when they land. Build 6 must stay
what `Play Inner Sun.bat` launches until he has played it: no new export before then.
Paste this into a new session (folder `C:\Users\stewa\Documents\Claude\Inner Sun`, Opus 5.5, effort
high, Auto):
```
Continue Inner Sun: M1d interim round, then my build 6 notes tonight. Read CLAUDE.md, PROGRESS.md, HANDOFF.md (the newest "Next session" section and "Side track: FTL parity"), docs/plans/M1d.md, docs/BACKLOG.md ("Gemini audit") and D052 to D058 in docs/DECISIONS.md. 1) First, start the FTL parity workstream as its own session with start_session (initiation user_asked, context fresh, its own worktree, Opus 5.5, effort high), using the paste prompt in HANDOFF.md "Side track: FTL parity". Keep in touch with it by SendMessage: tell it which files you are splitting, and tell it when it may merge. 2) Until my notes arrive: fix the verified Gemini audit bugs, each with a test, then the M1d "Ready to dispatch without his notes" items; re-run balance and determinism and record the new hashes. Do not export a new build and do not touch builds/ until I have played build 6. 3) When my build 6 notes land at the top of docs/STEWART_FEEDBACK.md: python tools/run_report.py --since 2026-10-22 first, replay my runs from the m1d-playtest-6 tag (a worktree at that tag, since main has moved), fill the M1d triage table, then work autonomously per CLAUDE.md and stop with a new playtest build. 4) When M1d closes, tell the parity session it may merge into main and review its merge. I will approve computer use if I am here. Stop for "checkpoint", a usage limit, or a decision that is genuinely mine.
```

## Next session: M1d (prepared before build 6 was played; superseded by the section above)
Stewart plays build 5b (or 5c), writes notes at the top of `docs/STEWART_FEEDBACK.md`, then starts a
session at effort **high** (his choice) with his weekly quota at about 80%, to spend up to 90%. The
plan is ready in `docs/plans/M1d.md`: the start protocol (`python tools/run_report.py --since
2026-10-17` first), a triage table to fill, the questions build 5b asked him with the levers behind
each answer, a decision tree for the likely notes, work that needs no notes, the bridge to M2, and
budget pacing. Specs ready to dispatch: `docs/plans/specs/m2_burrowers.md` (the onboarding hints are built).
**Already started (2026-10-17):** Stewart played build 5c for 15 minutes (his notes and what the run
record shows are at the top of `docs/STEWART_FEEDBACK.md`); build 6 (`m1d-playtest-6`) fixes the
miner's exit (D051), the miner drawn twice, adds the miner's aim estimate and the onboarding hints.
Douse never reached the game for him and the cause is not found: build 6 records an input diary in
each run record; read it with `python tools/run_report.py` after his next run, first thing.

Paste this into a new session (folder `C:\Users\stewa\Documents\Claude\Inner Sun`, Opus 5.5, effort
high, Auto):
```
Continue Inner Sun: M1d. Read CLAUDE.md, PROGRESS.md, HANDOFF.md (the "Next session" section) and docs/plans/M1d.md, then my notes at the top of docs/STEWART_FEEDBACK.md. Run python tools/run_report.py --since 2026-10-17, fill the triage table in M1d.md, then work autonomously per CLAUDE.md: specs to builders, verify every still yourself, keep what is fun. I will approve computer use if I am here, so play it by hand. Republish the making-of page (https://claude.ai/artifact/UJjDA4PJkSXMKjpg2zxQpc) when something visible lands. Stop with a new playtest build when my weekly usage reaches about 90%, or earlier for "checkpoint" or a decision that is genuinely mine.
```

## Side track: FTL parity (planned 2026-10-22, not started; does not replace M1d)
A planning session (D052 to D055) turned FTL into a reference behind a firewall: the community
survey and scored inventory (`docs/research/ftl-reference.md`), the ledger format with example rows
(`behavior-ledger.md`), the observation and differential-test plans, `PLAN.md` section 10 and the
checklist `docs/plans/M2_parity.md`. FTL's data folder is unpacked, private and git-ignored, in
`research_private/` (regenerate with `python tools/ftl_unpack.py`; never commit anything from it).
Nothing is built. Stewart picked inventory 1 to 6 (D056). **Order (D058):** the next session (prompt
at the top of this file) starts this one right away as a separate session in its own worktree, with
the prompt below. It can also be pasted by hand into a new session (folder
`C:\Users\stewa\Documents\Claude\Inner Sun`, Opus 5.5, effort high, Auto). It works on its own
branch and merges into main only after M1d has triaged Stewart's build 6 runs:
```
Start the Inner Sun FTL parity workstream (PLAN.md section 10, docs/plans/M2_parity.md). Read CLAUDE.md, PROGRESS.md, HANDOFF.md, then docs/research/ftl-reference.md, behavior-ledger.md, ftl-observation-plan.md and ftl-difftest-plan.md, and D052 to D055 in docs/DECISIONS.md. My picks (D056): inventory 1 to 6, rising upgrade prices, rewards that grow with depth in tiers, manned stations, doors and purging, stores that roll their stock, node environments. You are the observer: you may read research_private/, which is git-ignored and so missing from a worktree; read and write the main checkout's copy by absolute path, C:\Users\stewa\Documents\Claude\Inner Sun\research_private\ (if the unpacked data is missing, run python tools/ftl_unpack.py from the main checkout, which writes it there) and the sources in ftl-reference.md; write ledger rows for my picks in our own words with Inner Sun targets, exact FTL values only in research_private/ledger_evidence.md. Builders work in worktrees from ledger rows alone and never see FTL material. Build data-only systems first, every row closes with its test and its wrong-value check. Work in your own worktree and branch: do not merge into main until the M1d session says its build 6 triage is done (D058), leave the files it is splitting alone until the split is on main, and never export over builds/InnerSun.exe. Before each builder dispatch, run the Gemini math audit (python tools/gemini_audit.py, D057) on the rows and spec, and verify every finding yourself before acting on it. Ask me for a recorded FTL run when OBSERVE rows need it; I will approve computer use if I am here. Stop with a parity report and a playtest build, or earlier for "checkpoint" or a decision that is genuinely mine.
```

## Build 5 in one paragraph (2026-10-17)
Stewart had not played build 4 yet and asked for the outstanding list, on high effort, to about 80%
of his weekly quota. Done: the M1c polish (requisitions toast at the first dive, the rock tile repeat
broken, structure "light" blocks with a blue-lit crystal hollow, the blast ring clipped to the world
view, the map's "triangulation failed" error and pursuit label) and plan round E, the away miner
(D046 to D048: G sends the selected crew member to dig a vein by hand, the drill parks until they are
back, the haul pays only on return). The sim was a builder-opus round (about 70 minutes, 371k tokens),
the view a Sonnet builder round (about 25 minutes, 347k tokens); the lead did the polish, the specs
and the merges. Playtest build 5 is exported (`m1c-playtest-5`) and replaces build 4; build 5b (`m1c-playtest-5b`) adds the hazard visuals (D049: flames, smoke, teal water); build 5c (`m1c-playtest-5c`) adds world depth (D050: far wall and silhouettes through openings, dust, colour beds) and is what `Play Inner Sun.bat` launches. Usage note:
this whole session moved Stewart's weekly quota from 75% to about 77%. Next round (M1d) is the same
as the prompt below, with build 5 in place of build 4.

## M1c in one paragraph (superseded by build 5 above: read "build 4" there as history)
Stewart's build 3 notes ("picking a spot on the radar and going straight down", "more things to
manage", buried towns, something to keep on death) became D034: every powered system has a job in
the dig. Built and merged: loud stop notices (no power, broken bit); hold depth and helm-powered side
cutting (heading to +-90); fault rock whose rockfalls bracing soaks; blasts by the charge launcher
(half the ore shatters, D039); douse (a coolant unit on a fire); buried structures (old mine works, a
Soviet rig module, a crystal hollow with a sometimes-trader: crates, break-in events, a mid-dig store);
research and requisitions (D040); the rock shader redrawn as fractured blocks (D045). Playtest build 4
is exported (`m1c-playtest-4b`, which Stewart plays; `m1c-playtest-4` is the critic-reviewed build
without the stop-notice fix). Not done: the away miner (plan round E), hands-on play by the lead
(computer-use access was declined this session, so judging leaned on stills and the Gemini critic),
and the critic's M2 art items (`review/LEDGER.md` 24 to 28). The balanced bot wins about 38% (above the
10 to 30% band, kept on purpose: D039, D044); tune only if build 4 is too easy for Stewart.
Next round (M1d): triage his build 4 notes first, then the candidates in `docs/plans/M1c.md` that are
still open. Effort xhigh for the lead while triaging, high once it is plain building; Sonnet builders
for view and data, Opus builders only for sim-heavy work (from this session's task reports: the two
Opus sim rounds took 3.4 and 1.0 hours and about 405k and 368k tokens; Sonnet view and meta rounds 35
to 45 minutes and 240k to 460k tokens).

Paste this into a new session (folder `C:\Users\stewa\Documents\Claude\Inner Sun`, Opus 5.5, effort
xhigh, Auto):
```
Continue Inner Sun: M1d. Read CLAUDE.md, PROGRESS.md and HANDOFF.md (the newest paragraph), then docs/STEWART_FEEDBACK.md (my build 5 notes are at the top), docs/plans/M1c.md and docs/DECISIONS.md D034 onward. Replay any runs I mention from %APPDATA%\InnerSun\runs\. Write docs/plans/M1d.md from my notes and the open M1c items, then work autonomously per CLAUDE.md, judge changes with the Gemini critic and by playing by hand (python tools/play.py plus computer use; I will approve the access), keep what is fun. Republish the making-of page (https://claude.ai/artifact/UJjDA4PJkSXMKjpg2zxQpc) when something visible lands. Stop with a new playtest build. Stop earlier only for "checkpoint", a usage limit, or a decision that is genuinely mine.
```

## M1b in one paragraph
Stewart's first playtest (2.5 minutes, steering only) said there was nothing to do and runs were
too short with too little loot. The lead then played it by hand with real keys and mouse and found
eight control defects, all fixed and re-tested by hand. Stewart chose "digging is the game" (D024):
mining first, FTL systems, events, upgrades and occasional fights around it ("scanning planets and
gaining resources"). Built since: a nine-material ore and gem economy by depth, gas pockets, surveys
on map nodes, ore-bought gear, a zoomed-out drilling view with visible ore, pickups and a dig tally,
a 14-row Crust with about 20-minute runs. Playtest build 3 is exported. A live making-of page tracks
progress (https://claude.ai/artifact/UJjDA4PJkSXMKjpg2zxQpc); republish it when something visible
lands. Hands-on testing: `python tools/play.py`, then computer-use `request_access` with the window's
exe basename (`InnerSun.exe` for `--exe` builds, `Godot_v4.7.2-stable_win64.exe` for the project).
Stewart played build 3 (row 8; then a death to the front at row 7 holding 625 ore unspent): "amazing
so far", combat good. His asks are at the top of `docs/STEWART_FEEDBACK.md`. Next round (M1c) is a
design round, in this order unless he says otherwise:
1. Quick fixes: a loud "DRILL HAS NO POWER" alert and a combined "BIT BROKEN: press B" alert.
2. Steering that is a choice: lateral cutting speed and turn rate scale with power (drill and helm),
   a "hold depth" mode that cuts sideways along a vein, so pulling power from other systems pivots
   faster. Today lateral speed is forward speed x sin(heading), capped at 45 degrees.
3. Things in the rock: buried structures (old mine works, Soviet rigs, Agartha-style hollows and
   ruins, later Terraria-like underground towns) you break into for loot, events and trading posts.
4. Park and send out a miner (an away team on foot) to mine a vein by hand, with risks.
5. Meta progression: keep something on death (banked samples or research) that unlocks ships and
   starting gear across runs.
(Done in M1c except item 4, the away miner.)

## State in one paragraph (M1a)
M1a is built: a whole run plays from the first node to death or the layer gate. A painted drill
tower bores down a node map through layered rock (steering, power, heat, bit wear, noise, ore, gems,
water pockets). FTL-style systems and power, fire, water and heat spread room to room, and the crew
handle emergencies. A pursuer advances with time and noise. The run has real-time fights with pause
against rival rigs and a gate boss, 12 dossier events with redactions that lift with the codex, a
store, recruitment and permadeath, a death report, a codex and a saved profile. Every run is saved
as a replayable record. Three policy bots play 1,000 full runs in about 12 minutes; the first tuning
passes are D021 and D022. The blind critic scored the M0 build 3.8 and the M1 run screen 5.8 before
its fixes (`review/scores.csv`). Details: `PROGRESS.md`. Architecture: `docs/ARCHITECTURE.md`.

## What Stewart does now
Play the build (`Play Inner Sun.bat`, or the README's PowerShell line), as many runs as he likes, and
write notes at the top of `docs/STEWART_FEEDBACK.md` under a dated heading: what was fun, what was
boring or confusing, what he wanted to do and could not. His runs are saved in
`%APPDATA%\InnerSun\runs\`, so any problem can be replayed exactly (`python tools/replay.py --latest`).

## Start the next session (M1d)
In the Claude app, open the Code tab and start a new session with these settings:
- **Folder:** `C:\Users\stewa\Documents\Claude\Inner Sun`
- **Model:** Opus 5.5
- **Effort:** high (Stewart's choice for M1d, 2026-10-17; the triage thinking was done ahead in
  `docs/plans/M1d.md`)
- **Permission mode:** Auto

Or paste this into Windows PowerShell:
```powershell
cd "C:\Users\stewa\Documents\Claude\Inner Sun"; claude --model claude-opus-5-5 --effort high --permission-mode auto
```
Then paste the prompt from "M1c in one paragraph (newest)" at the top of this file.

## Delegation (what worked in M1a)

| Who | Model, effort | Does |
|---|---|---|
| Lead (the session) | Opus 5.5, xhigh | Architecture, specs, integration (main.gd, merges), game feel, taste, every diff and screenshot |
| `builder` | Sonnet, medium | UI, view scenes, content data, tooling and tests, from written specs |
| `builder-opus` | Opus, medium | Sim modules: drilling, systems, run and map, combat, events, policy bots |
| `writer` | Opus, medium | Events, codex, radio, in the style guide's voice |
| `asset-smith` | Sonnet, medium | Gemini art, ElevenLabs sound, Blender, normal maps |
| `qa-auditor` | Sonnet, high | Adversarial check of PROGRESS and HANDOFF before every handoff |
| `player-critic` | Sonnet, high (Opus at gates) | Blind review of `review/inbox` (run by `python tools/critic.py`) |

- **Every code agent gets its own worktree** (`isolation: worktree`) and a list of files it owns,
  disjoint from every other running agent. Agents commit on their branch; the lead reads the diff,
  merges with `git merge --no-ff`, runs the full `python tools/check.py`, pushes, and removes the
  worktree (`git worktree remove --force`, then `git branch -d`).
- **Expect three small merge conflicts** and resolve them by keeping both sides: the
  tuning-keys list in `game/tests/test_data.gd`, `docs/SPEND.md`, and `docs/progress/INDEX.md`.
  Progress picture numbers collide when two agents add one: renumber the later one with `git mv`.
- **Agents cannot see git-ignored files** in their worktree: point them at the main repo's Godot API
  dump, and commit a spec before dispatching the agent that reads it.
- **Agents overspend windowed runs** (each flashes a window on Stewart's screen for a second): give a
  limit and check it in the report. Two or three agents at once is plenty when RAM is tight.
- **Specs live in `docs/plans/specs/`.** Each states the goal, owned files, interfaces to keep, hard
  rules, the commands that must pass, what done looks like, and the report format.

## The review loop
1. `python tools/capture.py --mode run --bot balanced --seed <n> --duration 240 --stills 16 --label <label>`
   (a whole run; event, store, map and death screens are held long enough to see them).
2. `python tools/critic.py` (headless player-critic with a tool-call audit; `--model opus` at gates).
   `python tools/critic_gemini.py` watches the video (about 0.15 USD a review; its scores swing a
   point or more between runs, so trust what two reviews agree on).
3. Triage every issue in `review/LEDGER.md` as FIX, DEFER or REJECT; fix the FIX items.
4. Balance: `python tools/balance.py --full --runs 1000 --procs 6 --pack` (about 12 minutes), report in
   `harness/out/balance/full_report.md`; copy the headline report to `docs/research/` when it matters.

## Tools and paths
- Godot 4.7.2: `C:\Users\stewa\AppData\Local\Microsoft\WinGet\Links\godot_console.exe` (the tools find
  it). API reference of this exact build: `harness/out/godot-api/doc/classes/`.
- Blender 5.1: `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`.
- API keys: environment first, then `C:\Users\stewa\ClaudeProjects\Noclip\.env`, loaded inside scripts.
  Gemini works (critics 006 and 007 ran in M1c); ElevenLabs works;
  no PixelLab key. Never read or print keys.
- Everyday tools (all launch Godot through job objects): `check.py`, `shots.py` (`--mode run --bot`),
  `capture.py`, `perf.py` (`--mode run`), `determinism.py`, `export.py` (`--playtest --label`),
  `balance.py` (`--full`, `--bench`), `gallery.py` (every UI state), `bakeoff.py`, `replay.py`,
  `critic.py`, `critic_gemini.py`, `makingof.py` (labeled clips), `progress.py`.
- Game flags: no flags is normal play; `--mode=run --bot=balanced`, `--scenario=<id>`,
  `--replay=<record>`, `--profile-dir=<dir>`, `--debug-hud`; capture and test flags in `main.gd`.

## Gotchas
- **Movie Maker footage is gamma-encoded twice (found 2026-10-17, showcase session).** Every clip from
  `capture.py` is brighter and greyer than the game and its own stills: each channel is the still with
  sRGB encoding applied a second time (an sRGB decode matches the still to 2.5 percent mean error). So
  the Gemini critic has been judging washed-out video. The landing page clips are corrected at encode
  time with an sRGB decode per channel: `format=rgb24,lutrgb=r='if(lte(val,10.31),val/12.92,255*pow((val/255+0.055)/1.055,2.4))'`
  (the same for g and b); the capture pipeline itself is unchanged. Fixing it in `capture.py` (or the Movie Maker colour path) would change what the critic sees.
- **About 15 lights per canvas item.** Godot 2D lets one canvas item take only about 15 lights and
  silently drops the rest. Keep drawings in small nodes and disable idle lights. Lights reach only the
  items whose rectangle contains them: the rock is one mosaic item for that reason.
- **Glow and unshaded drawings (measured in the art pass).** HDR glow works (`hdr_2d=true`, threshold
  1.0). Glow sprites want modulate 0.9 to 1.1 flat; unshaded drawings need a x1.8 to x2.0 boost
  (`ShipView._fn` boost); dividing by the CanvasModulate color blows them out to white. Filled
  shapes with HDR colors ignore alpha: draw translucent fills on an additive layer with plain colors.
  `Environment.set_glow_level` is 0-based (0 to 6).
- **Light height for normal maps:** 120 to 260 px, or sprites come out nearly black.
- **Windows on Stewart's screen.** Capture windows are unfocusable and parked off-screen
  (`game/view/boot.gd`, `tools/proc.py`) but flash for about a second at startup. Batch windowed
  runs, never loop them. Any new bot or capture flag must go into `Boot.BOT_FLAGS`.
- **`check.py --no-import` lies right after a merge** that adds classes or assets: run the full check.
- **`JSON.parse_string` logs an engine error on bad input** (and fails a test): use `JSON.new().parse()`.
- **Shell quoting.** Bash heredocs and the Write tool can mangle backslashes (`\U`, `\u`): write Windows
  paths into files with the Edit tool, and build an em dash only at runtime (`char(0x2014)`).
- **Strict typing:** untyped declarations are errors; `var x := dict["k"]` is too; JSON numbers are
  floats (cast with `int()`); arrays accept index -1, so validate references; a subclass cannot
  redeclare a member of its base (see `Driver`).
- **Commit the generated files:** `.uid` next to scripts, `.import` next to assets.
- **Determinism:** all randomness from `sim.rng.get_stream(...)`, per side for the enemy
  (`world.stream(sim, name)`); the view may use its own hash-based randomness (it never feeds the sim).
- **Perf:** windowed fps is capped at 240 Hz; judge p99 and GPU ms. Perf taken while Black Diamond
  renders is marked untrusted.
- **RAM on this PC** fills up with leftover `node` processes from Claude sessions (about 15 GB was
  seen); git then fails with "getaddrinfo() thread failed to start". Retry later; Stewart restarts the
  Claude app when his sessions are done. Never kill processes by name.
- **Blocked helper:** a PID-based "kill strays" helper was refused by the safety filter. Do not re-add it.
- **GDScript utility names win.** A static helper named like a global utility (`wrap`, `clamp`,
  `snapped`) is shadowed when called unqualified inside its own class: `wrap("text", ...)` called the
  utility and failed every draw of the break-in banner. Name helpers distinctly (`wrap_lines`).
- **Computer use needs Stewart's click.** `request_access` shows him a dialog; if he is away or says
  no, stop the play.py task (the window closes with its job object) and judge with stills and critics.
- **`shots.py` empties its out folder** before each run: give each batch its own `--out`.

## Side by side with Black Diamond
Black Diamond (`C:\Users\stewa\Documents\Claude\Black Diamond`) builds in Godot on this PC at the same
time. Shared rules: `C:\Users\stewa\Documents\Claude\GODOT-SIDE-BY-SIDE.md`.

## Known gaps
`PROGRESS.md` ("Known gaps (M1c)"), `docs/BACKLOG.md` (non-blocking polish) and `review/LEDGER.md`
(critic items deferred to M2).

## Session protocols
- **Checkpoint** (Stewart types it): finish or safely stop the current step, update PROGRESS and
  HANDOFF, commit with explicit paths and push, stop with a two-line summary.
- **End of session:** run `qa-auditor` on PROGRESS and HANDOFF and fix what it finds; confirm
  `python tools/check.py` passes from a clean tree; update PROGRESS, HANDOFF and DECISIONS; commit and
  push; give Stewart a plain-English summary with the next session's launch settings and prompt.
