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
