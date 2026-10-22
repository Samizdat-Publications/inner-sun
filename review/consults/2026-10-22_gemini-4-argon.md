# Consult: Gemini 4 Argon on the whole repo (2026-10-22)

Stewart asked for one exploratory run of Google's new `gemini-4-argon` (listed by the API with a
1,048,576-token input window): give it the project's current state and ask where it could add
value. Decision: D057.

- **Input:** 161 committed files at commit `a4a804e` (core docs, plans, the FTL research docs, three
  balance reports, the newest critique, all of `game/sim`, `game/bots`, `game/data`, `game/meta`) plus
  three progress stills: 297,937 tokens. Nothing from `research_private/`, no keys.
- **Output:** 12,724 tokens. Cost about 0.75 to 1.50 USD (price for this model not published to us;
  estimated at Gemini Pro rates, `docs/SPEND.md`).
- **Ask:** Part A, where it adds value and where it does not; Part B, prove its number-checking with
  a spot audit (file, quote, calculation, confidence).
- Script: `tools/gemini_audit.py` (repeatable version of the one-off run).

## Verified by the lead (Claude), finding by finding

| # | Claim | Verdict | Notes |
|---|---|---|---|
| 1 | Ledger L-FIRE-01's band is far from today's numbers; one clause's wrong value would not fail it | **True** | One crew puts out a full fire in about 11 s, unfought spread across an open door takes about 33 s: ratio about 0.33 against a 0.7 to 1.5 band. The second clause needs its own wrong value. Ledger row updated. |
| 2a | A closed door already passes fire at the wall rate, and every pair of neighbouring rooms also has a wall path running in parallel | **True** | `hazard_sim.gd` (closed link uses `fire.spread_wall_factor`; `_find_walls` adds a wall pair for door-joined rooms too). A reinforced door cannot be slower than a wall without a code change. Ledger row L-DOR-01 updated. |
| 2b | L-DOR-02: at row 7 the rock is barely hotter than crew-harm heat; above about row 4 it never gets there | **True** | Rock at row 7 is about 54 C against 48 C. Its own text then says 14.7 to 29.4 kW/K where its calculation gives 1.47 to 2.93 (a 10x slip). Ledger row updated. |
| 3 | The rival AI and power restore pull in opposite priority orders | **Plausible, overstated** | Restore follows system priority (coolant first, weapons last) while the rival plan puts weapons first; the AI resets power four times a second, so the effect is a short mismatch, not a loop. Worth a test. |
| 4 | The greedy bot buys a weapon its weapons system cannot power | **True (heading wrong)** | `_can_power_weapon` adds one bar for an upgrade unconditionally (`sys_max + 1 >= need`). The finding's heading about bracing is wrong; it corrects itself mid-text. |
| 5 | Balance reports show hull 40 at row 0 for a 30-hull ship | **Anomaly true, cause unproven** | `balance_m1c_miner.md` row 0 shows 40 [35-40] while every other resource sits at its start value. Its explanation guesses at a file it never saw. |
| 6 | `docs/SPEND.md` miscounts the art-pass rows (64, not 66) | **False** | 66 art-pass rows, summing to exactly 9.24 USD, as the file says. Stated with high confidence. |
| 7, 8 | Two event options are never picked by any bot (`cold_spring` option 0, `byrd_signal` option 0) | **Plausible** | The bot scoring makes them dominated; dead content for bots, not necessarily for players. Arithmetic shown with a visible self-correction. |
| 9 | The state hash leaves out the ship's maximum hull and its weapon list | **True for `ShipWorld.state()`** | A divergence there would surface only indirectly. The second half (a mid-segment fight returns to "idle") was already a known gap. |
| 10 | Scenarios use the old rock heat slope (0.08 C per m) while runs use the layer's 0.033 | **True** | `drill.json` against `crust.json`; minor. |
| 11 | The blast planner values rock at full yield, ignoring the 50% blast yield (D039) | **True** | `blast_planner.gd` never reads `drill.blast_yield_pct`; the bots overvalue blasts about twice. |

**Score:** 8 of 11 true in whole or in part, 2 overstated or unproven, 1 false. Several are real
bugs the build sessions missed. The false one and the unit slip mean every finding must be checked
before anyone acts on it.

## Gemini's reply (verbatim; em dashes replaced by spaced hyphens per the house style)

## Part A: Where Gemini 4 Argon Adds Value (and Where It Does Not)

### Ranked Value Opportunities for Stewart

**1. Pre-Dispatch Behavior Ledger & Spec Math Auditor (M2 Parity Step P2 to P3)**
* **Why it matters:** In the M2 FTL parity workstream, the Lead (Opus) translates FTL observations into `docs/research/behavior-ledger.md` targets, and subagents build isolated tests and tuning data in worktrees. As Part B below proves, several current ledger rows (`L-FIRE-01`, `L-DOR-02`) have target bands that are mathematically impossible under the current `hazards.json` and `HazardSim` differential equations, or have "Wrong value" checks that will not actually fail the test. Catching this *before* dispatching an Opus builder saves 350k+ tokens and hours of wasted worktree iteration.
* **Workflow step:** Run once at the end of Step P2 (after the Lead writes the ledger rows and `docs/plans/specs/m2p_<system>.md`), before dispatching `builder` or `builder-opus`.
* **Input needed:** `docs/research/behavior-ledger.md`, `docs/plans/specs/m2p_*.md`, `game/data/tuning/*.json`, `game/data/ships/*.json`, and the relevant `game/sim/**/*.gd` files.
* **Output produced:** A `harness/out/ledger_math_audit.md` report verifying: (a) closed-form physics/math solutions for every `Target` band against current tuning, (b) verification that every `Wrong value` mutation mathematically crosses the boundary of the `Target` band to guarantee test failure, and (c) exact parameter bounds needed in `game/data/tuning/` to make the targets achievable.

