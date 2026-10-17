extends TestCase
## The away miner (game/sim/drill/drill_miner.gd, D046): refusals, the whole sortie, the parked drill,
## away crew, pocket and fault harm, death, recall, crates, fights, strikes, determinism and replay.
## The haul is checked with exact integer equality against the cells the miner cut.

const HEAD := Vector2(16.0, 10.0)  ## light_drill's drill head at the start of a straight segment.


## A scenario-mode sim on light_drill with a segment begun, every rock cell outside the ship set to
## granite (hardness 1), crew judgement off. drill_bars 0 keeps the drill still (only the miner cuts).
func _sim(drill_bars: int = 0, overrides: Dictionary = {}) -> Sim:
	var s := Sim.new(db(overrides), 11, "light_drill")
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": drill_bars})
	crew_auto_off(s)
	s.step()
	s.push({"type": "begin_segment", "segment": "m", "depth_m": 36.0, "lateral_m": 0.0})
	s.step()
	_fill_all(s, _code(s, "rock"))
	return s


func _code(s: Sim, id: String) -> int:
	for c: int in range(s.drill.materials.size()):
		if str(s.drill.materials[c].get("id", "")) == id:
			return c
	return -1


func _fill_all(s: Sim, code: int) -> void:
	var d: DrillSim = s.drill
	var ship := Rect2(d.ship_pos, d.ship_size)
	for r: int in range(d.rows):
		for c: int in range(d.cols):
			if not ship.has_point(Vector2((c + 0.5) * d.cell_m, (r + 0.5) * d.cell_m)):
				d.grid[r * d.cols + c] = code
	d._band_dirty = true


## Cells [c0..c1] x [r0..r1] become one material (test setup only).
func _box(s: Sim, c0: int, c1: int, r0: int, r1: int, code: int) -> void:
	for r: int in range(r0, r1 + 1):
		for c: int in range(c0, c1 + 1):
			s.drill.grid[r * s.drill.cols + c] = code


func _send(s: Sim, crew: String, p: Vector2) -> void:
	s.push({"type": "send_miner", "crew": crew, "x_m": p.x, "y_m": p.y})
	s.step()


## Step until the miner is no longer active (or the limit); returns the phases seen, in order.
func _run_sortie(s: Sim, limit_s: float = 120.0) -> PackedStringArray:
	var seen := PackedStringArray()
	for i: int in range(roundi(limit_s * Sim.TICK_HZ)):
		var p: String = s.drill.miner.phase
		if not p.is_empty() and (seen.is_empty() or seen[seen.size() - 1] != p):
			seen.append(p)
		if not s.drill.miner.active:
			break
		s.step()
	return seen


func _step_until_phase(s: Sim, phase: String, limit_s: float = 60.0) -> void:
	for i: int in range(roundi(limit_s * Sim.TICK_HZ)):
		if s.drill.miner.phase == phase:
			return
		s.step()


func _count(s: Sim, kind: String) -> int:
	var n: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == kind:
			n += 1
	return n


func _last(s: Sim, kind: String) -> Dictionary:
	for i: int in range(s.events.size() - 1, -1, -1):
		if str(s.events[i]["kind"]) == kind:
			return s.events[i]
	return {}


func _last_why(s: Sim, kind: String) -> String:
	for i: int in range(s.events.size() - 1, -1, -1):
		var e: Dictionary = s.events[i]
		if str(e["kind"]) == "bad_command" and str(e.get("type", "")) == kind:
			return str(e.get("why", ""))
	return ""


## Ore and gem units the cells that changed from `before` to now yield at full rate (exact).
func _yield_of_changes(s: Sim, before: PackedByteArray) -> PackedInt32Array:
	var d: DrillSim = s.drill
	var out := PackedInt32Array()
	out.resize(RunState.RESOURCES.size())
	for i: int in range(before.size()):
		if before[i] != d.grid[i] and d.yield_res_of[before[i]] >= 0:
			out[d.yield_res_of[before[i]]] += d.yield_amount_of[before[i]]
	return out


func _changed(s: Sim, before: PackedByteArray) -> int:
	var n: int = 0
	for i: int in range(before.size()):
		if before[i] != s.drill.grid[i]:
			n += 1
	return n


# Refusals ----------------------------------------------------------------------------------------

