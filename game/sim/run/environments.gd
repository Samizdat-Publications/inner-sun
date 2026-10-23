class_name Environments
extends RefCounted
## Node environments (parity round 5, L-ENV-01 and L-ENV-02): some fight and hazard nodes sit in a
## rockfall seam, magma heat, magnetite or a gas seam. The environment acts on the segment drilled
## toward the node and on everything at the node (a fight there included), for both ships alike.
## Static: definitions, the map roll, the lint and the switch that puts one in force on a RunState.
##
## Data, game/data/environments/<id>.json: {"id", "name", "blurb", "weight" (> 0), "from_row"
## (optional, first map row it can appear in, default 1), "effects": {...}}. Effect keys (absent =
## no effect):
##   rockfall_every_s [lo, hi]: falling rock on a rhythm, the next interval drawn uniformly from
##     [lo, hi] (stream "env/rockfall", the rival's "enemy/env/rockfall"); while drilling through
##     DrillVerbs' rockfall (warning, hit, bracing soaks it), in a fight a light hit on a random room
##     of each ship (CombatSim), soaked by a bracing layer like a shot.
##   rock_temp_add_c: added to the rock temperature around both hulls.
##   fire_chance_x: multiplies every fire chance (weapon hits, pursuer strikes, autoignition),
##     the product clamped to at most 1.
##   pursuer_x: multiplies the pursuer's advance per tick.
##   scanner_blind (true): no node beyond the current row counts as revealed (RunState.is_revealed)
##     and the view hides the rival's rooms (RunState.scanner_blind).
## Layer data, "environments": {"chance": per-node chance, "node_types": the node types that may
## carry one (never "store"; the start and the gate never do)}.
##
## The map roll (MapGen.assign_envs) runs after the map is complete, from its own stream "map/env",
## so the map itself is exactly what it was before environments existed.

const EFFECTS: Array[String] = ["rockfall_every_s", "rock_temp_add_c", "fire_chance_x", "pursuer_x", "scanner_blind"]
const FIELDS: Array[String] = ["id", "name", "blurb", "weight", "from_row", "effects"]
## Lint bands (the ledger's, L-ENV-02). Rockfall: the mean interval; the others: the value itself.
const ROCKFALL_MEAN_S: Vector2 = Vector2(8.0, 15.0)
const ROCK_ADD_C: Vector2 = Vector2(20.0, 35.0)
const FIRE_X: Vector2 = Vector2(1.0, 2.5)
const PURSUER_X: Vector2 = Vector2(0.5, 0.75)