**2. Whole-Repo Cross-Layer Invariant & State-Transition Auditor (Pre-Playtest Gate)**
* **Why it matters:** Subagents work in isolated worktrees on disjoint file sets (`isolation: worktree`). This prevents merge conflicts, but creates cross-module blind spots where Module A's assumptions about Module B's state or data schema drift out of sync (for example, `EnemyAI` vs `Systems` power restoration, or `PolicyChoices` vs `EncounterStore` upgrade limits, both found in Part B). Furthermore, `DataDB.lint()` checks structural types and IDs, but does not check semantic math invariants across tables.
* **Workflow step:** End-of-milestone gate (right before `qa-auditor` and `python tools/export.py --playtest`).
* **Input needed:** All of `game/sim/**/*.gd`, `game/bots/**/*.gd`, `game/meta/*.gd`, `game/data/**/*.json`, and `docs/DECISIONS.md` in a single long-context prompt.
* **Output produced:** A ranked defect list of cross-module logic bugs, state-hash omissions, conservation leaks, bot-vs-sim rule mismatches, and decisions in `DECISIONS.md` whose math or code no longer matches the text.

**3. Balance Report & Bot-Diagnostic Anomaly Detector**
* **Why it matters:** `python tools/balance.py --full` produces dense markdown tables (`docs/research/m1-evidence/balance_*.md`). Currently, the Lead reads headline win rates and death causes, but misses subtle statistical anomalies in the tables that prove a bot or sim feature is misfiring (such as the `cautious` and `balanced` bots starting at Row 0 with 40 Hull on a 30-Hull ship in the M1c reports, or `cautious` buying single bars of bracing that do nothing, both detailed in Part B).
* **Workflow step:** Immediately after running `python tools/balance.py --full`.
* **Input needed:** The generated `full_report.md`, `game/bots/*.gd`, and `game/data/**/*.json`.
* **Output produced:** A diagnostic brief separating *genuine game balance issues* from *bot AI bugs / harness leaks*, plus calculated sensitivity derivatives (e.g., how much `rows_per_s` or `loot_ore` needs to shift to move win rates into the 15% to 30% band).

**4. Automated Observation-CSV to Ledger-Target Fitter (M2 Parity Step P2)**
* **Why it matters:** In `docs/research/ftl-observation-plan.md`, the Lead plans to extract frame-by-frame CSVs from Stewart's FTL recordings (`O-01` through `O-11`) and convert them into normalized curves and scaled Inner Sun target bands (`tools/parity.py`).
* **Workflow step:** Step P2, after ffmpeg frame sampling produces the observation CSVs in `research_private/ftl_obs/`.
* **Input needed:** The raw observation CSVs and Inner Sun's `game/sim/` equations.
* **Output produced:** Exact curve fits, quantile tables (p10, p50, p90), and dimensional-analysis scaling factors translating FTL tile/second rates into Inner Sun meter/joule/millilitre tuning parameters.

### Where I Would NOT Add Value (Keep Claude Opus 5.5 Here)
* **Architecture, GDScript implementation, and tool orchestration:** Claude Opus 5.5 with its worktree subagent delegation (`builder`, `builder-opus`) and Windows job-object harness (`tools/*.py`) is already operating at a very high level, with 368 passing tests and strict determinism. Adding another model into code generation would only introduce style drift and tool friction.
* **Prose, lore, and tone (`writer`):** The dossier events, codex entries, and TOPSIDE radio lines in `game/data/` have a cohesive, dry conspiracy voice (`docs/STYLE_GUIDE.md`). Keep Opus on all writing.
* **Game feel, taste, and UI layout:** Claude is managing the iterative visual passes (`D045`, `D049`, `D050`) and triaging feedback effectively.
* **Blind video critique (`tools/critic_gemini.py`):** Gemini 3.1 Pro is already wired in for cheap ($0.15) blind video critiques. (Note: you should fix the double-sRGB gamma bug in `capture.py` noted in `HANDOFF.md` so the video critic stops judging washed-out footage, rather than changing the critic model.)

---

## Part B: Spot Audit of Numbers, Code, and Data

### 1. Ledger `L-FIRE-01` target band is mathematically impossible under current fire & crew tuning (and its "Wrong value" check will not fail)
* **Files & quotes:**
  * `docs/research/behavior-ledger.md` (`L-FIRE-01`): `"Target: time for one base-skill crew to put out a full fire in a 4 x 3 m room, divided by the time fire takes to cross an open door: 0.7 to 1.5; two crew take 0.4 to 0.6 of one crew's time."` and `"Wrong value: crew firefighting rate x3 must fail."`
  * `game/data/tuning/hazards.json`: `"fire": { "growth_per_s": 0.05, "spread_per_s": 0.03 }`, `"crew": { "fight_per_s": 0.11 }`
  * `game/sim/hazards/hazard_sim.gd`: `r.fire = minf(1.0, r.fire + _k("fire.growth_per_s") * dt * (1.0 - r.fire))` and `_spread_acc[j] += _k("fire.spread_per_s") * src.fire * factor * dt`
  * `game/sim/crew/crew_ai.gd`: `r.fire = maxf(0.0, r.fire - _k("crew.fight_per_s") * c.skill_fire * dt)`
* **What is wrong:**
  1. In Inner Sun, firefighting and fire spread are room-level (independent of room dimensions like `4 x 3 m`), and while a crew member fights a fire at `0.11/s`, the fire *simultaneously grows* at `0.05 * (1 - F)/s` at 10 Hz (`dt = 0.6 s`).
  2. Consequently, 1 crew member takes ~11.15 s to extinguish a full fire (`F = 1.0`), during which a neighboring room across an open door (`factor = 1.0`) only accumulates `0.193` spread exposure (well below the `1.0` threshold). Because the source fire is being lowered, it *never* crosses the open door while being fought, or if measured against an unfought fire's spread time (`1 / 0.03 = 33.33 s`), the ratio is `0.335`, which isless than half the target minimum of `0.7`.
  3. Because 1 crew is partially offset by `growth_per_s`, 2 crew (`0.22/s`) extinguish the fire in **less than half** the time of 1 crew (`0.464x`), which means multiplying `fight_per_s` by 3 (`Wrong value`) keeps the 2-crew/1-crew ratio at `0.489x` (still inside the `0.4 to 0.6` pass band!).
