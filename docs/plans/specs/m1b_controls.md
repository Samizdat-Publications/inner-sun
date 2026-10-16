# Spec: M1b round 1, make the controls work for a human (view only)

For a `builder` in its own worktree. Read CLAUDE.md, HANDOFF.md (gotchas), docs/ARCHITECTURE.md (view
rules), then game/view/main.gd, game/view/run_screen.gd, game/view/hud/*.gd, game/view/overlay/*.gd.
The Godot API dump is git-ignored: read it from the MAIN repo,
`C:\Users\stewa\Documents\Claude\Inner Sun\harness\out\godot-api\doc\classes\`.

## Why
Stewart's first playtest (docs/STEWART_FEEDBACK.md, 2026-10-16) found nothing to do but steer. The
lead then played the exported build with real keyboard and mouse and found these defects. Every one
of them is in the view; the sim is not to change in this spec.

## Owned files
game/view/main.gd, game/view/run_screen.gd, game/view/hud/*.gd, game/view/overlay/*.gd, one new
`game/view/overlay/help_view.gd`, new tests under game/tests/ (see "Tests"), README.md ("How to play"
only). Nothing in game/sim, game/bots, game/data, game/meta.

## Fixes, in priority order

1. **Hold the world while the node map is open (human play only).** Today the map opens in run phase
   "idle", which is a world phase, so the pursuer advances and strikes while the player reads the map:
   sitting on the first map for 3.5 minutes killed the ship at depth 0. In main.gd: when not
   `bot_driven`, not replaying, and the map overlay is open, do not step the sim, EXCEPT when the sim
   has queued commands (so a choose_node, power or crew order still applies: step exactly once per
   frame while commands are queued). Use `run.sim.has_pending()` (added by the lead for this).
   Show "PAUSED: MAP" or similar in the existing paused indicator so the player knows time stopped.
   Dialog and store phases already freeze the world in the sim; leave them.
2. **Power works while a dossier is open.** Power keys are gated by `sim.run.world_running()`
   (power_panel.gd:134), and the dossier's full-screen backdrop eats clicks on the power panel. But
   dossier options require power ("REQUIRES: HELM AT 2 BARS"), so the player cannot meet them. Allow
   power keys and power-panel clicks in phase "dialog" (and "idle"); keep the backdrop from blocking
   the power panel (MOUSE_FILTER_IGNORE on the dim backdrop, STOP only on the paper). The dossier must
   re-check option requirements live, so an option lights up as soon as the bars are in.
3. **Power changes give instant feedback, and repeated presses stack, even while paused.** Today a
   key press pushes an absolute target computed from `sys_want`, which only changes when the sim
   steps: while paused, pressing Shift+R twice queues "drill 2" twice (one step, not two) and the
   panel shows nothing until unpaused. Keep a per-row pending want in the panel (set on push, used
   for the next press and for drawing the wanted bars, cleared when the sim's value catches up or the
   tick advances past the push). Show pending bars clearly (outlined or blinking) while paused.
4. **Pause when a fight starts (human play only), and say what to do.** In the lead's test the rival
   knocked out all weapon bars and the reactor before a player could react, two crew died, and flee
   was impossible. When combat begins (phase becomes "combat" or `sim.enemy` appears), set `paused`
   and show a banner over the world area: "HOSTILE CONTACT. Paused. Power weapons (E) and bracing
   (W), arm a gun (F1, F2) and click an enemy room. Space to fight." Hide it on unpause.
5. **Warn before a fight.** While drilling toward a fight or gate node, show an alert in the alerts
   strip: "HOSTILE AHEAD: power weapons (E) before you arrive". Same for hazard nodes ("HAZARD AHEAD").
6. **Scanner click-to-steer does nothing.** Two real clicks inside the scanner screen (right side,
   mid height) left TGT at +0 (scanner_panel.gd:218). Find out why with a real input-event test (see
   Tests), fix it, and make a click set a course that holds (TGT shows the new value).
7. **Change bit has no binding.** The `change_bit` command exists (drill_sim.gd:138) but no key or
   button sends it. Bind **B**, and show "[B] NEW BIT (n left)" in the scanner readout when bit wear is
   above 50% (clickable). Disabled with a reason when no bits are left.
8. **In-game help.** A help overlay (new help_view.gd) opened with **H** and by a "HELP [H]" chip on
   the top bar; it pauses while open; Esc closes. One screen: the goal, the controls (match README
   "How to play"), and three short "when X happens" lines (flooding, fire, damage) from the lead's
   text below. Open it automatically on the first run of a fresh profile (`profile.runs == 0`).
9. **Death text names the real killer.** A hull death in a fight reads "Hull breached. The rock took
   the tower apart one plate at a time" (death_screen.gd). Pick the text from what was happening:
   in combat (enemy present) blame the rival rig or the gate machine; caught by the pursuer blame
   the front; otherwise the rock. Keep the existing tone.
10. **Flood hint.** When the drill room's water passes 1.2 m, alert: "DRILL ROOM FLOODING: crew won't
    wade in on their own. Select one (1-3) and click the drill room." (Auto crew skip rooms deeper than
    1.4 m, crew_ai.gd:44, and a drill room full for 10 s ends the run.)

## Help text (use as written; no em dashes anywhere)
- Goal: drill down through the Crust to the gate at the bottom of the map. Pick a route on the map,
  drill there, deal with what you find. Mine ore and gems on the way; spend them in trading posts.
- Something is following your noise (the red front on the map). Louder drilling (more drill power)
  draws it faster. If it catches you it strikes the hull every 10 seconds.
- Flooding: water pockets (blue on the scanner) and breaches let water in. Crew patch breaches;
  pumps run while COOLANT AND PUMPS has power. Crew will not wade into deep water on their own:
  order one in (1-3, then click the room).
- Fire: crew put fires out; fires grow, spread through doors and hatches, and break systems.
- Damage: crew repair broken power bars on their own; power comes back after a repair. Hull only
  comes back at a trading post (2 ore a point).

## Tests
- A new test that drives REAL input through the viewport (`Viewport.push_input` with InputEventKey /
  InputEventMouseButton at the on-screen positions of the controls) against main.tscn in run mode,
  and asserts the resulting sim commands: a power key, a power-panel click, Shift-key removal twice
  while paused (two steps), a crew key then a room click, a map node click, a dossier option key, a
  scanner click (steer), B (change_bit), H (help opens, world held). If push_input does not reach GUI
  controls headless, say so in the report and make the test windowed through tools/ only if the lead
  agrees; do not open windows in a loop.
- `python tools/check.py` prints `check: ok`; `python tools/determinism.py` still matches.

## Limits
- View only. Bots and replays must behave exactly as before (they never pause or hold).
- At most 2 windowed runs (`python tools/shots.py ...`) for a before/after look; batch them.
- Strict typing, files under about 400 lines, no em dashes, commit `.uid` files.
- Commit on your branch with explicit paths. Do not merge, push or touch main.

## Report (under 300 words)
What changed per item (1 to 10), the cause of item 6, test names and results, the check and
determinism output lines, anything you could not do and why.
