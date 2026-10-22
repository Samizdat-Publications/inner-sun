# Spec: split the oversized scripts, zero behaviour change (M1d, "Ready to dispatch" item 1)

## Goal
Bring eight scripts back under about 400 lines (CLAUDE.md conventions) by moving whole functions
into new helper files, without changing what the game does. Nothing a player, a bot, a replay or a
test can observe may change: same determinism hash, same balance results seed by seed.

## Two rounds, never on the same file
| Round | Agent | Owns (and only these, plus the new files it creates next to them) |
|---|---|---|
| Sim | builder-opus | `game/sim/drill/drill_sim.gd` (595), `game/sim/run/run_state.gd` (564), `game/sim/drill/drill_miner.gd` (497), `game/bots/policy_bot.gd` (467) |
| View | builder (Sonnet) | `game/view/ship_view.gd` (695), `game/view/main.gd` (582), `game/view/hud/scanner_panel.gd` (529), `game/view/ship/crew_sprite.gd` (454) |

Each round works in its own worktree from the commit named in the dispatch message.

## How to split
- Move cohesive groups of functions into a new `RefCounted` (sim, bots) or helper `Node2D`/static
  class (view) in the same folder, named for what it does (for example `drill_yields.gd`,
  `run_map_moves.gd`, `ship_view_rooms.gd`). Keep the original class as the public face: every
  method other files call keeps its name and signature on the original class (a one-line forward is
  fine). Do not rename public members, events, commands, tuning keys or data fields.
- Sim rules stay sim rules (hard rules 1 to 5): new sim files are plain `RefCounted`, no Nodes, no
  `Time`, no autoloads, randomness only through the streams the moved code already uses, in the same
  order. Never change the order in which random draws, events or resource changes happen.
- State: `state()` arrays must come out identical element by element (same order). If a moved
  helper owns state, the original's `state()` still builds the same array.
- Strict typing everywhere; check 4.7.2 signatures in `harness/out/godot-api/doc/classes/` of the
  main checkout (`C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\`).
- Commit the `.uid` files Godot writes next to new scripts. Files under about 400 lines each.
- No new features, no tuning, no comment rewrites beyond what the move needs.

## The oracle (both must hold before you report)
1. `python tools/check.py` prints `check: ok`.
2. `python tools/determinism.py` gives the hash recorded in the dispatch message (headless and
   Movie Maker must agree; this is one batched windowed run, the only one allowed).
3. A full balance run on the same seeds as the baseline:
   `python tools/balance.py --full --runs 60 --procs 6`, then
   `python tools/balance_compare.py <baseline results.jsonl> <your results.jsonl>` must print
   `compare: ok` (the baseline path is in the dispatch message).
The view round needs only 1 and 2 plus `python tools/shots.py --names start,fire,arrive --out
harness/out/shots_split_view` (look at the three stills: they must match the baseline stills named
in the dispatch message).

## Hard rules for this round
- Touch only the files you own and the new files you create. Stage explicit paths; never
  `git add -A`. Do not push; commit on your branch and report.
- Never export, never touch `builds/`. At most one windowed batch (determinism, and shots for the
  view round). Leave no background jobs running when you report.

## Report (under 250 words)
New files with line counts, old files' new line counts, what moved where in one line each, the
three oracle results verbatim (`check:`, the hash, `compare:`), and anything you could not split
without a behaviour change (leave it, say why).