func test_refusals_name_each_reason() -> void:
	var s := Sim.new(db(), 11, "light_drill")
	s.step()
	_send(s, "okafor", Vector2(20.0, 12.0))
	check_eq(_last_why(s, "send_miner"), "no_segment", "no segment under way")
	s.push({"type": "begin_segment", "segment": "m", "depth_m": 36.0, "lateral_m": 0.0})
	s.step()
	var d: DrillSim = s.drill
	_send(s, "nobody", Vector2(20.0, 12.0))
	check_eq(_last_why(s, "send_miner"), "no_crew", "an unknown crew member")
	_send(s, "okafor", Vector2(16.0, 0.5))
	check_eq(_last_why(s, "send_miner"), "outside", "above the ship's top edge")
	_send(s, "okafor", Vector2(-1.0, 12.0))
	check_eq(_last_why(s, "send_miner"), "outside", "off the grid")
	_send(s, "okafor", Vector2(d.ship_pos.x + 2.0, d.ship_pos.y + 4.0))
	check_eq(_last_why(s, "send_miner"), "outside", "inside the ship")
	_send(s, "okafor", DrillMiner.head(d) + Vector2(12.5, 1.0))
	check_eq(_last_why(s, "send_miner"), "range", "beyond range_m of the head")
	check_eq(DrillMiner.target_ok(d, s, "okafor", DrillMiner.head(d) + Vector2(6.0, 2.0)), "", "a fair target is ok")
	s.push({"type": "recall_miner"})
	s.step()
	check_eq(_last_why(s, "recall_miner"), "no_miner", "recall with nobody out")
	_send(s, "okafor", DrillMiner.head(d) + Vector2(6.0, 2.0))
	check(d.miner.active, "the miner is sent")
	_send(s, "vasquez", DrillMiner.head(d) + Vector2(-6.0, 2.0))
	check_eq(_last_why(s, "send_miner"), "miner_out", "only one miner at a time")
	s.ship.crew_by_id("lindqvist").alive = false
	check_eq(DrillMiner.target_ok(d, s, "lindqvist", DrillMiner.head(d) + Vector2(6.0, 2.0)), "miner_out", "miner_out comes first")
	var s2: Sim = _sim()
	s2.ship.crew_by_id("lindqvist").alive = false
	_send(s2, "lindqvist", HEAD + Vector2(6.0, 2.0))
	check_eq(_last_why(s2, "send_miner"), "no_crew", "a dead crew member cannot go")


# The whole sortie --------------------------------------------------------------------------------

func test_full_sortie_pays_the_exact_haul_on_return() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	var iron: int = _code(s, "iron_ore")
	var gem: int = _code(s, "gem")
	_box(s, 42, 46, 22, 25, iron)  # A 5 x 4 vein around the target (20 cells x 2 ore).
	_box(s, 47, 47, 23, 23, gem)  # A gem cell touching it.
	_box(s, 30, 30, 30, 30, iron)  # Far away: never dug.
	var before: PackedByteArray = d.grid.duplicate()
	var ore0: int = s.run.get_res("ore")
	var gems0: int = s.run.get_res("gems")
	var mined0: int = 0
	for v: int in d.mined:
		mined0 += v
	var chunks0: int = 0
	for v: int in d.chunk_changes:
		chunks0 += v
	_send(s, "okafor", Vector2(22.25, 11.75))
	check_eq(d.miner.phase, "board", "boarding first")
	check(not d.parked, "the drill is not parked while boarding")
	var paid_early: bool = false
	var seen := PackedStringArray()
	for i: int in range(120 * Sim.TICK_HZ):
		var p: String = d.miner.phase
		if not p.is_empty() and (seen.is_empty() or seen[seen.size() - 1] != p):
			seen.append(p)
		if not d.miner.active:
			break
		if s.run.get_res("ore") != ore0 or s.run.get_res("gems") != gems0:
			paid_early = true
		if d.miner.is_out():
			check(d.parked, "parked while out")
			check(s.ship.crew_by_id("okafor").away, "away while out")
		s.step()
	check_eq(",".join(seen), "board,exit,dig,vein,return,enter", "the phases in order")
	check(not paid_early, "nothing is paid while the miner is out")
	check(not d.miner.active and not d.parked, "back aboard: the drill unparks")
	var c: CrewMember = s.ship.crew_by_id("okafor")
	check(not c.away and c.alive, "okafor is aboard again")
	check_eq(c.room, d.drill_room, "in the drill room")
	var want: PackedInt32Array = _yield_of_changes(s, before)
	var ore_i: int = RunState.RESOURCES.find("ore")
	var gem_i: int = RunState.RESOURCES.find("gems")
	check_eq(want[ore_i], 40, "the whole 20-cell vein was mined out")
	check_eq(want[gem_i], 1, "and the gem touching it")
	check_eq(s.run.get_res("ore") - ore0, want[ore_i], "ore paid equals the dug cells' yield exactly")
	check_eq(s.run.get_res("gems") - gems0, want[gem_i], "gems paid equals the dug cells' yield exactly")
	var back: Dictionary = _last(s, "miner_back")
	check_eq(int((back["haul"] as Dictionary).get("ore", 0)), want[ore_i], "miner_back carries the haul")
	check_eq(d.grid[30 * d.cols + 30], iron, "the far ore is untouched")
	var mined1: int = 0
	for v: int in d.mined:
		mined1 += v
	var chunks1: int = 0
	for v: int in d.chunk_changes:
		chunks1 += v
	check_eq(mined1 - mined0, _changed(s, before), "every dug cell is counted in mined")
	check_eq(chunks1 - chunks0, _changed(s, before), "every dug cell bumps its chunk")
	check_eq(d.yielded[ore_i], 0, "the drill's own yield books stay clean")
	var sm: Dictionary = s.run.summary(s)
	check_eq(int(sm["sorties"]), 1, "summary: one sortie")
	check_eq(int(sm["haul_ore"]), want[ore_i], "summary: haul ore")
	check_eq(_count(s, "miner_out"), 1, "one miner_out event")


