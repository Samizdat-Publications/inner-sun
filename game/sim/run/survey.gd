class_name Survey
extends RefCounted
## Survey readings ("scanning planets"): every map node except the start carries n["survey"], a
## reading of the rock on the segment that leads to it (from the row above, row_depth_m of rock).
## Rolled once per run from the stream "survey", node by node in map order, four draws per node,
## so a seed always gives the same readings. The reading is not a guess: DrillSim generates that
## segment's rock FROM it (RockGen.options_of), so what the survey says is what the rock holds.
## The view shows it once the node is inside scanner range (RunState.is_revealed).
##
## A reading (keys in this order):
##   {"tier": 0.., "tier_name": "poor" | "fair" | ..., "richness": ore and gem count scale,
##    "ores": ore material ids the rock at that depth can hold (data order),
##    "gems": gem material ids it holds ([] when the survey found none),
##    "gas": gas pockets on the way, "water": water pockets on the way}
## Layer data, "survey": {"tiers": [{"name", "richness", "weight"}, ...] (poorest first),
##   "gems_chance", "gas_chance", "water_chance", and "deposit": the same chances plus "min_tier"
##   for "deposit" nodes (a known rich seam: a richer tier and more gas and water), and optional
##   "per_row": chances added for each row below the first segment (both kinds of node)}.


static func add_to_map(map: Array, layer: Dictionary, rock: Dictionary, rng: RandomNumberGenerator) -> void:
	var sd: Dictionary = layer.get("survey", {})
	var step_m: float = float(layer.get("row_depth_m", 36.0))
	for row: Variant in map:
		for nv: Variant in (row as Array):
			var n: Dictionary = nv
			var r: int = int(n["row"])
			if r == 0:
				n["survey"] = {}
				continue
			n["survey"] = roll(sd, rock, str(n["type"]) == "deposit", float(r - 1) * step_m, step_m, rng, r - 1)


## One reading for a segment from run depth d0 down by depth_m. `deeper` is the number of rows below
## the first segment: each adds the layer's survey.per_row chances (gas and water get likelier deeper
## down; a chance never goes above 1).
static func roll(sd: Dictionary, rock: Dictionary, deposit: bool, d0: float, depth_m: float,
		rng: RandomNumberGenerator, deeper: int = 0) -> Dictionary:
	var p: Dictionary = sd.get("deposit", {}) if deposit else sd
	var per_row: Dictionary = sd.get("per_row", {})
	var tiers: Array = sd.get("tiers", [])
	var min_tier: int = clampi(int(p.get("min_tier", 0)), 0, maxi(0, tiers.size() - 1))
	var total: float = 0.0
	for t: int in range(min_tier, tiers.size()):
		total += maxf(0.0, float((tiers[t] as Dictionary).get("weight", 0.0)))
	var u: float = rng.randf() * total
	var tier: int = min_tier
	for t: int in range(min_tier, tiers.size()):
		tier = t
		u -= maxf(0.0, float((tiers[t] as Dictionary).get("weight", 0.0)))
		if u < 0.0:
			break
	var d: float = float(maxi(0, deeper))
	var gems: bool = rng.randf() < float(p.get("gems_chance", 1.0)) + d * float(per_row.get("gems_chance", 0.0))
	var gas: bool = rng.randf() < float(p.get("gas_chance", 0.0)) + d * float(per_row.get("gas_chance", 0.0))
	var water: bool = rng.randf() < float(p.get("water_chance", 0.0)) + d * float(per_row.get("water_chance", 0.0))
	var td: Dictionary = tiers[tier] if not tiers.is_empty() else {}
	return {"tier": tier, "tier_name": str(td.get("name", "fair")), "richness": float(td.get("richness", 1.0)),
		"ores": possible(rock, "ore", d0, depth_m), "gems": possible(rock, "gems", d0, depth_m) if gems else [],
		"gas": gas, "water": water}


## Material ids of a feature group that can occur in a segment from run depth d0 down by depth_m,
## in data order, each once.
static func possible(rock: Dictionary, group: String, d0: float, depth_m: float) -> Array:
	var out: Array = []
	for f: Variant in rock.get("features", []):
		var fd: Dictionary = f
		if str(fd.get("group", "")) != group:
			continue
		var w: Vector2 = RockGen.window(fd, depth_m, d0)
		var m: String = str(fd.get("material", ""))
		if w.x <= w.y and not out.has(m):
			out.append(m)
	return out


## Checks the layer's "survey" block; adds errors for `file`.
static func lint(sd: Variant, file: String, errs: PackedStringArray) -> void:
	if not (sd is Dictionary):
		errs.append("%s: survey must be an object" % file)
		return
	var d: Dictionary = sd
	var tiers: Variant = d.get("tiers")
	if not (tiers is Array) or (tiers as Array).is_empty():
		errs.append("%s: survey.tiers must be a non-empty list" % file)
	else:
		var sum: float = 0.0
		for i: int in range(((tiers as Array).size())):
			var t: Variant = (tiers as Array)[i]
			if not (t is Dictionary) or str((t as Dictionary).get("name", "")).is_empty() \
					or float((t as Dictionary).get("richness", -1.0)) < 0.0 or float((t as Dictionary).get("weight", -1.0)) < 0.0:
				errs.append("%s: survey.tiers[%d] needs a name, richness >= 0 and weight >= 0" % [file, i])
			else:
				sum += float((t as Dictionary)["weight"])
		if sum <= 0.0:
			errs.append("%s: survey tier weights must add up to more than zero" % file)
	var blocks: Array[Dictionary] = [d]
	if d.get("deposit", {}) is Dictionary:
		blocks.append(d.get("deposit", {}))
	for block: Dictionary in blocks:
		for key: String in ["gems_chance", "gas_chance", "water_chance"]:
			var v: float = float(block.get(key, 0.0))
			if v < 0.0 or v > 1.0:
				errs.append("%s: survey %s must be from 0 to 1" % [file, key])
	if not (d.get("per_row", {}) is Dictionary):
		errs.append("%s: survey.per_row must be an object" % file)
	else:
		for key: Variant in (d.get("per_row", {}) as Dictionary).keys():
			var v: Variant = (d["per_row"] as Dictionary)[key]
			if not ["gems_chance", "gas_chance", "water_chance"].has(str(key)) or not (v is float or v is int) \
					or float(v) < 0.0 or float(v) > 1.0:
				errs.append("%s: survey.per_row.%s must be gems_chance, gas_chance or water_chance, 0 to 1" % [file, str(key)])
	if not (d.get("deposit", {}) is Dictionary):
		errs.append("%s: survey.deposit must be an object" % file)
	elif tiers is Array and int((d["deposit"] as Dictionary).get("min_tier", 0)) >= (tiers as Array).size():
		errs.append("%s: survey.deposit.min_tier must name an existing tier" % file)
