# Backlog

Polish and follow-ups raised during M1 that are not blocking the M1a playtest. Pull items into a
milestone checklist when they matter; delete them when done.

## Gemini audit (2026-10-22, each checked by the lead; details in `review/consults/2026-10-22_gemini-4-argon.md`)
Fixed in the M1d interim round (2026-10-22), each with a test:
- Blast planner scored rock at full yield: now blast_yield_pct of each material, rounded down, as a
  blast pays (`test_dig_verbs::test_blast_planner_values_what_the_blast_pays`).
- Greedy bot bought a weapon it could not power: the weapons upgrade counts only when on sale and
  still affordable after the weapon (`test_bots::test_greedy_buys_no_weapon_it_cannot_power`).
- Balance reports showed hull 40 at row 0: `FullRunStats` read the end-of-run maximum hull. Row 0 is
  now `RunState.start_resources`, requisitions included (`test_meta::test_run_stats_row_zero_is_the_start`).
- State hash: `ShipWorld.state()` now carries `hull_max` and the weapon list
  (`test_determinism::test_state_hash_covers_max_hull_and_weapons`); the determinism hash changed.
- Scenario rock heat: `drill.json` now 0.033 C per m like the Crust (`test_data::test_scenario_rock_heat_matches_the_crust`).
Checked, not a bug: rival power restore vs the rival AI. A hit on the weapons costs only the broken
bar, the plan gives the spare bar to coolant, and after the repair the weapons are back at 3 bars
within one AI think (`test_combat::test_rival_power_follows_its_plan_after_damage_and_repair`).
Open (design, not a bug): two event options no bot picks (`cold_spring` option 0 is the fallback
when the second coolant loop is down; `byrd_signal` option 0 trades the front for three rows of
map). Kept for players; revisit only if Stewart's runs show nobody picks them either.

## Events and writing
- A `{joined}` placeholder for the crew member who just joined (recruit pages now say "the survivor").
- A requirement "crew pool not empty" so recruit text never lies when the pool is exhausted.
- A playthrough test for every event and option (meet each option's requirements; allow a fight to
  end the dialog), not just the three reference events.
- The style guide's 40-word floor: apply it to intro pages only, or pad the short ending pages.
- Store upgrade lines carry `max_bars`; move the cap into the system data files.

## Systems and drilling
- Bracing at 2 bars per layer on a 2-bar room is one layer until upgraded; watch whether combat
  feels binary at the playtest.
- Coolant drains while idle (intended pressure); keep coolant cheap and steady in stores.
- Fire damage plus spread can still death-spiral; watch the balance report.
- The 8 m crown makes dodging water pockets hard; consider fewer, more readable obstacles.

## Sound
- `fire_crackle_loop` is quiet after normalization; `crew_hurt` and `ui_hover` have a low wobble in
  their tails; `typewriter_key_2` and `_3` ring long. Nobody has listened yet: Stewart at the playtest.

## View and art (from the M1a view agents)
- Combat rock: the procedural fill outside the drilled grid meets the lit grid rock at a visible edge,
  and its tiling repeats visibly.
- The painted crown hangs about 1.7 m below the hull over rock the sim has not cut (the cut footprint
  stops at the hull bottom); a taller footprint is a sim change.
- Frame-animated crew (Lindqvist, rivals) have no dedicated climbing pose; the hammer and weld work
  animations were never seen in a captured frame.
- Rock tile mipmaps are off (`.import` generate=false): slight shimmer at 0.5 scale.
- Heat shimmer above 50 C has not been seen in any frame.
- A fifth crew card would overflow the right column; the modal overlays were not re-centred on the
  new world rect (they overlap the slim alert strip by about 10 px).
- The weapon card charge text is half light, half dark where the bar fill ends.
- The bake-off lamp sprite carries a faint dark box; rival_a reads a little like an astronaut.
- The plain granite tile reads as cobblestones (the dense tile stands in); regenerate when the Gemini
  cap lifts.

## Play (from the balance report, first M1b candidates)
- The middle rows rarely threaten the hull; rivals feel scripted (the light rival dies in the same
  40 to 57 s fight on many seeds); gems pile up unspent (about 50 at the gate); ore makes hull
  repairs nearly free; the thermal lance is almost never bought; drill bits never break; flee rarely
  happens because the drill room is often damaged by then.
