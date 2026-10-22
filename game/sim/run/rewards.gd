class_name Rewards
extends RefCounted
## Tiered ore and gem rewards (parity L-RWD-01 to L-RWD-04, docs/plans/specs/m2p_economy.md). A
## reward is a tier ("low", "medium", "high") applied to the row's base: base = <res>_row1 +
## <res>_per_row x (row - 1), row clamped to at least 1; the amount is roundi(base x m), m uniform in
## the tier's [min, max]. Only ore and gems scale; supplies never do. The row is the ship's map row
## (RunState.current_row, 0 to 13 on the crust), never the squeezed event-content row.
## Each roll draws exactly one value from the "reward" stream. Static: the Sim is passed in.
## Tuning: game/data/tuning/economy.json (every key below; the store keys are read by StoreRoll and
## EncounterStore, listed here so the lint checks them in one place).

const TIERS: Array[String] = ["low", "medium", "high"]
const RESOURCES: Array[String] = ["ore", "gems"]
const STREAM: String = "reward"
const TUNING_KEYS: Array[String] = [
	"economy.reward_ore_row1", "economy.reward_ore_per_row", "economy.reward_gems_row1",
	"economy.reward_gems_per_row", "economy.tier_low_min", "economy.tier_low_max",
	"economy.tier_medium_min", "economy.tier_medium_max", "economy.tier_high_min",
	"economy.tier_high_max", "economy.gem_ore_value", "economy.sell_back_frac",
	"economy.store_rarity_weight_1", "economy.store_rarity_weight_2", "economy.store_rarity_weight_3",
	"economy.store_rarity_weight_4", "economy.store_rarity_weight_5",
	"economy.store_rarity_depth_gain_1", "economy.store_rarity_depth_gain_2",
	"economy.store_rarity_depth_gain_3", "economy.store_rarity_depth_gain_4",
	"economy.store_rarity_depth_gain_5",
]


## The row's base amount of `res` ("ore" or "gems") before the tier spread.
static func base(db: DataDB, res: String, row: int) -> float:
	var r: int = maxi(1, row)
	return db.tune("economy.reward_%s_row1" % res) + db.tune("economy.reward_%s_per_row" % res) * float(r - 1)


## The tier's multiplier range as (min, max).
static func spread(db: DataDB, tier: String) -> Vector2:
	return Vector2(db.tune("economy.tier_%s_min" % tier), db.tune("economy.tier_%s_max" % tier))


## A multiplier for `tier` from one draw `u` in [0, 1).
static func multiplier(db: DataDB, tier: String, u: float) -> float:
	var sp: Vector2 = spread(db, tier)
	return sp.x + (sp.y - sp.x) * u


## One draw from the "reward" stream (the caller turns it into a multiplier).
static func draw(sim: Sim) -> float:
	return sim.rng.get_stream(STREAM).randf()


## The amount of a tiered reward of `res` at `row` (one draw). The caller pays it through run.add.
static func roll(sim: Sim, res: String, tier: String, row: int) -> int:
	var m: float = multiplier(sim.db, tier, draw(sim))
	return roundi(base(sim.db, res, row) * m)


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	for key: String in TUNING_KEYS:
		if not db.tuning.has(key):
			errs.append("%s/tuning: missing number \"%s\"" % [db.root, key])
	for tier: String in TIERS:
		if db.tuning.has("economy.tier_%s_min" % tier) and db.tuning.has("economy.tier_%s_max" % tier):
			var sp: Vector2 = spread(db, tier)
			if sp.x <= 0.0 or sp.y < sp.x:
				errs.append("%s/tuning: economy.tier_%s_min must be above zero and at most tier_%s_max" % [db.root, tier, tier])
	if db.tuning.has("economy.sell_back_frac"):
		var f: float = db.tune("economy.sell_back_frac")
		if f < 0.0 or f > 1.0:
			errs.append("%s/tuning: economy.sell_back_frac must be 0 to 1" % db.root)