func test_tunnel_is_walkable_and_level_targets_go_round_the_hull() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	var target := Vector2(d.ship_pos.x + d.ship_size.x + 1.25, d.ship_pos.y + 6.25)  # Beside the hull.
	var before: PackedByteArray = d.grid.duplicate()
	_send(s, "okafor", target)
	_run_sortie(s)
	var fp: PackedInt32Array = MinerRoute.footprint(d)
	var dug := PackedInt32Array()
	for i: int in range(before.size()):
		if before[i] != d.grid[i]:
			dug.append(i)
			var r: int = i / d.cols
			var c: int = i % d.cols
			check(not (c >= fp[0] and c <= fp[1] and r >= fp[2] and r <= fp[3]), "no dug cell inside the footprint")
	check_gt(float(dug.size()), 10.0, "a tunnel was dug")
	# 4-connected: every dug cell touches another dug cell (or is the cell under the head).
	for i: int in dug:
		var touching: bool = false
		for j: int in dug:
			if absi(j - i) == d.cols or (absi(j - i) == 1 and j / d.cols == i / d.cols):
				touching = true
		check(touching, "dug cell %d touches the tunnel" % i)
	check_eq(d.grid[floori(target.y / d.cell_m) * d.cols + floori(target.x / d.cell_m)], 0, "the target cell is open")


func test_barren_target_turns_back_on_arrival() -> void:
	var s: Sim = _sim()
	_send(s, "okafor", HEAD + Vector2(3.0, 3.0))
	var seen: PackedStringArray = _run_sortie(s)
	check_eq(",".join(seen), "board,exit,dig,return,enter", "no vein phase in barren rock")
	check_eq(_count(s, "miner_back"), 1, "back aboard")


# The parked drill --------------------------------------------------------------------------------

func test_drill_parks_while_out_and_resumes() -> void:
	var s: Sim = _sim(2)
	var d: DrillSim = s.drill
	_send(s, "okafor", DrillMiner.head(d) + Vector2(5.0, 3.0))
	_step_until_phase(s, "exit")
	check(d.parked, "parked from the exit on")
	var y0: float = d.ship_pos.y
	var heat0: int = d.heat_added_j
	var wear0: float = d.bit_wear
	var noise0: float = d.noise_segment
	var ticks0: int = d.segment_ticks
	_step_until_phase(s, "return")
	check_eq(d.ship_pos.y, y0, "the ship does not move while parked")
	check_eq(d.heat_added_j, heat0, "no drill heat while parked")
	check_eq(d.bit_wear, wear0, "no bit wear while parked")
	check_eq(d.speed_m_s, 0.0, "speed 0")
	check(d.segment_ticks > ticks0, "the segment clock keeps going")
	var cells: int = d.miner.cells_dug
	check(is_equal_approx(d.noise_segment - noise0, float(cells) * s.db.tune("miner.noise_per_cell")),
			"only the miner's noise: noise_per_cell per dug cell")
	_run_sortie(s)
	check(not d.parked, "unparked on return")
	run_seconds(s, 1.0)
	check_gt(d.ship_pos.y, y0, "the drill moves again")


