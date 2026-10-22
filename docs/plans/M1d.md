# M1d: Stewart's build 5 notes (prepared 2026-10-17, before he played)

Written by the lead at extra effort so the M1d session (effort high, Stewart's weekly quota from about
80% to 90%) can start executing at once. Fill in the triage table from his notes; the rest is ready.

## Start of the session, in order
1. Read his notes at the top of `docs/STEWART_FEEDBACK.md` (newest heading first).
2. `python tools/run_report.py --since 2026-10-17` (no Godot): per run the result, rows, time, the
   commands by type with when each was first used, the verbs he never touched, and long quiet
   stretches. "Never used" is the first thing to read: a verb he never found is an onboarding
   problem, not a balance one. (On build 3 he never used blast, douse, assign or weapons; one record
   is 8.5 minutes with no input at row 0, an idle window the front killed.)
3. Replay any run he mentions: `python tools/replay.py <record>` (headless, checks the hash);
   `--watch` only when the picture matters.
4. Fill the triage table below: his note, the cause (code, data, onboarding or taste), the change,
   size (S, M, L), who (lead, builder, builder-opus, writer).
5. If he is at the PC, ask him to approve computer use, then play by hand: `python tools/play.py
   --exe -- --mode=run`, `request_access` for `InnerSun.exe`. G, F2, F and the miner card have never
   been pressed by a person.

## Triage table (fill in)
| His note | Cause | Change | Size | Who |
|---|---|---|---|---|
| | | | | |

## The questions build 5b asks (sent to him with the build), and the levers behind each answer
1. **Did you find G, and was the miner worth parking for?** Levers: `game/data/tuning/miner.json`
   (range_m 12, walk_m_s 1.4, hatch_s 2, dig_base_s 0.25, dig_hard_s 0.9, yield_pct 100,
   vein_max_cells 30, hp hits). Bots: balanced sends 1.2 a run, no deaths in 900 runs, haul about 2%
   of ore, so the bots find it marginal.
2. **Did you use blasts (F2), side cutting (A, D, hold depth) and douse (F)?** If not, onboarding (see
   the decision tree), not tuning.
3. **Too easy or too hard, and what killed you?** Balanced bot wins 38% (band 10 to 30%, kept high on
   purpose until he played: D039, D044). Levers: the gate boss (data/ships, gate node), charge prices
   (data/stores), `douse_fire_level`, `structure_chance` (data/layers), the pursuer's speed and noise
   weights (data/tuning), hull.
4. **Buried structures: special, or too many?** About 5 a run. Lever: `structure_chance` (0.3 + 0.02
   per row) in data/layers; loot tables in data/structures.
5. **Do fires, floods and the rock look better?** Hazard visuals (D049) and world depth are new in
   5b/5c; the scorch is still faint.
6. **Did research and requisitions feel like progress?** Six requisitions exist; the PLAN's meta v1
   adds the heavy borer ship and layout variants (M2).

## Decision tree (thought through ahead of his notes)
- **"I never found X" (G, F2, F, hold depth).** Contextual one-time hints, view only plus data: the
  first time a condition holds, TOPSIDE says one line on the radio strip and the key glows on its
  card. Conditions: a vein within 12 m off the path and the front 2+ rows back ("G: send a miner"),
  fault rock ahead and bracing at 0 ("W: bracing soaks rockfalls"), a rich cluster beyond the hull
  and charges in stock ("F2: blast it"), a fire and coolant in stock ("F: douse"). Hints shown are
  remembered in the profile, so each fires once ever. Spec ready: `specs/m1d_onboarding_hints.md`
  (one Sonnet round plus about 12 radio lines).
- **"The miner is tedious."** G twice sends to the best vein in range (the bots' MinerPlanner
  already scores targets: reuse `game/bots/miner_planner.gd` scoring through a pure helper the view
  can call); shorter hatch_s; faster walk.
- **"The miner is pointless."** Give it something the drill cannot do rather than more ore: rare
  **specimens** (a fossil, a crystal, an artefact) that the drill shatters but a miner lifts out
  whole, paid as research and codex entries, the meta currency. Data: a `specimen` material flag
  plus loot. This makes the miner the research verb and ties it to progression. builder-opus, one
  round (sim and bots), then a view round.
- **"The dig is still samey."** The PLAN's M2 burrowers answer it best: creatures that latch onto
  the hull while drilling and chew a room until crew repel them (assign) or the weapons shake them
  off; they come in fault rock and near hollows. That is "more to manage" during the dig, uses crew
  and weapons, and is already in the approved plan. Next after onboarding. Design and spec ready:
  `specs/m2_burrowers.md` (builder-opus for the sim, then a view round with a painted sprite).
