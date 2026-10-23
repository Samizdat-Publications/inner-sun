extends TestCase
## Ledger rows L-ENV-01 (some fight and hazard nodes carry an environment, for both ships alike) and
## L-ENV-02 (each environment has one clear effect, in its band). Every check is a function that
## returns pass or fail, run once with the real data and once with the row's Wrong value (an
## in-memory change: the "both sides" switch off, or the environment's strength at zero or 1.0),
## which must fail. The fights use ledger_env_fight (the player's guns unpowered) with the rival
## disarmed, so they show only what the environment does; drilling uses ledger_env_drill.

const SEED: int = 7
const MAP_SEEDS: int = 1000
const LAYER: String = "crust"
const FIGHT_S: float = 160.0


# Helpers ----------------------------------------------------------------------------------------

## A scenario fight against a disarmed rival_light with `env` in force (put in by the set_env
## command before the fight, so the rival's rock comes from start_fight).
func _fight(d: DataDB, env: String, both: bool = true, p_seed: int = SEED) -> ScenarioRun:
	var r := ScenarioRun.from_scenario(d, "ledger_env_fight", p_seed)
	r.sim.run.env_both_sides = both
	if not env.is_empty():
		r.sim.push({"type": "set_env", "env": env})
	r.step()
	r.sim.combat.start_fight(r.sim, "rival_light", false)
	r.sim.combat.enemy_side = CombatSide.new()
	return r


func _drill(d: DataDB, env: String) -> ScenarioRun:
	var r := ScenarioRun.from_scenario(d, "ledger_env_drill", SEED)
	if not env.is_empty():
		r.sim.push({"type": "set_env", "env": env})
	return r


func _steps(r: ScenarioRun, seconds: float) -> void:
	for i: int in range(roundi(seconds * Sim.TICK_HZ)):
		r.step()


