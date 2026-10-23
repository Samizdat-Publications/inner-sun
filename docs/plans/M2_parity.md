# M2 workstream P: FTL parity on chosen systems (checklist)

Plan: `PLAN.md` section 10. Decisions: D052 to D055. Research: `docs/research/ftl-reference.md`
(sources and the scored inventory), `behavior-ledger.md` (rows), `ftl-observation-plan.md`,
`ftl-difftest-plan.md`. Starts after M1d closes.

## Firewall, every step
- Observers (the lead, in the main checkout) may read `research_private/` and the links in
  `ftl-reference.md`. Builders may not: they work in worktrees from ledger rows only, and their specs
  say "do not open `docs/research/ftl-*.md`, `research_private/` or any FTL page".
- Committed files hold behavior in our words and Inner Sun targets. Exact FTL values go to
  `research_private/ledger_evidence.md` under the row's evidence ID.
- No FTL names, text, art, audio or data files in the repo. The data lint already rejects em dashes;
  reviewers also check new data for borrowed names.

## P1: Stewart's pick
- [x] Stewart picks systems from the top 10 (and any lower row he wants). Log it in
      `docs/STEWART_FEEDBACK.md` and mark the picked rows in the inventory. Done 2026-10-22 (D056):
      inventory 1 to 6.

## P2: rows and observation
- [ ] Back up `C:\Users\stewa\Documents\My Games\FasterThanLight\` to `research_private\` before any FTL session.
- [x] For each picked system: number, shape, rule and feel rows in `behavior-ledger.md`, each with an
      evidence ID, an Inner Sun target band, a named test and a wrong value. Done 2026-10-22 (28 rows).
- [ ] Ask Stewart for one recorded FTL run (observation method A); sample it; fill the OBSERVE rows
      and O-06 to O-08 (pacing, crises, decisions per minute).
- [ ] Method B sessions only for rows A could not settle, with Stewart present.

## P3: build from the rows
- [x] Work in this session's own worktree and branch; merge into main only after M1d has triaged
      Stewart's build 6 runs (D058). Leave the files M1d is splitting alone until the split is on main.
- [x] Before each builder dispatch: `python tools/gemini_audit.py --question <q.md> --extra <the spec>`
      asking it to check every target band against the current data and code and every wrong value
      against its band (D057). Verify each finding yourself before changing a row.
- [x] `tools/ledger.py` (parser and coverage report) with its own test (`tools/test_ledger.py`).
- [x] Per system, one builder spec in `docs/plans/specs/m2p_<system>.md` that quotes only ledger
      rows; scenarios `game/data/scenarios/ledger_<system>.json`; tests `game/tests/test_ledger_<system>.gd`.
- [x] Data-only systems first (upgrade prices, rewards, store stock), then crew and stations, then
      new verbs (doors and venting, disruption, node hazards).
- [x] Each round: `python tools/check.py` says `check: ok`, determinism hash recorded, a balance run
      with the new measures.

## P4: differential checks
- [ ] `tools/parity.py` (local only) compares the picked rows against the private reference.
- [x] Balance report measures in band (`ftl-difftest-plan.md`, layer 4).
- [ ] Critic rubric run on the feel rows; Stewart's A/B per system (three questions, 1 to 5).
- [x] `docs/research/parity_report.md` committed with the coverage per system.

Status 2026-10-23: P3 done on the branch (rounds 1 to 6a, playtest build `m2p-parity-1`); P4 left:
`tools/parity.py`, the critic rubric on the feel row and Stewart's A/B. Rounds 4 and 5 were checked by
hand while the Gemini audit was out of credits.

## P5: make it ours
- [ ] Deliberate divergences logged as "waived by design" rows with D-numbers.