- **"Too easy."** First the gate boss and charge prices; then structure loot. Re-run 300 per bot
  after each change and keep balanced inside 15 to 30%.
- **"Too hard" or "the front is unfair."** Pursuer speed and noise weights; the HUD's pursuit
  warning lead time.
- **"The screen is too busy, the text is small"** (also critics 24, 30, 38). A UI pass: icons for the
  power job lines, larger critical numbers (hull, depth, front distance), the store as cards rather
  than a table. A builder round with gallery stills (`python tools/gallery.py`).
- **"I want to unlock things."** The heavy borer ship (PLAN M2 meta v1) as the first big unlock,
  bought with research; layout variants later.

## Ready to dispatch without his notes
1. **Split the oversized files** with zero behaviour change: drill_sim.gd 595, run_state.gd 563,
   scanner_panel.gd 529, main.gd 522, drill_miner.gd 497, policy_bot.gd 467, crew_sprite.gd 454,
   ship_view.gd 694. The oracle is free: `python tools/determinism.py` must still give
   e4c82e3d6d55a625 and a 300-run balance report must match the old one exactly per seed. A Sonnet
   builder for view files, builder-opus for sim files; never both on the same file.
2. **PARKED notice in amber**, not alarm red (parking is a choice, not an emergency):
   `RunScreen.set_notice` takes a style by notice kind (`AlertsStrip.drill_stop` returns the kind).
3. **Scorch that shows** on dark floors: a multiply-blend material (CanvasItemMaterial
   BLEND_MODE_MUL) for the scorch nodes in `game/view/ship/room_fire.gd`, so it darkens the art
   instead of fading under it.
4. **A critic capture that shows the miner**: Gemini 008 never saw it. Find a seed where the balanced
   bot sends a miner in the first 4 minutes (the balance runs' per-seed `sorties` counter, or add
   `sortie_first_s` to the summary), then capture that seed.
5. **Regenerate the drill crown art** (Stewart, 2026-10-22, with a screenshot): the painted crown
   under the tower "looks really cool" but has generation errors, two stray cone-shaped pieces
   among the cutter teeth right of centre. `game/assets/ship/drill_crown_{albedo,normal,emission}.png`
   (Gemini art pass, `docs/SPEND.md` "fit_crown"). An asset-smith round: about 8 candidates from the
   same prompt and style reference, each with its normal and emission maps, a contact sheet; the
   lead drops any with stray parts and shows Stewart the best two or three to pick from. Same size
   and anchor so `ship_view.gd` needs no change. About 1 to 2 USD; log it in `docs/SPEND.md`.
6. **Known, unreachable today:** a fight started mid-dig returns the run to "idle"
   (`game/sim/combat/combat_sim.gd:114`, `_return_phase`); only matters once structure events may
   start fights (D042 forbids it). Fix it in the same change that allows them.

## The bridge to M2 ("The Crust, complete", PLAN.md section 4)
| M2 item | Status |
|---|---|
| Art pass in the chosen style | Painted rooms done; fire, smoke and water (D049); world depth (5c); crew work poses, UI pass, particles that match the painted style still to do |
| Burrowers that latch onto the hull; Soviet automata | Not started (burrowers first, see above) |
| Away teams through the airlock | The away miner is the first step (D046); next: a team into a buried structure |
| Gas; sonic emitters | Gas done; sonic emitters not started |
| About 30 events | 17 (12 dossiers, 5 structure events): a writer round |
| 2 store types; a layer-gate boss | Done (crust and hollow traders; the gate boss) |
| Codex and meta v1 with the heavy borer unlock and layout variants | Codex, research and six requisitions done; the heavy borer not started |
| Mid-run save; settings; audio pass; voiced radio | Not started |
Suggested order after M1d's fixes: onboarding hints, burrowers, specimens for the miner (if he
wants the miner to matter more), the heavy borer unlock, a writer round to 30 events, then save,
settings and the audio and voice pass.

## Budget pacing for 80% to 90%
Measured in the 2026-10-17 session: from 75% to 76% for the polish, the away miner (builder-opus
371k tokens, about 70 minutes; Sonnet view 347k, about 25 minutes), the hazard visuals (Sonnet 257k)
plus the lead's fixes, a Gemini critic, a QA audit and two exports. So 10% is roughly: triage and
hands-on play 1%, six to eight builder rounds, two exports with critic and QA 0.5%, and a 1% reserve
for the handoff. Check `get_usage` after every merge; stop at 90% with a complete build.
Lessons that saved tokens: the lead verifies every builder's stills itself (builders tuned blind
twice); a loud debug colour settles "does it draw" in one windowed run; builders must not leave
background jobs running (one kept waking itself and re-sending its report).
