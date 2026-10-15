# Spec: M1 step 5, events, store, crew (sim side)

For a builder-opus agent after step 3 (can run beside step 4 if files stay disjoint). Read
CLAUDE.md, docs/ARCHITECTURE.md, docs/STYLE_GUIDE.md (the event file format and effects are
defined there; implement exactly that), game/data/events/*.json (three examples), RunState, Systems.

## Event runner (game/sim/events/encounter.gd and helpers)
- `start_event(sim, node)`: pick an event whose kind matches the node (event, cavern, hazard), whose
  layer matches and whose rows include the node's row, not yet used this run when once_per_run,
  weighted, from the "events" stream. Pick the event's crew member (first live crew member unless the
  event says otherwise). Phase `dialog`.
- Command `{"type": "choose", "option": i}`: checks requirements (res, system bars, crew skill,
  codex), rolls the outcome by weight from the "events" stream, applies effects in order, then goes to
  the outcome's page or ends. On a page without options, choose 0 ends the event.
- The event ends to idle, unless an effect started a fight (combat) or opened a store (store).
- Effects exactly as listed in the style guide. Hazard effects act on the player's ship
  (`system:<name>` picks the room with that system; `random` from the events stream). `reveal` and
  `pursuer` call RunState. `codex` calls `run.learn`. `crew_join` adds a crew member from
  `game/data/crew/<pool>.json` (name, skills) with a free station; `crew_lose` kills one
  (permadeath, emits crew_died with cause "event").
- state(): current event id, page, picked crew, events used this run, store state.

## Store
- `open_store(sim, node)`: phase `store` with the layer's store (`game/data/stores/<id>.json`):
  stock lines with item, amount, price (gems), limits. Items: resource packs (coolant, cells, bits,
  charges), hull repair paid in ore (1 hull per 2 ore), weapons (adds to the next free slot), a crew
  hire (from a pool), system upgrades (+1 bar to a system, capped by the system data).
- Commands `{"type": "buy", "item": i, "qty": n}` and `{"type": "leave"}`.

## Lint (Encounter.lint)
Every event: id, kind, layer, rows, start page exists, every page referenced exists, every option
has outcomes with positive weights, every effect type is known with valid fields, every codex id,
enemy ship, store and crew pool exists, requirements name real resources, systems and skills, no
em dash anywhere. Stores, crew pools, codex entries and radio triggers checked too.

## Tests
Determinism of event picks and outcomes; requirements gate options; each effect type changes the
sim as specified (one test each); a fight effect enters combat; store purchases spend gems or ore
exactly and respect limits; crew join and loss; once_per_run respected over a run; replay matches.

## Writer (after this lands)
The writer agent adds about 8 more crust events (mix of event, cavern, hazard, one recruit), their
codex entries, a crew pool of survivors and defectors, store blurbs, and more TOPSIDE lines, in the
style guide's voice, then runs the lint.
