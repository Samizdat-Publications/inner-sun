# Spec m2p_views_a: door and purge clicks, the station skill, bars up to the new tops (parity round 6a)

Parity workstream P3, round 6a (PLAN.md section 10, D056, D080). Builder: `builder` (view and UI),
in its own worktree off `claude/blissful-neumann-c52d9b`. The sim rules are built and tested; this
round only lets the player see and use them.

## Firewall (read first)
Work from this spec and the rows it names in `docs/research/behavior-ledger.md` only. Do not open
`docs/research/ftl-*.md`, `research_private/`, or any page about another game.

## Rows this round serves
L-DOR-01 (the toggle and its real-input self-test), L-DOR-F1 (doors and purges read at a glance),
L-MAN-03 (the crew card shows the station skill), L-ENV-01 (environments shown on the map before the
player chooses). Leave their Status lines to the lead.

## What the sim already offers (do not change any of it)
- Command `{"type": "door", "link": <link id>, "open": bool}`: refused with `bad_command`
  {"type": "door", "why"} when there is no such link or it is already in that state; emits "door".
  Applies in any phase (pause is the view not stepping; it applies on the next step).
- Command `{"type": "purge", "room": <room id>, "open": bool}`, same rules; state:
  `sim.hazards.is_purged(room_index)`; emits "purge"; a fire put out by it emits "fire_out" with
  "by": "purge". While purged the room takes rock heat (it can hurt crew deep down).
- `CrewMember.skill_station` (0.9 to 1.7 in the data), next to `skill_fire` and `skill_repair`.
- System tops are now higher: helm 4 bars, bracing 6, weapons 5, drill 6, coolant 5, reactor 14.
- Environments (round 5): each map node may carry `"env"` (an id in `game/data/environments/*.json`,
  with `name` and `blurb`); `RunState.env_id` and `env` are the one in force; `scanner_blind` hides
  nodes past the current row (`RunState.is_revealed` already applies it);
  `RunState.rival_rooms_hidden()` says the combat view must hide the rival's rooms; events
  "env_entered" {"env", "node"} and "env_left" {"env"}.

## Files you own (touch nothing else)
`game/view/ship/room_art.gd` (doors already swap `door_open` and `door_closed` art; add a closed hatch
lid and the purge look), `game/view/ship_view.gd` and `game/view/ship_view_build.gd` (hit targets),
`game/view/main_input.gd` (the clicks), `game/view/hud/crew_cards.gd`, `game/view/hud/power_panel.gd`
(only if bars do not fit), `game/view/overlay/map_view.gd` and `game/view/overlay/survey_marks.gd` (the
environment marker), the scanner files under `game/view/hud/` (`scanner_panel.gd`, `scanner_draw.gd`,
`scanner_extras.gd`: the blind look), `game/view/combat_view.gd` and `game/view/hud/enemy_panel.gd`
(the hidden rooms), `game/view/hud/dig_callouts.gd` (the entered callout), the help page (find it under `game/view/overlay/` or `game/view/hud/`), a new
helper file under `game/view/ship/` if a file would pass 400 lines, `game/tests/ui_selftest.gd` (the
real-input self-test), `game/tests/test_ui.gd` or a new view test, and the gallery state list if a
new still is needed (`game/view/ui_gallery.gd`). Do not touch `game/sim/**`, `game/bots/**`,
`game/data/**` or `tools/**`; two other builders are changing sim, bot and balance files right now.

## What to build
1. **Doors and hatches.** A left click on a door or a hatch in the ship cutaway toggles it (push the
   `door` command with the opposite of `Link.open`), paused or not, before any crew order or room
   click is considered (a door's hit box: its sprite; a hatch's: its rim, a few px larger). A closed
   hatch gets a visible lid (a dark plate over the rim drawn in the same painted style, or a simple
   shape if no art exists; say which). Hovering a door or hatch shows the pointing-hand cursor.