## The environment ids in a fixed order (sorted as plain Strings; never rely on table order).
static func ids(table: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in table.keys():
		out.append(str(k))
	out.sort()
	return out


## Roll one node's environment: two draws every time (the chance, then the pick), so the sequence
## never depends on the outcome. "" for none.
static func roll(table: Dictionary, order: PackedStringArray, row: int, chance: float, rng: RandomNumberGenerator) -> String:
	var hit: bool = rng.randf() < chance
	var pick: float = rng.randf()
	if not hit:
		return ""
	var total: float = 0.0
	for id: String in order:
		var d: Dictionary = table[id]
		if int(d.get("from_row", 1)) <= row:
			total += maxf(0.0, float(d.get("weight", 0.0)))
	if total <= 0.0:
		return ""
	var left: float = pick * total
	var last: String = ""
	for id: String in order:
		var d: Dictionary = table[id]
		var w: float = maxf(0.0, float(d.get("weight", 0.0)))
		if int(d.get("from_row", 1)) > row or w <= 0.0:
			continue
		last = id
		left -= w
		if left < 0.0:
			return id
	return last


## Put an environment in force on the run ("" for none) for a node (the target while drilling
## toward it, the current one while there). Emits "env_left" {"env"} and "env_entered" {"env",
## "node"}; the rock around each hull moves by the change in rock_temp_add_c at once (the drill and
## the idle step then keep it there).
static func put_in_force(sim: Sim, run: RunState, id: String, node_id: String, table: Dictionary) -> void:
	if id == run.env_id and node_id == run.env_node:
		return
	var old_p: float = run.rock_add_c(sim.player)
	var old_e: float = run.rock_add_c(sim.enemy) if sim.enemy != null else 0.0
	if not run.env_id.is_empty():
		sim.emit("env_left", {"env": run.env_id})
	var def: Dictionary = table.get(id, {}) if not id.is_empty() else {}
	if not id.is_empty() and def.is_empty():
		push_error("Environments: no environment \"%s\" in data/environments" % id)
		id = ""
	run.env_id = id
	run.env_node = node_id
	run.env = def
	run.env_serial += 1
	var fx: Dictionary = def.get("effects", {})
	run.env_fire_x = maxf(0.0, float(fx.get("fire_chance_x", 1.0)))
	run.env_rock_add = float(fx.get("rock_temp_add_c", 0.0))
	run.env_pursuer_x = maxf(0.0, float(fx.get("pursuer_x", 1.0)))
	run.scanner_blind = bool(fx.get("scanner_blind", false))
	var rf: Variant = fx.get("rockfall_every_s", [])
	run.env_rockfall_s = Vector2.ZERO
	if rf is Array and (rf as Array).size() == 2:
		run.env_rockfall_s = Vector2(float((rf as Array)[0]), float((rf as Array)[1]))
	sim.ship.rock_temp_c += run.rock_add_c(sim.player) - old_p
	if sim.enemy != null:
		sim.enemy.ship.rock_temp_c += run.rock_add_c(sim.enemy) - old_e
	if not id.is_empty():
		sim.emit("env_entered", {"env": id, "node": node_id})


## Ticks until the next rockfall of a band [lo, hi] s (at least 1), one draw.
static func next_rockfall_ticks(band: Vector2, rng: RandomNumberGenerator) -> int:
	return maxi(1, roundi(rng.randf_range(band.x, band.y) * Sim.TICK_HZ))


# Lint ------------------------------------------------------------------------------------------

static func lint(db: DataDB, errs: PackedStringArray) -> void:
	var table: Dictionary = db.table("environments")
	for id: String in ids(table):
		_lint_env(table[id], db.source_of("environments", id), id, errs)
	var layers: Dictionary = db.table("layers")
	for lid: Variant in layers.keys():
		var layer: Dictionary = layers[lid]
		if layer.has("environments"):
			_lint_layer_block(layer["environments"], db.source_of("layers", str(lid)), table, errs)


static func _num(v: Variant) -> bool:
	return v is float or v is int


static func _in(v: float, band: Vector2) -> bool:
	return v >= band.x - 0.000001 and v <= band.y + 0.000001


static func _lint_env(d: Dictionary, file: String, id: String, errs: PackedStringArray) -> void:
	for k: Variant in d.keys():
		if not FIELDS.has(str(k)):
			errs.append("%s: unknown field \"%s\" (known: %s)" % [file, str(k), ", ".join(FIELDS)])
	if file.get_file().get_basename() != id:
		errs.append("%s: id \"%s\" must match the file name" % [file, id])
	for k: String in ["name", "blurb"]:
		if not (d.get(k) is String) or str(d.get(k)).strip_edges().is_empty():
			errs.append("%s: \"%s\" must be a non-empty string" % [file, k])
	if not _num(d.get("weight")) or float(d.get("weight", 0.0)) <= 0.0:
		errs.append("%s: weight must be a number above zero" % file)
	if d.has("from_row") and (not _num(d["from_row"]) or int(d["from_row"]) < 1):
		errs.append("%s: from_row must be a number, 1 or more" % file)
	var fv: Variant = d.get("effects")
	if not (fv is Dictionary) or (fv as Dictionary).is_empty():
		errs.append("%s: effects must be a non-empty object" % file)
		return
	var fx: Dictionary = fv
	for k: Variant in fx.keys():
		var key: String = str(k)
		var v: Variant = fx[k]
		match key:
			"rockfall_every_s":
				if not (v is Array) or (v as Array).size() != 2 or not _num((v as Array)[0]) or not _num((v as Array)[1]):
					errs.append("%s: effects.rockfall_every_s must be [lo, hi] seconds" % file)
					continue
				var lo: float = float((v as Array)[0])
				var hi: float = float((v as Array)[1])
				if lo <= 0.0 or hi < lo or not _in((lo + hi) * 0.5, ROCKFALL_MEAN_S):
					errs.append("%s: effects.rockfall_every_s needs 0 < lo <= hi and a mean in %s s" % [file, str(ROCKFALL_MEAN_S)])
			"rock_temp_add_c":
				if not _num(v) or not _in(float(v), ROCK_ADD_C):
					errs.append("%s: effects.rock_temp_add_c must be a number in %s C" % [file, str(ROCK_ADD_C)])
			"fire_chance_x":
				if not _num(v) or not _in(float(v), FIRE_X):
					errs.append("%s: effects.fire_chance_x must be a number in %s" % [file, str(FIRE_X)])
			"pursuer_x":
				if not _num(v) or not _in(float(v), PURSUER_X):
					errs.append("%s: effects.pursuer_x must be a number in %s" % [file, str(PURSUER_X)])
			"scanner_blind":
				if not (v is bool) or not bool(v):
					errs.append("%s: effects.scanner_blind must be true (leave it out for no effect)" % file)
			_:
				errs.append("%s: unknown effect \"%s\" (known: %s)" % [file, key, ", ".join(EFFECTS)])


static func _lint_layer_block(v: Variant, file: String, table: Dictionary, errs: PackedStringArray) -> void:
	if not (v is Dictionary):
		errs.append("%s: environments must be an object {chance, node_types}" % file)
		return
	var b: Dictionary = v
	if not _num(b.get("chance")) or float(b.get("chance", -1.0)) < 0.0 or float(b.get("chance", 2.0)) > 1.0:
		errs.append("%s: environments.chance must be a number from 0 to 1" % file)
	var types: Variant = b.get("node_types")
	if not (types is Array) or (types as Array).is_empty():
		errs.append("%s: environments.node_types must be a non-empty list of node types" % file)
	else:
		for t: Variant in (types as Array):
			if not MapGen.NODE_TYPES.has(str(t)) or str(t) == "store":
				errs.append("%s: environments.node_types: \"%s\" cannot carry an environment (stores, the start and the gate never do)" % [file, str(t)])
	if table.is_empty() and float(b.get("chance", 0.0)) > 0.0:
		errs.append("%s: environments.chance is above zero but data/environments is empty" % file)
