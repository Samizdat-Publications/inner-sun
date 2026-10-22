# Differential-test plan: is Inner Sun at rough parity, in numbers and in feel?

Written 2026-10-22 (FTL parity side track, D052 to D055). Companion files: `behavior-ledger.md` (the
rows being tested), `ftl-observation-plan.md` (where FTL-side readings come from).

Classic differential testing feeds the same inputs into the original and the rebuild and reports a
match rate. FTL cannot be driven by a script, has no headless mode and gives us no state dump, so we
adapt it: the FTL side is a fixed reference (documented values and observations, kept private), the
Inner Sun side is our deterministic sim, and "the same inputs" means the same situation rebuilt as an
Inner Sun scenario. The goal is rough parity of shape and feel, not equal numbers: Inner Sun's rooms,
units and pacing differ on purpose.

## Five layers, cheapest first

### 1. Ledger tests inside `python tools/check.py` (committed, every run)
- Every number, shape or rule row in `behavior-ledger.md` gets a headless test named after it:
  `game/tests/test_ledger_<system>.gd`, function `test_l_<system>_<nn>` (for example
  `test_l_fire_01`). Most build a small scenario in `game/data/scenarios/ledger_<system>.json` (a
  room, a fire, a crew member, a timeline of commands), step the sim, and assert the row's
  **Inner Sun target band**.
- These tests never read FTL material: the targets in the ledger are already Inner Sun's own
  numbers. So they run in worktrees, on a fresh clone and in the exported build's checks.
- **Prove each test can fail** (borrowed from the REA method): each row names a wrong value (a tuning
  key pushed out of range). The test file runs the scenario once more with that override and
  asserts the check now fails. A test that cannot fail is not evidence.
- Determinism and conservation rules apply as everywhere: the scenario's hash is stable and water and
  heat totals still balance.

### 2. A coverage score (`python tools/ledger.py`, to build)
- Parses `behavior-ledger.md` (the row format is strict for this reason) and the test results, and
  prints per system and overall: rows in scope, rows passing, rows failing, rows waived by design
  (with their D-number), rows still open.
- **Parity of a system** = passing number, shape and rule rows / those rows in scope. A system is at
  rough parity at 80% or more with no failing row marked "core".
- The report is committed as `docs/research/parity_report.md` after each workstream step (Inner Sun
  values and pass or fail only).

### 3. Shape comparison against the FTL reference (local only, `python tools/parity.py`, to build)
- Runs only where `research_private/` exists (the lead's checkout), never in `check.py`.
- For rows whose target came from an FTL curve (fire growth over time, repair progress, income per
  layer), it runs the Inner Sun scenario, extracts the same measure, puts both on a common scale
  (each system's scale factor is a private note, because a committed factor plus our value would
  give away the FTL number) and reports the gap:
  - a single value: ratio error, pass within the row's tolerance;
  - a curve: both normalised to their own duration and peak, then the largest gap and the mean gap
    between them;
  - a distribution (balance metrics): quantiles side by side (10th, 50th, 90th).
- Output: `research_private/parity_local.md`. Only pass or fail per row ever leaves that folder.
- Its main use is to set and re-check the Inner Sun target bands; day to day, layer 1 guards them.

### 4. Run-level parity with the balance bots (`python tools/balance.py`)
New measures added to the balance report (bots play Inner Sun only; the FTL side comes from the
wikis, the game's data and Stewart's recorded runs):
- fights per layer and their spacing; share of nodes that are fights, events, stores, empty;
- income per row (ore and gems) and how it splits between fights, events and the dig;
- what the money is spent on (upgrades, consumables, repairs, gear) by row;
- crises per minute (fires, breaches, systems down) and time to the first one;
- pursuer pressure: share of runs where the pursuer is within one row at the gate, and how often
  it forces a fight;
- death causes and the row of death.
Each has a target band in the ledger (shape rows such as "upgrades take about half of all
spending by mid-run").

### 5. Feel
- **Human pacing, both games (O-06 to O-08):** fight length, time between crises and decisions per
  minute, read from Stewart's FTL recordings and from his Inner Sun run records (the input diary in
  each record, `python tools/run_report.py`). Compared as ranges, by the lead.
- **Critic rubric:** "feel" rows are written as things a viewer can see ("within two seconds of a
  fire starting the room reads as burning at a glance"; "an unpowered system is obvious without
  hovering"). `python tools/critic_gemini.py` and the player-critic judge Inner Sun clips and stills
  against those rows. The critics never see FTL footage, so their verdicts stay on our game.
- **Stewart's A/B, the real test:** for each system he picked, ten minutes of FTL then ten minutes of
  Inner Sun around that system, and three fixed questions scored 1 to 5: as tense? as readable? as
  many real choices? His answers go to `docs/STEWART_FEEDBACK.md`. A system is done when his scores
  are 4 or more, or when he says the difference is one he wants.

## After parity: making it ours
Parity is the base, not the goal. Once a system passes, deliberate changes for the dig (deck-stacked
hazards, heat in place of air, noise and the pursuer) are made on purpose: the row is marked
"waived by design" with a D-number in `docs/DECISIONS.md`, so the coverage score shows what was
matched and what was changed knowingly.

## What gets built for this, when the workstream starts
| Piece | Size | Notes |
|---|---|---|
| `game/tests/test_ledger_*.gd` and `game/data/scenarios/ledger_*.json` | per row, small | Builders write them from the ledger rows alone |
| `tools/ledger.py` | small | Parser and coverage report; a unit test of its own on a sample ledger |
| `tools/parity.py` | small to medium | Local only; reads `research_private/`; prints pass or fail per row |
| Balance report measures | medium | In `tools/balance.py` and the bots' summaries |
| `tools/ftl_session.py` | small | Job-object launcher for FTLGame.exe plus the window recorder (observation method B) |
