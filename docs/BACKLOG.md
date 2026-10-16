# Backlog

Polish and follow-ups raised during M1 that are not blocking the M1a playtest. Pull items into a
milestone checklist when they matter; delete them when done.

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