func test_miner_noise_is_about_a_tenth_of_drilling_the_same_cells() -> void:
	var s: Sim = _sim(3)
	var d: DrillSim = s.drill
	s.push({"type": "power", "room": "drill", "bars": 3})
	var noise0: float = d.noise_segment
	var mined0: int = 0
	for v: int in d.mined:
		mined0 += v
	run_seconds(s, 6.0)
	var mined1: int = 0
	for v: int in d.mined:
		mined1 += v
	var per_cell: float = (d.noise_segment - noise0) / float(maxi(1, mined1 - mined0))
	var ratio: float = s.db.tune("miner.noise_per_cell") / per_cell
	print("miner noise calibration: drill %.4f per cell at 3 bars in granite, miner/drill %.3f" % [per_cell, ratio])
	check_gt(ratio, 0.05, "the miner is not silent")
	check_lt(ratio, 0.2, "the miner is much quieter than the drill")


func test_segment_end_while_boarding_calls_the_sortie_off() -> void:
	var s: Sim = _sim(4)
	var d: DrillSim = s.drill
	d.target_y = d.ship_pos.y + d.ship_size.y + 0.3  # Arrive almost at once.
	_send(s, "vasquez", DrillMiner.head(d) + Vector2(5.0, 3.0))  # From the bridge: a long walk.
	run_seconds(s, 3.0)
	check(not d.active, "the segment ended")
	check(not d.miner.active, "the sortie is off")
	check(bool(_last(s, "miner_back").get("called_off", false)), "called off, nothing carried")
	check(not s.ship.crew_by_id("vasquez").away, "vasquez never left")
	check_eq(int(s.run.summary(s)["sorties"]), 0, "no sortie counted")


# Away crew ---------------------------------------------------------------------------------------

func test_away_crew_man_nothing_and_ignore_room_fire() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	var helm: int = s.ship.room_index("bridge")
	check(s.systems.is_manned(s.player, helm), "vasquez mans the helm before")
	_send(s, "vasquez", HEAD + Vector2(6.0, 6.0))
	_step_until_phase(s, "dig")
	var c: CrewMember = s.ship.crew_by_id("vasquez")
	check(c.away, "vasquez is out")
	check(not s.systems.is_manned(s.player, helm), "the helm is unmanned")
	check(not s.systems.is_manned(s.player, d.drill_room), "an away miner does not man the drill room")
	check_eq(c.room, d.drill_room, "room stays valid (the drill room)")
	var hp0: float = c.hp
	var pos0: Vector2 = c.pos
	s.push({"type": "ignite", "room": "drill", "level": 1.0})
	run_seconds(s, 3.0)
	check_eq(c.hp, hp0, "a fire in the drill room does not hurt the away miner")
	check_eq(c.pos, pos0, "CrewAI leaves away crew alone")
	check_eq(c.job_kind, "sortie", "the job stays the sortie")


# Harm ------------------------------------------------------------------------------------------

func test_gas_pocket_burns_off_and_hurts_the_miner_only() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	_box(s, 34, 36, 21, 23, _code(s, "gas_pocket"))
	_send(s, "okafor", Vector2(17.75, 11.75))  # The route's last cells cross the pocket.
	_run_sortie(s)
	var hurt: Dictionary = _last(s, "miner_hurt")
	check_eq(str(hurt.get("cause", "")), "miner_gas", "gas hurts the miner")
	check_eq(float(hurt.get("hp", 0.0)), s.db.tune("miner.gas_hp"), "by gas_hp")
	check_eq(_count(s, "fire_started"), 0, "no fire aboard")
	check_eq(d.gas_bursts, 0, "no gas burst in the ship")
	for r: int in range(21, 24):
		for c: int in range(34, 37):
			check_eq(d.grid[r * d.cols + c], 0, "the whole pocket burned off")
			check_eq(d.burst_marks[r * d.cols + c], 1, "and is marked burst")