* **Calculation:**
  * Continuous ODE for `n` base-skill (`1.0`) crew fighting from `F(0) = 1.0` to `0`:
    $$\frac{dF}{dt} = 0.05(1 - F) - 0.11n \implies t_{\text{ext}}(n) = \frac{1}{0.05} \ln\left(\frac{0.11n}{0.11n - 0.05}\right)$$
  * For $n = 1$: $t_{\text{ext}}(1) = 20 \ln(0.11 / 0.06) = 12.123\text{ s}$ (exact discrete 60 Hz / 10 Hz sim: **11.15 s**).
  * For $n = 2$: $t_{\text{ext}}(2) = 20 \ln(0.22 / 0.17) = 5.157\text{ s}$ (exact discrete sim: **5.18 s**).
  * Unfought open-door spread time at $F = 1.0$: $t_{\text{spread}} = \frac{1.0}{0.03\text{ s}^{-1}} = 33.33\text{ s}$ (discrete: **33.6 s**).
  * Ratio $t_{\text{ext}}(1) / t_{\text{spread}} = 11.15 / 33.6 = \mathbf{0.332} \notin [0.7, 1.5]$.
  * Even if you triples `fight_per_s` to `0.33` (the stated `Wrong value`), the 2-crew to 1-crew time ratio is $\ln(0.66/0.61) / \ln(0.33/0.28) = 0.0788 / 0.1643 = \mathbf{0.480} \in [0.4, 0.6]$, so the wrong-value check for the second clause would **pass instead of failing**.
* **Confidence:** High.

---

### 2. Ledger `L-DOR-01` and `L-DOR-02` contradict existing code and tuning parameters
* **Files & quotes:**
  * `docs/research/behavior-ledger.md` (`L-DOR-01`): `"Target: a closed door passes fire at 30 to 50% of the open-door rate (between open and Inner Sun's wall rate, fire.spread_wall_factor) ... Today: the sim honours closed links for water, heat and fire, but nothing lets the player close one."`
  * `docs/research/behavior-ledger.md` (`L-DOR-02`): `"Target: ... at row 7 rock temperature the purged room reaches crew-harm heat (crew.heat_safe_c) in 10 to 20 s."`
  * `game/sim/hazards/hazard_sim.gd`: `if li >= 0 and not ship.links[li].open: factor = _k("fire.spread_wall_factor")`
  * `game/data/layers/crust.json`: `"row_depth_m": 60.0`, `"rock_temp_base_c": 40.0`, `"rock_temp_c_per_m": 0.033`
  * `game/data/tuning/hazards.json`: `"crew": { "heat_safe_c": 48.0 }`, `"heat": { "capacity_kj_per_m3_k": 0.5, "hull_kw_per_m2_k": 0.012, "breach_hull_factor": 400.0 }`
* **What is wrong:**
  1. In `L-DOR-01`, `HazardSim._fire()` currently sets a closed link's fire spread factor *equal* to `fire.spread_wall_factor` (`0.15`, or 15% of an open door), not between open and wall. There is no separate `spread_closed_door_factor` in code or tuning, and a closed door between two rooms also shares a `WallPair` in `ship.walls`! Because `HazardSim._init` adds *both* the `Link` adjacency and the `WallPair` adjacency into `_adj_from`/`_adj_to`, two rooms on the same deck have **two independent spread accumulators** running in parallel (`_spread_acc`), though since the faster one triggers first, only the link's accumulator matters unless reinforced doors are made slower than walls (in which case the wall accumulator at `0.15` will bypass the reinforced door!).
  2. In `L-DOR-02`, the ledger assumes that at Row 7, rock temperature is hot enough to heat a purged room to `crew.heat_safe_c` (`48.0 C`) in 10 to 20 seconds. In `crust.json` (retuned in D029), the rock temperature at Row 7 (`depth_m = 420 m`) is **53.86 C** (`40.0 + 0.033 * 420`). To heat a standard `4 x 3 x 3 m` room (`heat_cap = 18 kJ/K`) from `24 C` to `48 C` (`80.4%` of the way to the `53.86 C` asymptote) in 10 to 20 seconds requires an effective thermal conductance of **14.7 to 29.4 kW/K** (equivalent to a `3.0 to 6.1 m²` hull breach). If tested at any row above Row 3 (`depth < 242.4 m`), `rock_temp_c` is **below 48.0 C**, so a room purged to the rock can *never* reach `heat_safe_c` in infinite time.
* **Calculation:**
  * Row 7 depth: $7 \times 60\text{ m} = 420\text{ m}$.
  * Row 7 rock temp: $T_{\text{rock}} = 40.0 + 0.033 \times 420 = \mathbf{53.86^\circ\text{C}}$.
  * Threshold depth where $T_{\text{rock}} = 48.0^\circ\text{C}$: $(48.0 - 40.0) / 0.033 = \mathbf{242.42\text{ m}}$ (Row 4.04).
  * For a room starting at $T_0 = 24^\circ\text{C}$ to reach $48^\circ\text{C}$ when $T_{\text{rock}} = 53.86^\circ\text{C}$:
    $$\frac{T(t) - T_0}{T_{\text{rock}} - T_0} = \frac{24}{29.86} = 0.80375 = 1 - e^{-t/\tau} \implies \tau = \frac{t}{-\ln(1 - 0.80375)} = \frac{t}{1.6284}$$
    For $t \in [10, 20]\text{ s}$, $\tau = C / G \in [6.14, 12.28]\text{ s}$. With $C = 36\text{ m}^3 \times 0.5\text{ kJ/(m}^3\cdot\text{K)} = 18\text{ kJ/K}$, the required conductance is $G \in [\mathbf{1.47, 2.93}]\text{ kW/K}$.
