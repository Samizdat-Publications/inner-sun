# Spec: M1c round D, research and requisitions (something to keep after a death)

For a `builder` (Sonnet) in its own worktree. Read first: CLAUDE.md (hard rules), HANDOFF.md
gotchas, docs/ARCHITECTURE.md (the Profile section and the replay header), docs/plans/M1c.md, then
game/meta/profile.gd and run_record.gd, game/sim/core/sim.gd (`_init`, `options`, `replay`),
game/sim/run/run_state.gd (`begin`, `summary`), game/sim/run/gear.gd, game/sim/events/event_effects.gd
(how a crew member joins), game/view/overlay/death_screen.gd and codex_view.gd (the screen style),
game/view/main.gd (where the profile is loaded, merged and saved, and how a new run starts),
game/view/ui/ui_theme.gd. Godot API dump (git-ignored): read it from the main repo,
`C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\`.

## Why (Stewart, build 3)
"Presumably the user gets to unlock better ships at some point or something. There has to be some
sense of progression or reason to come back, almost like a roguelite where if you die you keep
something that helps in the next run." Ships come in M2 (they need art); this round gives every run
a payout that buys permanent starting upgrades.

## The design
- Fiction: the rig's telemetry reaches TOPSIDE even when the crew does not. TOPSIDE's lab turns it
  into RESEARCH, and research buys REQUISITIONS: equipment loaded onto every later dive.
- Research earned per run, from the run summary alone (a pure static function so tests and the
  death screen agree), shown as a breakdown:
  - 2 per map row reached (summary `rows_reached`),
  - 5 per codex entry learned this run that the profile did not know before,
  - 3 per fight won (`fights_won`), 15 more when the layer gate is beaten (result "won"),
  - 1 per 40 ore gained (`gained.ore`, rounded down).
  Stewart's build 3 run (row 7 or 8, one fight, a few hundred ore) should earn roughly 40 to 60, so
  his first death buys one or two of the cheap items.
- Requisitions are data, one file each in a new table `game/data/requisitions/*.json`:
  `{"id", "name", "blurb", "cost", "order", "effects": {...}}` with effects drawn from:
  `"start_resources": {res: amount}` (added to the ship's start), `"max_hull": n` (max hull and hull),
  `"gear": [gear id]` (fitted at the start through the existing gear code), `"crew": n` (that many
  extra crew from the "survivors" pool, rolled from a stream such as `"meta/crew"`). A lint checks
  ids, costs, resource names, gear ids and pools, and rejects em dashes. First set (tune the costs
  if the bots or the numbers say otherwise):
  - `spare_bits` Spare bit crate: +1 bit. 20
  - `charge_crate` Charge crate: +3 charges. 20
  - `coolant_tank` Second coolant tank: +6 coolant. 25
  - `field_plating` Field plating: +5 max hull. 40
  - `tungsten_start` Tungsten head: start with the tungsten drill head fitted. 60
  - `fourth_hand` A fourth hand: start with a fourth crew member. 80
  Every owned requisition applies to every later run (no loadout choice yet).
- Determinism: owned requisition ids go into the run options (`"requisitions": [ids]`, sorted
  strings, next to `known_codex`), so they are part of the replay header; the sim applies them once
  when the run begins (in `Sim._init` right after `run.begin`, or inside `RunState.begin` if that is
  cleaner; scenario mode ignores them). Replays and RunRecord files must carry them.
- Profile: `research: int` (the balance) and `requisitions: PackedStringArray` (owned), saved and
  loaded (an old profile without them loads as 0 and none). `merge_run` adds the run's research.
  `run_options()` includes the owned ids. Buying: `Profile.buy(id, db) -> String` ("" on success,
  else the reason), deducting the cost.

## The view
- Death screen: a RESEARCH block with the breakdown lines and "+N research, M banked", and a
  "REQUISITIONS [R]" button next to NEW RUN.
- A requisitions screen (new overlay in game/view/overlay/, in the steel and brass style of the codex
  and death screens): the balance at the top, one row per requisition (name, blurb, effect line,
  cost, OWNED or a BUY button, greyed with the reason when unaffordable), CLOSE (Esc). Buying saves
  the profile at once. It sits above the death screen; NEW RUN still starts the next run, which now
  begins with the owned requisitions.
- The run's first seconds: a short toast or the top bar's status line lists what was loaded
  ("REQUISITIONS LOADED: +1 bit, +3 charges"), if a toast system exists; skip otherwise.
- The UI gallery (`tools/gallery.py`) gains the requisitions screen and the new death screen block.

## Owned files
game/meta/**, game/data/requisitions/** (new), a new lint file for it (wire it into DataDB.lint the
way the other tables are), game/sim/core/sim.gd (only the call that applies requisitions and the
options doc line), a new game/sim/run/requisitions.gd for the apply code, game/view/overlay/
death_screen.gd, the new overlay file, game/view/run_screen.gd (mount the overlay), game/view/main.gd
(only what the new screen and the options need), game/view/ui_gallery.gd, game/tests/** (new
test_meta.gd), docs/ARCHITECTURE.md (Profile section), docs/DECISIONS.md (one entry, D040, for the
numbers). NOT game/sim/drill, systems, bots, data/rock, tuning (another agent owns them now). If
run_state.gd must change, keep it to a few lines in `begin` and say so in the report.

## Proof
- `test_meta.gd`: the research formula on hand-made summaries (each line, rounding); profile round
  trip with research and requisitions; an old profile file loads; buy deducts, refuses when short or
  owned; a run with requisitions starts with the right resources, hull, gear and crew; a scenario
  ignores them; a replay from the seed, options and commands of a run with requisitions ends in the
  same hash as the run itself.
- `python tools/check.py` prints `check: ok`; `python tools/determinism.py` matches.
- One windowed batch at most: `python tools/gallery.py` (or the closest flag) for stills of the new
  death screen block and the requisitions screen. Look at them and say what you saw.

## Limits
- Strict typing, files under about 400 lines, no em dashes anywhere, randomness only from
  `sim.rng.get_stream(...)`, tests never write bare `user://` (use `--profile-dir` or a temp dir).
  Commit `.uid` files. Explicit `git add` paths. At most one batch of windowed runs.
- Commit on your branch. Do not merge, push or touch main.

## Report (under 300 words)
What changed, the data and profile shapes, how requisitions enter the replay header, what the stills
showed, check and determinism lines, open problems, your branch name.