func test_water_pocket_drains_into_the_tunnel() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	_box(s, 32, 37, 21, 23, _code(s, "water_pocket"))
	var water0: int = s.hazards.water_in_ml
	_send(s, "okafor", Vector2(17.75, 11.75))
	_run_sortie(s)
	check_eq(str(_last(s, "miner_hurt").get("cause", "")), "miner_water", "water hurts the miner")
	check_eq(s.hazards.water_in_ml, water0, "no water enters the ship")
	check_eq(s.ship.total_water_ml(), 0, "the ship is dry")
	check_eq(d.water_in_ml, 0, "the drill room got nothing")
	check_eq(d.grid[22 * d.cols + 32], 0, "the far end of the pocket drained too")
	check_eq(s.ship.crew_by_id("okafor").hp, CrewMember.MAX_HP - s.db.tune("miner.water_hp"), "hp down by water_hp")


func test_fault_rock_strain_drops_a_rockfall_on_the_miner() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	_fill_all(s, _code(s, "fault_rock"))
	_send(s, "okafor", HEAD + Vector2(7.0, 5.0))
	_step_until_phase(s, "dig")
	var warned: bool = false
	for i: int in range(60 * Sim.TICK_HZ):
		if d.miner.rockfall_ticks > 0:
			warned = true
		if _count(s, "miner_hurt") > 0 or not d.miner.active:
			break
		s.step()
	check(warned, "a rockfall was scheduled")
	check_eq(_count(s, "miner_rockfall_warn"), 1, "warned once")
	var hurt: Dictionary = _last(s, "miner_hurt")
	check_eq(str(hurt.get("cause", "")), "miner_rockfall", "the rockfall hits the miner")
	check_eq(float(hurt.get("hp", 0.0)), s.db.tune("miner.rockfall_hp"), "for rockfall_hp")
	check_eq(d.verbs.strain, 0, "the drill's own strain is untouched")
	check_eq(d.verbs.rockfalls, 0, "no rockfall on the ship")


func test_pursuer_strike_hits_a_miner_outside() -> void:
	var s: Sim = _sim()
	_send(s, "okafor", HEAD + Vector2(6.0, 4.0))
	s.run._strike(s, "caught")
	check_eq(_count(s, "miner_hurt"), 0, "boarding: not hit")
	_step_until_phase(s, "dig")
	s.run._strike(s, "caught")
	var hurt: Dictionary = _last(s, "miner_hurt")
	check_eq(str(hurt.get("cause", "")), "miner_strike", "the strike hits the miner")
	check_eq(s.ship.crew_by_id("okafor").hp, CrewMember.MAX_HP - s.db.tune("miner.strike_hp"), "for strike_hp")


func test_death_loses_the_haul_and_records_the_cause() -> void:
	var s: Sim = _sim(0, {"miner.gas_hp": 150.0})
	var d: DrillSim = s.drill
	var iron: int = _code(s, "iron_ore")
	_box(s, 32, 37, 20, 20, iron)  # Ore along the way out.
	_box(s, 35, 37, 22, 23, _code(s, "gas_pocket"))
	var ore0: int = s.run.get_res("ore")
	_send(s, "okafor", Vector2(18.25, 11.75))
	_run_sortie(s)
	var c: CrewMember = s.ship.crew_by_id("okafor")
	check(not c.alive, "the miner died")
	check_eq(c.cause_of_death, "miner_gas", "of gas")
	check_eq(c.hp, 0.0, "hp clamps at 0")
	var lost: Dictionary = _last(s, "miner_lost")
	check_eq(str(lost.get("cause", "")), "miner_gas", "miner_lost names the cause")
	check_gt(float(int((lost["haul"] as Dictionary).get("ore", 0))), 0.0, "they were carrying ore")
	check_eq(s.run.get_res("ore"), ore0, "the haul is lost: no ore paid")
	check_eq(_count(s, "crew_died"), 1, "crew_died too")
	check(not d.miner.active and not d.parked, "the drill unparks")
	check_eq(int(s.run.summary(s)["miner_deaths"]), 1, "summary: one miner death")