* **Confidence:** High.

---

### 3. `EnemyAI` vs `Systems._restore()` fighting loop when an enemy system is damaged (D018 unintended side effect)
* **Files & quotes:**
  * `game/sim/systems/systems.gd`:
    * `set_power()`: `r.sys_power = mini(want, left)` / `r.sys_want = r.sys_power`
    * `_reconcile()`: `"Broken bars give their power back... Nothing is restored automatically."` (stale comment) -> calls `_restore(sim, world, sd, total, out)`, which restores `r.sys_power` toward `r.sys_want` in reverse `cut_order` (highest `priority` first) every 6 ticks (`10 Hz`).
  * `game/sim/combat/enemy_ai.gd`:
    * `_power()`: runs every 15 ticks (`4 Hz`), computes `_want[ri]` from `ai.power` list order against `intact_bars()`, then calls `sy.set_power(sim, enemy, ri, _want[ri])` only for rooms where `_want[ri] != rooms[ri].sys_power`.
  * `game/data/ships/rival_heavy.json` & `rival_raider.json`:
    * `rival_heavy` `ai.power` sum: `3 (weapons) + 4 (bracing) + 2 (bridge/helm) + 2 (coolant) = 11 bars`, while `reactor` has `10 bars` (`coolant` starts at `power: 1`, `bars: 2`, `sys_want = 1`).
