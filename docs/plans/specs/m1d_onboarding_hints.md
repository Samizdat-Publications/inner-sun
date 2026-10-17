# Spec: one-time hints that teach the verbs in play (M1d, ready to dispatch)

For a `builder` (Sonnet) in its own worktree, plus a short `writer` pass for the lines (or the lead
writes them; there are about 12). View, meta (profile) and data only: nothing in game/sim changes.
Dispatch it when Stewart's notes or `python tools/run_report.py` show verbs he never used (on his
build 3 run: blast, douse, assign and weapons, never touched).

## Why
Both of Stewart's playtests hit discovery first: "I don't see anything I can do" (build 2), "my bit
broke and can't move, how do I fix that?" and "I can't seem to see what [helm and bracing] do"
(build 3). The help page (H) lists everything, but nobody reads a manual mid-dive. Teach each verb
the first time it would pay off, in TOPSIDE's voice, once ever.

## Design
- A hint fires when its condition first holds in play, once per profile ever (remembered in the
  profile, so a new run does not repeat it), at most one hint every 20 s, never while an overlay is
  open, never in a fight (except fight hints), never in bot, capture or replay runs.
- It shows as a TOPSIDE line on the radio strip (the same place and look as the existing radio
  lines, data in `game/data/radio/`) plus a 6 s glow on the card or panel that owns the key (the
  blast card, the miner card, the power row, the crew card), so the eye goes to the control.
- Conditions are pure functions of the sim state (the view only reads), each in a static helper with
  a test:
  | Hint | When | Says (gist; the writer words it) | Glows |
  |---|---|---|---|
  | power | the drill has 0 bars while drilling for 3 s | Q W E R T give a system power, Shift takes it back | power panel |
  | steer | 20 s into the first dive without a steer command | A and D turn the drill toward the ore on the scanner | scanner |
  | hold_depth | a vein beside the ship, level with the drill head | turn to 90 to cut sideways along a seam | scanner |
  | miner | a yielding cluster within 12 m off the path and the front 2+ rows back | G sends a crew member to dig it by hand | miner card |
  | blast | a rich cluster within 14 m, charges in stock, weapons powered or not | F2 then click: a charge cracks it open, half the ore survives | blast card |
  | bracing | fault rock within 4 m ahead and 0 bracing layers | W: bracing soaks rockfalls | power row W |
  | douse | a room burning above 0.3 and coolant in stock | F douses the worst fire for one coolant | the DOUSE button |
  | bit | the bit breaks | B fits a spare | the alert |
  | crew | a fire or breach no crew member is heading to | 1 to 3 picks a crew member, click a room to send them | crew cards |
  | weapons | the first fight starts | F1 and F2 arm a weapon, click an enemy room to fire | weapon cards |
  | requisitions | the first death screen with research to spend | R opens requisitions: research buys starting gear | the button |
  | map | the first map choice | survey marks show what is in the rock on the way | survey log |
- **From Stewart's build 5c run (2026-10-17, must be covered):** he asked "is there a pause button",
  "do I have to turn off power to stop the drill and deploy the miner?" (he cut the drill to 0 bars
  by hand), "I'm at an old mine shaft, how do I exploit it, do I send the miner?", and douse "isn't
  doing anything". So add:
  | Hint | When | Says (gist) | Glows |
  |---|---|---|---|
  | pause | the first fire, the first fight or the first miner sent, whichever comes first | Space pauses; orders still work while paused | the top bar's clock |
  | structure | a buried structure within 15 m of the drill head (its scanner box in view) | cut into it with the drill or a blast: crates pay at once; G sends the miner to a crate in range | scanner |
  | miner (extend) | as above | add: the drill parks itself, no need to cut its power | miner card |
  | douse (first fire) | as above | add: one coolant per press, 6 s to vent again | DOUSE button |
  Also, without waiting for a hint: the scanner's structure label gets a second line "CUT IN FOR
  CRATES" until it is broken into, and the miner card's ready line reads "G, THEN CLICK THE ROCK.
  THE DRILL PARKS ITSELF." (`game/view/hud/scanner_extras.gd` and `miner_card.gd`, both owned below).
- Data: new radio triggers `hint_<name>` in `game/data/radio/topside_crust.json` (one or two lines
  each, the style guide's voice, no em dashes); extend the radio lint's trigger list. The view picks
  a hint's line by a hash of the profile's run count, never the sim's streams.
- Profile: `hints_seen: PackedStringArray` in `game/meta/profile.gd` (saved, loaded, merged; old
  profiles without it load fine). Settings later can reset it; for now a dev flag `--hints-reset`.

## Owned files
New `game/view/hud/hint_director.gd` (HintDirector: conditions, pacing, glow requests),
`game/view/run_screen.gd` and `game/view/main.gd` (build and bind it; keep main.gd's edit tiny),
the cards that glow (`hud/blast_card.gd`, `hud/miner_card.gd`, `hud/power_panel.gd`,
`hud/crew_cards.gd`, `hud/scanner_panel.gd`, `hud/scanner_extras.gd`, `hud/top_bar.gd`: a `glow(seconds)` method each where they glow, drawn as a pulsing
brass outline), `game/meta/profile.gd`, `game/data/radio/topside_crust.json`, the radio lint
(`game/sim/events/encounter_lint.gd`, the trigger list only), `game/view/boot.gd` only if a flag must
be listed, tests `game/tests/test_hints.gd`, README (one line).

## Checks
`python tools/check.py` prints `check: ok`; tests cover every condition helper, once-ever memory, the
20 s pacing and the bot or replay suppression. Stills (at most 3 windowed jobs): a run started with
`--hints-reset` and no bot is not possible headless, so add a dev flag `--hint=<name>` that forces
one hint at t=2 for stills, and shoot three of them (`shots.py --mode run --extra=--hint=miner`).
Stage explicit paths only; commit on your branch with the Co-Authored-By line; do not push or merge.