func test_recall_mid_dig_brings_back_a_partial_haul() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	_fill_all(s, _code(s, "coal"))  # Every cell yields 1 ore.
	var ore0: int = s.run.get_res("ore")
	_send(s, "okafor", HEAD + Vector2(8.0, 7.0))
	_step_until_phase(s, "dig")
	run_seconds(s, 4.0)
	s.push({"type": "recall_miner"})
	s.step()
	check_eq(d.miner.phase, "return", "turned back at once")
	var dug: int = d.miner.cells_dug
	_run_sortie(s)
	check_eq(s.run.get_res("ore") - ore0, dug, "every dug coal cell paid exactly 1 ore")
	check_lt(float(dug), 20.0, "short of the target")
	check_gt(float(dug), 0.0, "but something")


func test_recall_while_boarding_and_while_climbing_out() -> void:
	var s: Sim = _sim()
	_send(s, "okafor", HEAD + Vector2(6.0, 4.0))
	s.push({"type": "recall_miner"})
	s.step()
	check(not s.drill.miner.active, "called off while boarding")
	check(not s.ship.crew_by_id("okafor").away, "never left")
	_send(s, "okafor", HEAD + Vector2(6.0, 4.0))
	_step_until_phase(s, "exit")
	run_seconds(s, 0.5)
	s.push({"type": "recall_miner"})
	s.step()
	check_eq(s.drill.miner.phase, "enter", "climbing back in")
	_run_sortie(s, 5.0)
	check(not s.drill.miner.active, "aboard again")


func test_crate_pays_into_the_haul_not_the_run() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	d.structures.id = "test_works"
	d.structures.def = {"id": "test_works", "loot": [{"res": "ore", "amount": 7, "weight": 1.0}]}
	var i: int = 23 * d.cols + 40
	d.grid[i] = _code(s, "crate")
	d.structure_marks[i] = StructureStamp.MARK_INTERIOR
	var ore0: int = s.run.get_res("ore")
	_send(s, "okafor", Vector2(20.25, 11.75))
	var seen_haul: int = 0
	for k: int in range(60 * Sim.TICK_HZ):
		if not d.miner.active:
			break
		seen_haul = maxi(seen_haul, d.miner.haul[RunState.RESOURCES.find("ore")])
		check_eq(s.run.get_res("ore"), ore0, "nothing paid while out")
		s.step()
	check_eq(seen_haul, 7, "the crate's roll went into the haul")
	check_eq(s.run.get_res("ore") - ore0, 7, "and is paid on return")
	check(bool(_last(s, "loot").get("miner", false)), "the loot event says the miner opened it")
	check_eq(d.structures.crates_opened, 1, "one crate opened")


func test_a_fight_pulls_the_miner_aboard() -> void:
	var s: Sim = _sim()
	_fill_all(s, _code(s, "coal"))
	_send(s, "okafor", HEAD + Vector2(6.0, 6.0))
	_step_until_phase(s, "dig")
	run_seconds(s, 2.0)
	var ore0: int = s.run.get_res("ore")
	var carried: int = s.drill.miner.haul[RunState.RESOURCES.find("ore")]
	s.combat.start_fight(s, "rival_light", false)
	s.step()
	check(not s.drill.miner.active, "pulled aboard at once")
	check(not s.ship.crew_by_id("okafor").away, "okafor is aboard")
	check_eq(s.run.get_res("ore") - ore0, carried, "the haul is paid")


# Determinism and replay --------------------------------------------------------------------------

func _demo_sortie() -> Sim:
	var s: Sim = _sim(2)
	_box(s, 42, 46, 22, 25, _code(s, "copper_ore"))
	_box(s, 30, 33, 26, 27, _code(s, "fault_rock"))
	_send(s, "lindqvist", Vector2(22.25, 11.75))
	_run_sortie(s)
	run_seconds(s, 1.0)
	return s


func test_sortie_is_deterministic_and_hashed() -> void:
	var a: Sim = _demo_sortie()
	var b: Sim = _demo_sortie()
	check_eq(a.state_hash(), b.state_hash(), "the same sortie gives the same hash")
	check_gt(float(_count(a, "miner_back")), 0.0, "the sortie came back")
	var h: String = b.state_hash()
	b.drill.miner.strain += 1
	check(b.state_hash() != h, "the miner's state is in the hash")
	b.drill.miner.strain -= 1
	b.ship.crew_by_id("lindqvist").away = true
	check(b.state_hash() != h, "away is in the hash")