## Ticks of the seam's rockfalls on one side ("player" or "enemy").
func _falls(s: Sim, side: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for e: Dictionary in s.events:
		if str(e["kind"]) == "rockfall" and str(e.get("cause", "")) == "seam" and str(e.get("side", "player")) == side:
			out.append(int(e["t"]))
	return out


## Mean seconds between consecutive falls (-1 with fewer than two).
func _mean_gap_s(t: PackedInt32Array) -> float:
	if t.size() < 2:
		return -1.0
	return float(t[t.size() - 1] - t[0]) / float(t.size() - 1) / Sim.TICK_HZ


func _fx(d: DataDB, env: String) -> Dictionary:
	return (d.table("environments")[env] as Dictionary)["effects"]


## The rock temperature a ship's data gives it (scenario fights start there).
func _own_rock(w: ShipWorld) -> float:
	return float(w.ship.source_def.get("rock_temp_c", 40.0))


func _with_effect(d: DataDB, env: String, key: String, value: Variant) -> DataDB:
	((d.table("environments")[env] as Dictionary)["effects"] as Dictionary)[key] = value
	return d


func _without_effect(d: DataDB, env: String, key: String) -> DataDB:
	((d.table("environments")[env] as Dictionary)["effects"] as Dictionary).erase(key)
	return d


func _energy(w: ShipWorld) -> int:
	var e: int = 0
	for r: Room in w.ship.rooms:
		e += r.energy_j
	return e


# L-ENV-01 ---------------------------------------------------------------------------------------

func test_l_env_01() -> void:
	_map_rule()
	_in_force_on_the_map()
	check(_rockfall_both(db(), true), "rockfall seam: falling rock hits both ships in a fight")
	check(not _rockfall_both(db(), false), "Wrong value: a rockfall seam that hits only the player must fail")
	check(_magma_both(db(), true), "magma heat: both hulls sit in hotter rock and take in more heat")
	check(not _magma_both(db(), false), "Wrong value: magma that heats only the player must fail")
	check(_magnetite_both(db(), true), "magnetite: the scanner is blind and the rival's rooms are hidden")
	check(not _magnetite_both(db(), false), "Wrong value: magnetite that leaves the rival in view must fail")
	check(_gas_hits_both(db(), true), "gas seam: weapon hits light fires more easily on both ships")
	check(not _gas_hits_both(db(), false), "Wrong value: a gas seam that only the player's hull feels must fail")


## Over 1,000 seeded maps: 20 to 35% of fight and hazard nodes carry an environment, never the
## start, a store or the gate, and every map is the same seed's map without the "env" field.
func _map_rule() -> void:
	var d: DataDB = db()
	var layer: Dictionary = d.table("layers")[LAYER]
	var table: Dictionary = d.table("environments")
	var eligible: int = 0
	var with_env: int = 0
	var bad_place: int = 0
	var changed: int = 0
	var early: int = 0
	var kinds: Dictionary = {}
	for s: int in range(1, MAP_SEEDS + 1):
		# The run's own map is this one plus surveys (test_map checks that); assign_envs may only add.
		var streams := RngStreams.new(s)
		var plain: Array = MapGen.generate(layer, streams.get_stream("map"))
		var m: Array = plain.duplicate(true)
		MapGen.assign_envs(m, layer, table, streams.get_stream("map/env"))
		for r: int in range(m.size()):
			for i: int in range((m[r] as Array).size()):
				var n: Dictionary = (m[r] as Array)[i]
				var env: String = str(n.get("env", "missing"))
				var t: String = str(n["type"])
				if t == "fight" or t == "hazard":
					eligible += 1
					if not env.is_empty():
						with_env += 1
						kinds[env] = int(kinds.get(env, 0)) + 1
						if int(n["row"]) < int((table[env] as Dictionary).get("from_row", 1)):
							early += 1
				elif not env.is_empty():
					bad_place += 1
				var bare: Dictionary = n.duplicate(true)
				bare.erase("env")
				if bare != ((plain[r] as Array)[i] as Dictionary):
					changed += 1
	var share: float = float(with_env) / float(maxi(1, eligible))
	print("    environments on %d of %d fight and hazard nodes (%.1f%%) over %d maps: %s" % [with_env, eligible, share * 100.0, MAP_SEEDS, str(kinds)])
	check(share >= 0.20 and share <= 0.35, "20 to 35%% of fight and hazard nodes carry an environment (got %.1f%%)" % (share * 100.0))
	check_eq(bad_place, 0, "no environment on the start, a store, the gate or any other node type")
	check_eq(changed, 0, "a map with environments is the same seed's map node for node")
	check_eq(early, 0, "no environment above its from_row")
	for id: String in Environments.ids(table):
		check(int(kinds.get(id, 0)) > 0, "environment %s appears on some map" % id)


## A real run: every node carries "env" (what the map view reads); drilling toward a node with an
## environment puts it in force, it stays while the ship is there, and leaving it ends it.
func _in_force_on_the_map() -> void:
	var s: Sim = null
	var pick: Dictionary = {}
	for p_seed: int in range(1, 200):
		var t := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
		for n: Dictionary in (t.run.map[1] as Array):
			if not str(n["env"]).is_empty() and str(n["type"]) == "fight" and t.run.links_from_current().has(str(n["id"])) \
					and str((n["survey"] as Dictionary).get("structure", "")).is_empty():  # No break-in mid-segment.
				s = t
				pick = n
				break
		if s != null:
			break
	check(s != null, "some seed has an environment on a row-1 node")
	if s == null:
		return
	var all_have: bool = true
	for n: Dictionary in s.run.nodes:
		all_have = all_have and n.has("env")
	check(all_have, "every node of a run's map carries \"env\" (the map view's data)")
	var env: String = str(pick["env"])
	check_eq(s.run.env_id, "", "nothing in force at the start")
	s.push({"type": "choose_node", "node": pick["id"]})
	s.step()
	check_eq(s.run.env_id, env, "drilling toward the node puts its environment in force")
	check(has_event(s, "env_entered"), "env_entered")
	check_eq(s.run.state()[s.run.state().size() - 4], env, "env_id is in RunState.state()")
	var guard: int = 0
	while s.run.phase == "drill" and guard < 300 * Sim.TICK_HZ:
		s.step()
		guard += 1
	check(s.run.phase != "drill", "the segment ended")
	if s.run.current_node != str(pick["id"]):
		print("    segment ended in phase %s at %.1f s: %s" % [s.run.phase, s.seconds(), str(s.events.slice(maxi(0, s.events.size() - 6)))])
	check_eq(s.run.current_node, str(pick["id"]), "arrived at the node")
	check_eq(s.run.env_id, env, "the environment stays in force at the node")
	if s.enemy != null:
		var add: float = float(_fx(db(), env).get("rock_temp_add_c", 0.0))
		check(absf(s.enemy.ship.rock_temp_c - (_own_rock(s.enemy) + add)) < 0.001, "the rival's rock carries the environment's heat (%.2f)" % s.enemy.ship.rock_temp_c)
	# Leaving for a node without one ends it.
	if s.run.phase == "combat":
		s.combat._finish(s, "fled")
	var bare: String = ""
	for id: String in s.run.links_from_current():
		if str(s.run.node(id)["env"]).is_empty():
			bare = id
	if not bare.is_empty():
		s.push({"type": "choose_node", "node": bare})
		s.step()
		check_eq(s.run.env_id, "", "drilling on toward a node without one ends it")
		check(has_event(s, "env_left"), "env_left")


func _rockfall_both(d: DataDB, both: bool) -> bool:
	var r: ScenarioRun = _fight(d, "rockfall_seam", both)
	_steps(r, 120.0)
	var p: int = _falls(r.sim, "player").size()
	var e: int = _falls(r.sim, "enemy").size()
	print("    rockfall seam, 120 s fight (both sides %s): player %d falls, rival %d" % [str(both), p, e])
	return p >= 5 and e >= 5


## Rock temperature and heat taken in over 20 s, both ships, against the same fight without it.
func _magma_both(d: DataDB, both: bool) -> bool:
	var hot: ScenarioRun = _fight(d, "magma_heat", both)
	var cold: ScenarioRun = _fight(db(), "")
	_steps(hot, 20.0)
	_steps(cold, 20.0)
	var add: float = float(_fx(d, "magma_heat").get("rock_temp_add_c", 0.0))
	var ok: bool = true
	for k: int in range(2):
		var h: ShipWorld = hot.sim.player if k == 0 else hot.sim.enemy
		var c: ShipWorld = cold.sim.player if k == 0 else cold.sim.enemy
		var dt: float = h.ship.rock_temp_c - c.ship.rock_temp_c
		var de: int = _energy(h) - _energy(c)
		print("    magma (both sides %s), %s: rock +%.1f C, %d J more heat in the rooms after 20 s" % [str(both), h.side, dt, de])
		ok = ok and absf(dt - add) < 0.001 and add > 0.0 and de > 0
	return ok


func _magnetite_both(d: DataDB, both: bool) -> bool:
	var r: ScenarioRun = _fight(d, "magnetite", both)
	return r.sim.run.scanner_blind and r.sim.run.rival_rooms_hidden()


## Forty weapon strikes on each ship with a fire chance of 0.5: under gas (x2.0, clamped to 1)
## every one lights its room.
func _gas_hits_both(d: DataDB, both: bool) -> bool:
	var counts: PackedInt32Array = _strike_fires(d, "gas_seam", both, 40)
	print("    gas seam (both sides %s): 40 strikes at fire chance 0.5 lit %d player rooms, %d rival rooms" % [str(both), counts[0], counts[1]])
	return counts[0] == 40 and counts[1] == 40


func _strike_fires(d: DataDB, env: String, both: bool, n: int) -> PackedInt32Array:
	var r: ScenarioRun = _fight(d, env, both)
	var s: Sim = r.sim
	var w: WeaponDef = s.combat.player_side.defs[0]
	w.fire_chance = 0.5
	var rng: RandomNumberGenerator = s.rng.get_stream("test/strikes")
	var out := PackedInt32Array([0, 0])
	for i: int in range(n):
		for k: int in range(2):
			var tw: ShipWorld = s.player if k == 0 else s.enemy
			var ri: int = i % tw.ship.rooms.size()
			tw.ship.rooms[ri].fire = 0.0
			CombatHits._strike(s, tw, ri, w, w.damage, rng, 0.2)
			if tw.ship.rooms[ri].fire > 0.0:
				out[k] += 1
	return out


# L-ENV-02 ---------------------------------------------------------------------------------------

func test_l_env_02() -> void:
	check(_rockfall_band(db()), "rockfall seam: one fall every 8 to 15 s per ship, soaked by bracing")
	check(not _rockfall_band(_with_effect(db(), "rockfall_seam", "rockfall_every_s", [0.0, 0.0])), "Wrong value: a rockfall seam at zero must fail")
	check(_magma_band(db()), "magma heat: rock 20 to 35 C hotter than the row's own")
	check(not _magma_band(_with_effect(db(), "magma_heat", "rock_temp_add_c", 0.0)), "Wrong value: magma at zero must fail")
	check(_magnetite_band(db()), "magnetite: pursuer x0.5 to x0.75 and nothing ahead revealed")
	check(not _magnetite_band(_with_effect(db(), "magnetite", "pursuer_x", 1.0)), "Wrong value: magnetite with a full-speed pursuer must fail")
	check(not _magnetite_band(_without_effect(db(), "magnetite", "scanner_blind")), "Wrong value: magnetite with a working scanner must fail")
	check(_gas_band(db()), "gas seam: every fire chance x1.5 to x2.5 for both ships")
	check(not _gas_band(_with_effect(db(), "gas_seam", "fire_chance_x", 1.0)), "Wrong value: a gas seam at 1.0 must fail")


## Drilling: the seam's falls come on a rhythm with a mean interval of 8 to 15 s, through the drill's
## rockfall (a warning first). In a fight: the same on each ship; braced, a layer soaks the fall;
## unbraced, it costs rockfall_hull_pts hull.
func _rockfall_band(d: DataDB) -> bool:
	var dr: ScenarioRun = _drill(d, "rockfall_seam")
	_steps(dr, 160.0)
	var drill_gap: float = _mean_gap_s(_falls(dr.sim, "player"))
	var warned: bool = has_event(dr.sim, "rockfall_warn")
	var fight: ScenarioRun = _fight(d, "rockfall_seam")
	_steps(fight, FIGHT_S)
	var pg: float = _mean_gap_s(_falls(fight.sim, "player"))
	var eg: float = _mean_gap_s(_falls(fight.sim, "enemy"))
	var soaked: bool = true
	for e: Dictionary in fight.sim.events:
		if str(e["kind"]) == "rockfall" and str(e.get("side", "player")) == "player" and not bool(e["absorbed"]):
			soaked = false
	# Unbraced: every fall costs the hull.
	var bare: ScenarioRun = _fight(d, "rockfall_seam")
	bare.sim.push({"type": "power", "room": "bracing", "bars": 0})
	var hull0: int = bare.sim.run.get_res("hull")
	_steps(bare, 60.0)
	var falls: int = 0
	for e: Dictionary in bare.sim.events:
		if str(e["kind"]) == "rockfall" and str(e.get("side", "player")) == "player" and not bool(e["absorbed"]):
			falls += 1
	var lost: int = hull0 - bare.sim.run.get_res("hull")
	var want: int = falls * roundi(d.tune("drill.rockfall_hull_pts"))
	print("    rockfall seam: mean gap drilling %.2f s, fight player %.2f s, rival %.2f s; unbraced %d falls cost %d hull" % [drill_gap, pg, eg, falls, lost])
	var in_band: bool = true
	for g: float in [drill_gap, pg, eg]:
		in_band = in_band and g >= 8.0 and g <= 15.0
	return in_band and warned and soaked and falls > 0 and lost == want


## Rock temperature with magma minus without, while drilling (same depth) and around the rival.
func _magma_band(d: DataDB) -> bool:
	var hot: ScenarioRun = _drill(d, "magma_heat")
	var cold: ScenarioRun = _drill(db(), "")
	_steps(hot, 30.0)
	_steps(cold, 30.0)
	var add_drill: float = hot.sim.ship.rock_temp_c - cold.sim.ship.rock_temp_c
	var same_depth: bool = absf(hot.sim.run.depth_m - cold.sim.run.depth_m) < 0.001
	var f: ScenarioRun = _fight(d, "magma_heat")
	var add_rival: float = f.sim.enemy.ship.rock_temp_c - _own_rock(f.sim.enemy)
	print("    magma: drilling rock +%.2f C (same depth %s), rival's rock +%.2f C" % [add_drill, str(same_depth), add_rival])
	return same_depth and add_drill >= 20.0 and add_drill <= 35.0 and add_rival >= 20.0 and add_rival <= 35.0


## A run at its start: the pursuer's advance over 10 s with magnetite in force against without, and
## no node beyond the current row revealed (the target excepted).
func _magnetite_band(d: DataDB) -> bool:
	var rates: PackedFloat64Array = PackedFloat64Array()
	var hidden: bool = true
	for k: int in range(2):
		var s := Sim.new(d, SEED, "light_drill", {"mode": "run"})
		if k == 1:
			Environments.put_in_force(s, s.run, "magnetite", "", d.table("environments"))
		var r0: float = s.run.pursuer_row
		run_seconds(s, 10.0)
		rates.append(s.run.pursuer_row - r0)
		if k == 1:
			for n: Dictionary in s.run.nodes:
				if int(n["row"]) > s.run.current_row() and s.run.is_revealed(n):
					hidden = false
	var ratio: float = rates[1] / maxf(rates[0], 1e-12)
	print("    magnetite: pursuer x%.3f, next rows hidden %s" % [ratio, str(hidden)])
	return ratio >= 0.5 and ratio <= 0.75 and hidden


## Autoignition per hot room and hazard step, gas against none, for both ships (rooms held at 130 C,
## each fire put out at once so every step is a fresh trial; autoignite_per_s raised to 0.2 for
## more trials per second, the ratio does not depend on it), plus pursuer strikes and weapon hits.
func _gas_band(d: DataDB) -> bool:
	d.tuning["fire.autoignite_per_s"] = 0.2
	var base: Vector2 = _autoignite(d, "")
	var gas: Vector2 = _autoignite(d, "gas_seam")
	var rp: float = gas.x / maxf(base.x, 1e-12)
	var re: float = gas.y / maxf(base.y, 1e-12)
	var fx: float = float(_fx(d, "gas_seam").get("fire_chance_x", 1.0))
	# Pursuer strikes at fire chance 0.5: the multiplier, clamped to 1, lights every one at x2.
	d.tuning["run.strike_fire_chance"] = 0.5
	var s := Sim.new(d, SEED, "light_drill", {"mode": "run"})
	Environments.put_in_force(s, s.run, "gas_seam", "", d.table("environments"))
	var lit: int = 0
	for i: int in range(30):
		for r: Room in s.ship.rooms:
			r.fire = 0.0
		var n0: int = s.events.size()
		s.run._strike(s, "caught")
		for j: int in range(n0, s.events.size()):
			if str(s.events[j]["kind"]) == "fire_started":
				lit += 1
	var hits: PackedInt32Array = _strike_fires(d, "gas_seam", true, 40)
	print("    gas seam: autoignition x%.2f player, x%.2f rival (data x%.2f); 30 strikes at 0.5 lit %d; 40 hits at 0.5 lit %d and %d" % [rp, re, fx, lit, hits[0], hits[1]])
	var ok: bool = rp >= 1.5 and rp <= 2.5 and re >= 1.5 and re <= 2.5
	if fx * 0.5 >= 1.0:
		ok = ok and lit == 30 and hits[0] == 40 and hits[1] == 40
	return ok


## Fires started per hot-room hazard step: (player, rival).
func _autoignite(d: DataDB, env: String) -> Vector2:
	var fires := Vector2.ZERO
	var trials := Vector2.ZERO
	for k: int in range(10):
		var r: ScenarioRun = _fight(d, env, true, SEED + k)
		var s: Sim = r.sim
		var worlds: Array[ShipWorld] = [s.player, s.enemy]
		for w: ShipWorld in worlds:
			w.hazards.coolant_on = false
		for t: int in range(20 * Sim.TICK_HZ):
			for w: ShipWorld in worlds:
				w.ship.rock_temp_c = 130.0
				for rm: Room in w.ship.rooms:
					rm.fire = 0.0
					rm.set_temp_c(130.0)
				for c: CrewMember in w.ship.crew:
					c.hp = CrewMember.MAX_HP
			var n0: int = s.events.size()
			var hazard_step: bool = s.tick % Sim.HAZARD_EVERY == 0
			s.step()
			if hazard_step:
				trials += Vector2(float(s.player.ship.rooms.size()), float(s.enemy.ship.rooms.size()))
			for j: int in range(n0, s.events.size()):
				var e: Dictionary = s.events[j]
				if str(e["kind"]) == "fire_started":
					if str(e.get("side", "player")) == "player":
						fires.x += 1.0
					else:
						fires.y += 1.0
	return Vector2(fires.x / maxf(1.0, trials.x), fires.y / maxf(1.0, trials.y))


# Determinism ------------------------------------------------------------------------------------

## Same seed and commands, same hash; the new streams leave the map and survey streams where they
## were (the map stream ends exactly where a bare MapGen.generate leaves it).
func test_env_determinism() -> void:
	var hashes := PackedStringArray()
	for k: int in range(2):
		var s := Sim.new(db(), SEED, "light_drill", {"mode": "run"})
		s.push({"type": "choose_node", "node": s.run.links_from_current()[0]})
		run_seconds(s, 20.0)
		hashes.append(s.state_hash())
	check_eq(hashes[0], hashes[1], "same seed, same commands, same hash")
	var s2 := Sim.new(db(), SEED, "light_drill", {"mode": "run"})
	var bare := RngStreams.new(SEED)
	MapGen.generate(db().table("layers")[LAYER], bare.get_stream("map"))
	check_eq(s2.rng.get_stream("map").state, bare.get_stream("map").state, "the map stream is untouched by environments")
	check(s2.rng.state().has("map/env"), "environments draw from their own stream")
	# The set_env command: scenarios only, known ids only.
	var r := ScenarioRun.from_scenario(db(), "ledger_env_fight", SEED)
	r.sim.push({"type": "set_env", "env": "no_such_env"})
	r.step()
	check(has_event(r.sim, "bad_command") and r.sim.run.env_id.is_empty(), "an unknown environment is refused")
	s2.push({"type": "set_env", "env": "gas_seam"})
	s2.step()
	check(s2.run.env_id.is_empty(), "set_env is refused in a run")


func test_env_lint() -> void:
	check_eq(Array(db().lint()).filter(func(e: String) -> bool: return e.contains("environments")), [], "the environment data lints clean")
	var d: DataDB = _with_effect(db(), "gas_seam", "fire_chance_x", 9.0)
	_with_effect(d, "magma_heat", "rock_wobble", 1.0)
	(d.table("layers")[LAYER] as Dictionary)["environments"] = {"chance": 0.27, "node_types": ["store"]}
	var errs: String = "\n".join(d.lint())
	check(errs.contains("fire_chance_x must be a number in"), "a fire multiplier out of its band is caught")
	check(errs.contains("unknown effect \"rock_wobble\""), "an unknown effect key is caught")
	check(errs.contains("cannot carry an environment"), "a store as an environment node type is caught")