2. **Purge.** Each room gets a small vent button in a top corner of its cutaway (an icon that reads as
   a vent, never text-only), a click toggles `purge`. A purged room reads at a glance: the vent button
   lit, and a cold grey-blue draught pulled toward the vent across the room (a few soft particles or
   a scrolling gradient), plus a "PURGING" tag in small caps by the room name. When the purge puts a
   fire out, the existing "FIRE OUT" callout shows (it may already; check `dig_callouts.gd` reads
   `"by"`; add "PURGED: <ROOM>" in the same style if it is cheap).
3. **Help page.** Two lines in the existing voice: "Click a door or hatch to shut it: fire crawls
   through a shut door far slower." and "Click a room's vent to purge it: the fire dies in seconds,
   but deep down the rock's heat comes in."
4. **Crew cards.** A third skill, "STATION 1.3", with the same bar style as FIRE and REPAIR; keep
   the card readable at its current size (rearrange the skill row if it does not fit).
5. **Bars up to the new tops.** Check the power panel and the room art with every system at its top
   (reactor 14, drill 6, bracing 6, weapons 5, coolant 5, helm 4). Fix anything that overflows or
   overlaps.
6. **Store stamp.** The store's "ALL SALES FINAL" stamp was moved 16 px down after a still showed it
   overlapping a sell price; it was never re-rendered. Include the store in your gallery batch and
   look at it.

7. **Environments.** On the map, a node with an environment shows a small marker (one simple icon per
   kind: falling slabs, a heat shimmer or flame, a compass needle or static, a gas cloud) and its
   name and blurb in the node's hover or detail text, before the player chooses. On "env_entered" a
   callout in the existing style names it ("ROCKFALL SEAM"), and the HUD shows the one in force
   until "env_left". While `scanner_blind`, the scanner shows static or snow over its picture with
   "NO SIGNAL: MAGNETITE" instead of the survey; while `rival_rooms_hidden()`, the rival's room
   interiors in the combat view are drawn as a dark silhouette (hull outline only, no rooms, fires or
   crew) and the enemy panel says its systems are unreadable.

## Tests and checks
- `ui_selftest.gd`: a real-input click on `door_low` closes it (Link.open false on the next step),
  a second click opens it; a click on a room's vent purges it and a second click stops it; both
  while paused too. This closes L-DOR-01's toggle clause.
- A view unit test that hit-tests door, hatch and vent positions (no window).
- Stills (at most two windowed batches in total, `python tools/gallery.py` and/or
  `python tools/shots.py --names <...> --out harness/out/shots_m2p_views_a`): (a) doors closed around
  a burning room, one hatch closed; (b) a purging room; (c) the crew cards; (d) the power panel with
  every system at its top; (e) the store; (f) the map with environment markers; (g) a blind scanner
  and a hidden rival in a fight (a scenario with `set_env`, which works in scenario mode only). Look at every still yourself and say what you saw.

## Commands that must pass
`python tools/check.py` prints `check: ok` (full run with import, first); `SELFTEST ok`.

## Report (short)
What each still shows (paths), what you changed, tests added, anything you could not do and why,
branch and final commit. Commit with explicit paths, messages without em dashes, ending with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not push or merge.

## Addition (2026-10-22, from Stewart's build 6 notes via the M1d session)
Crew selection on the ship: a click on a crew figure selects it (Shift+click adds or removes), a drag
from empty floor draws a box that selects every figure inside, and a click on a room then sends every
selected crew member there with one existing `assign` command each (no new sim command, so replays
stay plain commands). Selected figures get a ring; Esc or a click off the ship clears it. Door, hatch
and vent clicks keep priority. Real-input self-test and one still. The M1d session is changing
`ship_view*.gd`, `main.gd`, the scanner files, `run_screen.gd`, `alerts_strip.gd`,
`hint_director.gd` and `crew_sprite.gd` on main at the same time: keep edits there small and new code
in new helper files; `douse_layer.gd` and `room_fire.gd` are off limits.