* **What is wrong:**
  1. When an enemy ship spawns (`Ship.from_def`), `r.sys_want` is initialized to the room's starting `power`.
  2. When a high-plan-order enemy room (like `weapons`, which is #1 in `ai.power`, but has **lowest** system priority `1` in `game/data/systems/weapons.json`) takes 1 bar of hit damage (`damage_room`), `damage_room` immediately calls `_reconcile()` -> `_restore()`.
  3. Because `weapons` lost 1 bar of `sys_power`, 1 reactor bar is now free, and `weapons.sys_want` is still its old undamaged value (`3`), while `weapons.intact_bars()` is now `2`. If any other room on the enemy ship had `sys_want > sys_power`, `_restore` gives it the bar.
  4. Worse: when `EnemyAI._power()` runs on tick `15n`, it lowers the damaged room or raises lower-priority plan rooms (e.g. raising `coolant` from 1 to 2 on `rival_heavy`), which overwrites `coolant.sys_want = 2` while `weapons.sys_want` was overwritten to `2`!
  5. Then, when the enemy crew repairs `weapons` back to `3 intact_bars` (`CrewAI._work`), `weapons.sys_want` is stuck at `2` (because `EnemyAI` called `set_power(..., 2)` while it was damaged), and `coolant` holds the 10th reactor bar (`coolant` has priority `5`, the highest in the game!). Until the next `EnemyAI.think` tick (up to 14 ticks / 0.23 s later), `_restore` will not restore power to `weapons`, and every time damage/repair happens between 4 Hz AI ticks and 10 Hz system ticks, `_restore` (which sorts by `systems/*.json` `priority`: coolant 5 > helm 4 > bracing 3 > drill 2 > weapons 1) allocates power in the **exact opposite order** of `EnemyAI` (which prioritizes weapons first and coolant last).
* **Calculation:**
  * System priorities in `game/data/systems/*.json`: `coolant: 5`, `helm: 4`, `bracing: 3`, `drill: 2`, `weapons: 1`.
  * `EnemyAI` plan order in `rival_heavy.json`: `weapons` (first, 3 bars), `bracing` (2), `bridge` (1), `bracing` (4), `coolant` (1), `bridge` (2), `coolant` (2).
  * Total desired bars in `rival_heavy` plan = $3 + 4 + 2 + 2 = 11 > 10$ (reactor output).
* **Confidence:** High.

---

### 4. `cautious` bot wastes 140 ore per store visit on single Bracing bars that give 0 layers (`PolicyChoices` vs `crust_trader.json`)
* **Files & quotes:**
  * `game/bots/policy_choices.gd`:
    ```gdscript
    static func _units_worth_buying(sim: Sim, d: Dictionary) -> int:
        if str(d.get("item", "")) != "upgrade" or str(d.get("system", "")) != "bracing":
            return 1
        var ri: int = sim.ship.room_with_system("bracing")
        if ri < 0:
            return 1
        var per: int = maxi(1, roundi(sim.db.tune("systems.bracing_bars_per_layer")))
        return per - sim.ship.rooms[ri].sys_max % per
    ```
  * `game/data/stores/crust_trader.json` (stock line 8):
    `{"item": "upgrade", "system": "bracing", "price": 140, "currency": "ore", "limit": 2, "max_bars": 4, "text": "Bracing struts. Two make another layer."}`
  * `game/bots/policy_bot.gd`: `cautious` sets `b.ore_reserve = 30`, `balanced` sets `b.ore_reserve = 15`.
  * `docs/research/m1-evidence/balance_m1c_miner.md`:
    * `cautious`: `crust_trader 8: 165` across 300 runs.
    * `balanced`: `crust_trader 8: 287` across 300 runs.
* **What is wrong:**
  1. Look at the comment in `PolicyChoices._units_worth_buying`: `"Bracing bars only help in whole layers: buy as many units as complete the next layer."` When `light_drill` starts with `bracing` at `sys_max = 2` and `bracing_bars_per_layer = 2`, `2 - (2 % 2) = 2` units (`280 ore`).
  2. However, why is `crust_trader 8` (the bracing upgrade line) bought an **odd** number of times (`165` and `287`), and why does `store_opened` log `qty`? Because in `balance_full.py` (or event counting), `bought` events count **commands** (`{"type": "buy", "item": 8, "qty": 2}` emits *one* `"bought"` event!).
  3. Wait: what happens if a player or event or anything ever puts `sys_max` at `2` and the bot has between `170` and `309` ore? `_units_worth_buying` returns `2`, which costs `280` ore (`310` with `ore_reserve = 30`), so the bot buys nothing. That part works for `bracing`.
  4. Now look at `_can_power_weapon` in `game/bots/policy_choices.gd` (lines 201 to 208):
     ```gdscript
     ## A bought weapon is only worth it if the weapons system can feed it beside the guns already
     ## mounted (counting a weapons upgrade still on sale this visit).
     static func _can_power_weapon(sim: Sim, d: Dictionary) -> bool:
         ...
         var wr: int = sim.ship.room_with_system("weapons")
         return wr >= 0 and sim.ship.rooms[wr].sys_max + 1 >= need
     ```
     The comment says `"counting a weapons upgrade still on sale this visit"`, but the code unconditionally adds `+ 1` to `sim.ship.rooms[wr].sys_max` **without checking whether the weapons upgrade is still on sale, whether `sys_max` is already at `max_bars`, or whether the bot has the 160 ore to buy it!**
  5. On `light_drill`, starting weapons are `borer_turret` (`power: 1`) + `charge_launcher` (`power: 1`) = `2`. The store weapon is `thermal_lance` (`power: 2`), so `need = 1 + 1 + 2 = 4`. Starting `weapons` room has `bars: 3` (`sys_max = 3`).
  6. Because `3 + 1 >= 4` is **always true**, `greedy` (whose `upgrades` list puts `"weapon"` *before* `"system:weapons"`) buys `thermal_lance` for **70 gems** (`crust_trader 5`: bought 140 to 165 times in 300 runs!) when it does **not** have 160 ore to upgrade `weapons` to 4 bars! And because `CombatSide.assign_power(3)` assigns power in slot order (`slot 0`: borer 1 bar, `slot 1`: charge launcher 1 bar, leaving **1 bar** for `slot 2`: thermal lance which needs **2 bars**), the 70-gem Thermal Lance sits **completely unpowered (`0` charge) in every rival fight** until `greedy` either runs out of charges or later finds 160 ore at another store!
* **Calculation:**
  * `light_drill` weapons: `slot 0` (`borer_turret`, `power = 1`), `slot 1` (`charge_launcher`, `power = 1`), `slot 2` (`thermal_lance`, `power = 2`). Total `need = 4`.
  * `light_drill` `weapons` room: `sys_max = 3`.
  * In `CombatSide.assign_power(3)`:
    * `i = 0`: `need = 1 <= 3` -> `powered[0] = 1`, `left = 2`.
    * `i = 1`: `need = 1 <= 2` -> `powered[1] = 1`, `left = 1`.
    * `i = 2`: `need = 2 <= 1` (False) -> `powered[2] = 0`.
  * In `balance_m1c_miner.md` (`greedy`, 2 rows): `crust_trader 5` (`thermal_lance`) is bought **165 times**, while `crust_trader 10` (`weapons` upgrade) is bought 284 times (only after `diamond_head` at 450 ore and `tungsten_head` at 180 ore). Whenever `greedy` has 70 gems but < 160 ore at a store, it spends 70 gems on a gun it cannot power.
* **Confidence:** High.

---

### 5. Balance Report Contamination: `balance.py` leaked owned Requisitions (`field_plating` / `tungsten_start`) into the M1c 900-run balance reports
* **Files & quotes:**
  * `docs/research/m1-evidence/balance_m1c_miner.md` & `balance_m1c_structures.md` ("Resources on arrival per row (median [p10-p90])"):
    * `cautious` Row 0: `hull: 40 [35-40]`
    * `balanced` Row 0: `hull: 40 [35-40]`
    * `greedy` Row 0 (in `balance_m1c_miner.md` first table): `hull: 30 [30-35]`; (in second table): `hull: 35 [30-35]`
  * `game/data/ships/light_drill.json`: `"hull": 30`, `"start_resources": {"ore": 10, "gems": 15, "coolant": 14, "cells": 12, "bits": 2, "charges": 4}`
  * `docs/DECISIONS.md` (`D025` & `D040`): `hull_plating` (`+5 max_hull, +5 hull`, bought in stores) and `field_plating` (`+5 max_hull`, requisition).
* **What is wrong:**
  * At Row 0 (`t = 0 s`, before any segment is drilled or any store is visited), `light_drill` has a deterministic starting hull of **30** (as seen in `balance_full_report_1000_runs.md`, where Row 0 hull is `30 [30-30]` for all three bots).
  * Why do `cautious` and `balanced` have a median Hull of **40** (`[35-40]`) and `greedy` have **30 to 35** (`[30-35]`) at **Row 0, t = 0 s** in both `balance_m1c_structures.md` and `balance_m1c_miner.md`?
  * Wait: in `RunState`, there is no store at Row 0 (`types[0][0] = "start"`). How can Hull at Row 0 arrival be 35 or 40?
  * Let's check how "Resources on arrival per row" is recorded! When the ship arrives at a store in Row $r$ (or buys `hull_plating` which adds `+5` to `sim.ship.hull_max` and `+5` to `hull`), `light_drill` max hull only reaches 40 after buying **two** `hull_plating` gear items (`max_owned: 2`, `30 + 2 * 5 = 40`).
  * Why is Row 0 reporting `40 [35-40]`? Because Row 0 in that table is **not** being recorded at `t = 0` - or rather, `t s` says `0`, `ore` says `10 [10-10]`, `gems` says `15 [15-15]`, `coolant` says `14 [14-14]`, `cells` says `12 [12-12]`, `bits` says `2 [2-2]`, `charges` says `4 [4-4]`, yet `hull` says `40 [35-40]`!
  * All six other resources at Row 0 are the exact starting values (`10, 15, 14, 12, 2, 4`), which proves no requisitions (`spare_bits`, `coolant_tank`, `charge_crate`) were active at `t = 0`, yet Row 0 `hull` is `40 [35-40]` for `cautious`/`balanced` and `35 [30-35]` for `greedy`!
  * Why? Because `balance_full.py` (which is not in the file dump, but whose output is in `balance_m1c_miner.md`) records Row 0's `hull` from the **end-of-run `hull_max`** (`sim.ship.hull_max`, which ends at 40 after the bot buys two `hull_plating` items during the run!) instead of `30` (`sim.ship.source_def["hull"]`)!
* **Calculation:**
  * `light_drill.json` starting `hull` = `30`.
  * `hull_plating.json`: `"max_owned": 2`, `"effects": {"max_hull_add": 5, "hull_add": 5}`.
  * `cautious` buys `crust_trader 15` (`hull_plating`) `487` times in `300` runs (`1.62` per run -> median 2 plates -> `30 + 2 * 5 = 40` final `hull_max`).
  * `balanced` buys `crust_trader 15` `495` times in `300` runs (`1.65` per run -> median 2 plates -> `40` final `hull_max`).
  * `greedy` (first run) buys `crust_trader 15` `158` times in `300` runs (`0.53` per run -> median 0 plates -> `30` final `hull_max`); (second run) `198` times in `300` runs (`0.66` per run -> median 1 plate -> `35` final `hull_max`).
  * This proves `balance_full.py` is initializing Row 0's hull column using the post-run mutated `ship.hull_max` instead of the initial hull at `t = 0`.
* **Confidence:** High.

---

### 6. `SPEND.md` arithmetic and row-count errors in the audited reconciliation
* **Files & quotes:**
  * `docs/SPEND.md`:
    * `"2026-10-16 | Gemini gemini-3-pro-image | reconciliation (qa-auditor): the logged art-pass rows total 9.24 USD (66 images)..."`
    * `"Session total (2026-10-15 to 16, M1a): about 15 USD (logged 11.96 plus the 3.00 reconciliation), under the 40 USD soft cap."`
* **What is wrong:**
  1. Counting the `artpass` rows in `docs/SPEND.md`, there are **64** `artpass` rows (at `$0.14` each = **$8.96**), not 66 rows (`$9.24`).
  2. Including the 12 `bakeoff painted` rows (`12 * $0.14 = $1.68`), there are **76** total image rows (`76 * $0.14 = $10.64`).
  3. Adding the `$0.06` video critic smoke test and `$0.98` ElevenLabs audio pass gives a logged pre-reconciliation total of **$11.68**, not `$11.96` (a `$0.28` / 2-image counting error by `qa-auditor`).
  4. The 6 post-M1a Gemini video critic rows (`004` through `009`, totaling `$0.79`) are appended *below* the `"Session total"` line with no updated cumulative total.
* **Calculation:**
  * Bake-off images: $12 \times \$0.14 = \$1.68$.
  * Art-pass images logged in table: $64 \times \$0.14 = \$8.96$ (claimed: $66 \times \$0.14 = \$9.24$).
  * Other M1a spend: $\$0.06 + \$0.98 = \$1.04$.
  * Sum of logged rows before reconciliation: $\$1.68 + \$8.96 + \$1.04 = \mathbf{\$11.68}$ (claimed: $\$11.96$).
  * With $\$3.00$ reconciliation + $\$0.79$ M1b/M1c critics: $\$11.68 + \$3.00 + \$0.79 = \mathbf{\$15.47}$.
* **Confidence:** High.

---

### 7. Event `cold_spring.json` has a dead option (`intro/0`) that no bot will ever pick and is strictly dominated by `intro/3`
* **Files & quotes:**
  * `game/data/events/cold_spring.json`:
    * Option 0 (`"Pump the spring into the tanks."`): `codex: coolant_k7`, `coolant: 3..5`.
    * Option 1 (`"Filter it through the second coolant loop."`, requires `coolant: 2` bars): `codex: coolant_k7`, `coolant: 5..6`.
    * Option 2 (`"Pry open the sled's battery bay."`): `2/3` chance `cells: +1`; `1/3` chance `cells: +1, crew_damage: 15`.
    * Option 3 (`"Stay, pump it dry and strip the sled."`): `codex: coolant_k7`, `coolant: 6..8`, `cells: +1`, `pursuer: +0.7 rows`.
  * `docs/research/m1-evidence/balance_m1c_miner.md`, `balance_m1c_structures.md`, `balance_full_report_1000_runs.md`:
    * Across **2,202 total runs** (`360` occurrences of `cold_spring`), only `cold_spring/intro/1` (`260` times) and `cold_spring/intro/3` (`105` times) were ever chosen. Option 0 and Option 2 were chosen **0 times in 2,202 runs**.
* **What is wrong:**
  * Why was Option 0 never chosen in 2,202 runs, even when `coolant` was < 2 bars?
  * Let's check `PolicyChoices.effect_value()` in `game/bots/policy_choices.gd`:
    * In `PolicyBot.wanted_power()`, during `"idle"` (and when arriving at a node after `"drill"`), `coolant` is always allocated `2` or `3` bars (Priority #1 in `wanted_power` for both `drill` and `idle`!). Because `light_drill` starts with `coolant` at `2` bars, Option 1's requirement (`"requires": {"system": {"coolant": 2}}`) is satisfied in **100% of runs** unless the coolant room is currently damaged or overheated (> 90 C) on arrival!
    * Even if `coolant` is damaged (< 2 effective bars):
      * Option 0 scores: `codex (2.0) + 4.0 * 1.2 * gain_scale = 2.0 + 4.8 * gain_scale` (`6.8` for balanced/cautious, `10.64` for greedy).
      * Option 2 scores: `cells: 1 * 6.0 * gain_scale - (1/3) * 15 * 0.3 * loss_scale = 6.0 * gain_scale - 1.5 * loss_scale` (`4.5` for balanced, `3.0` for cautious, `9.9` for greedy) -> always loses to Option 0 or Option 3!
      * Option 3 scores: `codex (2.0) + (7.0 * 1.2 + 1.0 * 6.0) * gain_scale - 15.0 * 0.7 * loss_scale = 2.0 + 14.4 * gain_scale - 10.5 * loss_scale` (`5.9` for balanced, `-4.6` for cautious, `21.62` for greedy).
    * Thus, `greedy` **always** picks Option 3 (`21.62 > 13.88` for Option 1), and `cautious`/`balanced` **always** pick Option 1 (`8.6 > 6.8 > 5.9`) because `coolant` has 2 bars! Option 0 and Option 2 are completely dead content for all bots.
* **Calculation:**
  * Balanced (`gain_scale = 1.0, loss_scale = 1.0`):
    * Opt 0: $2.0 + 4 \times 1.2 = \mathbf{6.8}$
    * Opt 1: $2.0 + 5.5 \times 1.2 = \mathbf{8.6}$
    * Opt 2: $6.0 - \frac{1}{3}(4.5) - 0.25(1.5 - 4.5)$? Wait: `worst = 6.0 - 4.5 = 1.5`, `mean = 4.5`, `risk_down * (worst - mean) = 0.25 * (-3.0) = -0.75` -> $4.5 - 0.75 = \mathbf{3.75}$.
    * Opt 3: $2.0 + 7 \times 1.2 + 6.0 - 10.5 = \mathbf{5.9}$.
  * Greedy (`gain_scale = 1.8, loss_scale = 0.6`):
    * Opt 1: $2.0 + 5.5 \times 1.2 \times 1.8 = \mathbf{13.88}$
    * Opt 3: $2.0 + (8.4 + 6.0) \times 1.8 - 10.5 \times 0.6 = 2.0 + 25.92 - 6.3 = \mathbf{21.62}$.
* **Confidence:** High.

---

### 8. `byrd_signal.json` Option 0 (`"Answer on the same key."`) is strictly dominated in `PolicyChoices` and only fired once in 2,202 runs
* **Files & quotes:**
  * `game/data/events/byrd_signal.json`:
    * Option 0 (`"Answer on the same key."`): `codex: byrd_1947`, `reveal: +3 rows`, `pursuer: +0.5 rows`.
    * Option 1 (`"Triangulate the source with the scanner."`, requires `helm: 2` bars): `codex: byrd_1947`, `reveal: +2 rows`.
    * Option 2 (`"Switch the receiver off."`): no effects (`0.0`).
  * `game/bots/policy_choices.gd`:
    * `"codex": return 2.0`
    * `"reveal": return 1.5 * float(e.get("rows", 0))`
    * `"pursuer": return -15.0 * float(e.get("rows", 0.0)) * bot.loss_scale`
* **What is wrong:**
  * In `PolicyChoices.effect_value()`, `reveal: 3` is worth `3 * 1.5 = +4.5`, and `codex` is worth `+2.0` (total `+6.5`), whereas `pursuer: 0.5` is penalized at `-15.0 * 0.5 * loss_scale = -7.5 * loss_scale`.
  * Therefore, for **every** bot policy - even `greedy` (`loss_scale = 0.6` -> penalty `-4.5` vs `reveal` gain isn't multiplied by `gain_scale`!) - Option 0's net score is:
    * `cautious` (`loss_scale = 2.0`): `2.0 + 4.5 - 15.0 = -8.5` (loses to Option 2 `"Switch the receiver off"` at `0.0`!).
    * `balanced` (`loss_scale = 1.0`): `2.0 + 4.5 - 7.5 = -1.0` (loses to Option 2 at `0.0`!).
    * `greedy` (`loss_scale = 0.6`): `2.0 + 4.5 - 4.5 = +2.0` (loses to Option 1 at `2.0 + 3.0 = +5.0` whenever `helm` has 2 bars!).
  * That is why in `balance_m1c_miner.md`, across 900 runs (`254` occurrences of `byrd_signal`), Option 1 was picked `141` times, Option 2 ("do nothing") was picked `112` times, and Option 0 was picked **1 time** (only when `greedy` arrived with a damaged helm!).
* **Calculation:**
  * Score of Option 0: $2.0 + 1.5(3) - 15.0(0.5)\text{loss\_scale} = 6.5 - 7.5 \cdot \text{loss\_scale}$.
  * For `loss_scale >= 0.87`, Score(Option 0) < `0.0` = Score(Option 2).
* **Confidence:** High.

---

### 9. `CombatSim` mid-segment fight bug (`_return_phase`) and `Sim.state()` omission of `Sim._pending` and `Room.hull_area_m2` / `Ship.hull_max`
* **Files & quotes:**
  * `game/sim/combat/combat_sim.gd` (line 114): `_return_phase = "scenario" if sim.run.phase == "scenario" else "idle"`
  * `game/sim/ship/ship_world.gd` (`state()`):
    `rooms.append([r.energy_j, r.water_ml, r.fire, r.breach_m2, r.flooded_s, r.sys_max, r.sys_damage, r.sys_power, r.sys_want, r.sys_failed])`
  * `game/sim/run/gear.gd`: `sim.ship.hull_max += more_hull`
* **What is wrong:**
  1. `ship.hull_max` is mutated mid-run by `Gear.fit("hull_plating")` (`+5`) and at run start by `Requisitions.apply` (`field_plating`, `+5`), and `ship.weapons` is mutated by `EncounterStore.buy("weapon")` and `CombatLoot._weapon()`. Neither `ship.hull_max` nor `ship.weapons` is included in `ShipWorld.state()` or `RunState.state()`! (Outside of combat, `CombatSim.state()` holds the `player_side` from the *last* fight, so a weapon bought at a store or found in loot does not enter `state_hash()` until the next fight starts; and `ship.hull_max` only enters `state_hash()` indirectly if `hull` is healed to `hull_max`.)
  2. As noted in `PROGRESS.md`, `CombatSim.start_fight` hardcodes `_return_phase = "idle"` instead of `"drill" if sim.drill.active else "idle"` (unlike `Encounter._to_idle`). If any non-structure event or debug command ever triggers a fight while `sim.drill.active` is true, the run gets stuck in `"idle"` with `sim.drill.active == true`, blocking `begin_segment` (`if active or (phase != "idle"...) return false`) and permanently wedging the run.
* **Calculation:**
  * In `ShipWorld.state()`: `return [side, ship.id, rooms, crew, links, hazards.state()]`  -  neither `ship.hull_max` nor `ship.weapons` is in the array.
* **Confidence:** High.

---

### 10. `D026` / `D029` Rock Temperature Claim vs Actual Formula (`rock_temp_c` at the Gate)
* **Files & quotes:**
  * `docs/DECISIONS.md` (`D026`): `"Layer rock_temp_c_per_m 0.08 -> 0.04 so the rock at the gate is as hot as before (about 62 C)."`
  * `docs/DECISIONS.md` (`D029`): `"rows 10 -> 14 (gate at 780 m) ... Rock heat rock_temp_c_per_m 0.04 -> 0.033 (66 C at the 780 m gate; 0.04 would make it 71 C, the old gate was 62 C)."`
  * `game/sim/run/run_state.gd` (`arrive()`): `depth_m = float(layer.get("row_depth_m", 36.0)) * float(int(n["row"]))`
  * `game/sim/drill/drill_sim.gd`: `sim.run.depth_m = start_depth_m + (_py - start_y)`
* **What is wrong:**
  * A small precision note on `D029`: at the 780 m gate (`row 13`, `13 * 60 m = 780 m`), `40.0 + 0.033 * 780 = 65.74 C` (~66 C), which matches `D029`.
  * However, in `drill.json`, `"rock_temp_c_per_m"` was left at `0.08` (the old M1a value from `D020`), while `crust.json` has `0.033`. Because `DrillSim.step()` checks `if not sim.run.layer.is_empty():` and overrides `_rock_c_per_m` with `crust.json`'s `0.033`, any **scenario** (`mode == "scenario"`, where `sim.run.layer` is `{}`) uses `drill.json`'s `0.08 C/m` (more than **2.4x** hotter per meter than a real run in the Crust!).
* **Calculation:**
  * Scenario mode rock heat slope (`drill.json`): `0.08 C/m`.
  * Run mode Crust rock heat slope (`crust.json`): `0.033 C/m`.
  * Ratio: $0.08 / 0.033 = \mathbf{2.424\times}$.
* **Confidence:** High.

---

### 11. `BlastPlanner.loot_target()` vs `D039` (`blast_yield_pct = 50%`) Valuation Mismatch
* **Files & quotes:**
  * `docs/DECISIONS.md` (`D037` & `D038` & `D039`):
    * `D037`: `"loot circles worth 50 (balanced) or 40 (greedy) ore-equivalent"`
    * `D039`: `"Now a blast pays drill.blast_yield_pct (50) of each material's yield, rounded down per material per blast; the rest shatters."`
  * `game/bots/blast_planner.gd` (`loot_target`):
    ```gdscript
    if yr >= 0:
        value_of[m] = float(d.yield_amount_of[m]) * (value_ore if yr == ore_i else value_gem)
    ```
* **What is wrong:**
  * When `D039` halved the blast yield (`blast_yield_pct: 50`), `BlastPlanner.loot_target()` was **not** updated to multiply rock yields by `blast_yield_pct / 100.0` (or account for integer floor truncation when a single cell of `coal` (`amount: 1`) or `gem` (`amount: 1`) is blasted and rounds down to `1 * 50 / 100 = 0`!).
  * Specifically:
    1. `BlastPlanner` still scores rock cells at **100% of their uncut yield** (`value_of[m] = yield_amount_of[m] * value`), so a circle that `BlastPlanner` scores as worth `"50 ore-equivalent"` actually yields **at most 25 ore-equivalent** (and **0** for an isolated `coal` or `quartz` cell because `1 * 50 / 100 = 0` via integer division in `DrillSim.scale_pending`!).
    2. Meanwhile, `value_crate` (`12.0` per crate cell, or `48.0` for a 2x2 crate) is compared on the same scale, even though crates do *not* shatter (`100%` yield).
* **Calculation:**
  * In `DrillSim.scale_pending(pct)`: `_pend_amt[m] = _pend_amt[m] * pct / 100`.
  * If a blast hits 1 cell of `gem` (`amount = 1`, `value = 3.0`), `BlastPlanner` adds `+3.0` to the circle's value, but `_pend_amt[6] = 1 * 50 / 100 = 0` gems paid!
  * For larger clusters, `BlastPlanner` overvalues rock ore/gems by **2x** relative to `blast_min_value` (`50.0` for balanced, `40.0` for greedy) and relative to `value_crate`.
* **Confidence:** High.

---

## What I Could Not Check

From this commit snapshot, I could not audit the GDScript view layer (`game/view/**/*.gd`), the test suite (`game/tests/**/*.gd`), or the Python harness scripts (`tools/*.py`, including `tools/balance_full.py` and `tools/run_report.py`), because those files were not included in the prompt payload. In particular, I could not inspect the UI input-handling code in `game/view/` to diagnose why Stewart's `douse` (`F` / button) clicks did not register during his build 5c run, nor could I verify the private FTL unpacked files in `research_private/` (which are git-ignored by design).