func test_replay_of_a_run_with_a_sortie_ends_in_the_same_hash() -> void:
	var d: DataDB = db()
	var r := ScenarioRun.from_scenario(d, "miner_demo", 1)
	r.play_to_end()
	check_eq(_count(r.sim, "miner_out"), 1, "the demo sends a miner")
	check_eq(_count(r.sim, "miner_back"), 1, "and gets them back")
	check(_count(r.sim, "bad_command") == 0, "no refused command")
	var cmds: Array[Dictionary] = r.sim.command_log
	var again: Sim = Sim.replay(d, 1, "light_drill", cmds, r.sim.tick)
	check_eq(again.state_hash(), r.sim.state_hash(), "the replay ends in the same hash")


func test_demo_targets_a_rich_vein_beside_the_path() -> void:
	var r := ScenarioRun.from_scenario(db(), "miner_demo", 1)
	r.play_to_end()
	var back: Dictionary = _last(r.sim, "miner_back")
	var paid: Dictionary = back.get("haul", {})
	var units: int = int(paid.get("ore", 0)) + int(paid.get("gems", 0))
	check_gt(float(units), 15.0, "the demo's vein pays well (got %s)" % str(paid))
	var out: Dictionary = _last(r.sim, "miner_out")
	check_gt(float(out.get("t", 0)), 1.9 * Sim.TICK_HZ, "the miner climbs out after about 2 s")


# Bots ------------------------------------------------------------------------------------------

func test_planner_finds_a_vein_off_the_lane_and_avoids_pockets() -> void:
	var s: Sim = _sim()
	var d: DrillSim = s.drill
	_box(s, 44, 47, 22, 24, _code(s, "copper_ore"))  # 12 cells x 3 ore, about 7 m to the side.
	_box(s, 32, 33, 30, 34, _code(s, "gold_ore"))  # On the drill's own lane: never a miner target.
	var t: Dictionary = MinerPlanner.target(s, d, 1.0, 3.0, 20.0, 3.0)
	check(not t.is_empty(), "a target was found")
	if not t.is_empty():
		var c: int = floori(float(t["x_m"]) / d.cell_m)
		var r: int = floori(float(t["y_m"]) / d.cell_m)
		check(c >= 44 and c <= 47 and r >= 22 and r <= 24, "in the copper vein")
		check_eq(float(t["value"]), 36.0, "valued at its ore")
	check_eq(MinerPlanner.target(s, d, 1.0, 3.0, 40.0, 3.0), {}, "nothing worth 40")
	_box(s, 38, 39, 20, 24, _code(s, "gas_pocket"))  # Across the way there.
	check_eq(MinerPlanner.target(s, d, 1.0, 3.0, 20.0, 3.0), {}, "a tunnel through gas is refused")
	check_eq(MinerPlanner.crew(s, d), "okafor", "the reactor hand goes, not the helm pilot")


## Policy bots on a short copy of the crust layer (five rows of 24 m, like test_bots.gd's).
func test_policy_bots_send_and_always_bring_the_miner_home() -> void:
	var d: DataDB = db()
	var short: Dictionary = (d.table("layers")["crust"] as Dictionary).duplicate(true)
	short["id"] = "miner_test"
	short["rows"] = 5
	short["row_depth_m"] = 24.0
	short["store_rows"] = [2]
	short["min_fights_per_path"] = 1
	short["gate_enemy"] = "rival_light"
	d.table("layers")["miner_test"] = short
	var sorties: int = 0
	for pair: Array in [["balanced", 3], ["greedy", 8]]:
		var bot: String = str(pair[0])
		var p_seed: int = int(pair[1])
		var fr: FullRun = FullRun.start(d, p_seed, bot, {"layer": "miner_test"}, "light_drill", 1800.0)
		fr.play_to_end()
		check(fr.outcome != "stuck", "%s seed %d finished (%s)" % [bot, p_seed, fr.cause])
		var out: int = _count(fr.sim, "miner_out")
		sorties += out
		var ended: int = 0
		for e: Dictionary in fr.sim.events:
			if str(e["kind"]) == "miner_lost" or (str(e["kind"]) == "miner_back" and not bool(e.get("called_off", false))):
				ended += 1
		var still_out: int = 1 if fr.sim.drill.miner.is_out() else 0
		check_eq(ended + still_out, out, "%s seed %d: every miner came back or died" % [bot, p_seed])
		check(still_out == 0 or fr.sim.run.is_over(), "%s seed %d: out only if the run ended" % [bot, p_seed])
	check_gt(float(sorties), 0.0, "the policy bots use the miner")

