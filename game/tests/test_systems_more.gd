extends TestCase
## Systems, continued: coolant bars and pumps, the exact coolant bill in run mode, the enemy world,
## replays, the lint, and energy conservation with the systems running.


func _sim(mode: String = "scenario", p_seed: int = 5, overrides: Dictionary = {}) -> Sim:
	return Sim.new(db(overrides), p_seed, "light_drill", {"mode": mode})


func _set_temp(s: Sim, id: String, t: float) -> void:
	var r: Room = room(s, id)
	s.hazards.add_heat(r, roundi(t * r.heat_cap_j_per_k) - r.energy_j)


## Bridge temperature after 20 s from 60 C with the given coolant bars.
func _bridge_after(bars: int) -> float:
	var s: Sim = _sim()
	crew_auto_off(s)
	s.push({"type": "power", "room": "coolant", "bars": bars})
	s.step()
	_set_temp(s, "bridge", 60.0)
	run_seconds(s, 20.0)
	return room(s, "bridge").temp_c()


func test_coolant_bars_set_the_cooling() -> void:
	var t0: float = _bridge_after(0)
	var t2: float = _bridge_after(2)
	var t3: float = _bridge_after(3)
	check_gt(t0 - t2, 3.0, "with 0 coolant bars the room stays hotter than with 2 (%.2f C vs %.2f C)" % [t0, t2])
	check_gt(t2 - t3, 1.5, "with 3 bars it cools faster than with 2 (%.2f C vs %.2f C)" % [t2, t3])


func test_pumps_stop_without_coolant_power() -> void:
	var out_ml: Array[int] = []
	for bars: int in [0, 2]:
		var s: Sim = _sim()
		crew_auto_off(s)
		s.push({"type": "power", "room": "coolant", "bars": bars})
		s.step()
		check_eq(s.hazards.pump_scale, 1.0 if bars > 0 else 0.0, "pump_scale with %d coolant bars" % bars)
		s.hazards.add_water(room(s, "drill"), 2_000_000)
		run_seconds(s, 10.0)
		out_ml.append(s.hazards.water_out_ml)
	check_eq(out_ml[0], 0, "no water is pumped out with 0 coolant bars")
	check_gt(float(out_ml[1]), 0.0, "pumps run with 2 bars")


func test_run_mode_bills_coolant_exactly() -> void:
	var per: int = 40_000
	var s: Sim = _sim("run", 4, {"systems.coolant_j_per_unit": per})
	var start: int = s.run.get_res("coolant")
	check_eq(start, 20, "light_drill starts with 20 coolant units")
	for id: String in ["bridge", "bracing", "reactor", "weapons", "drill", "coolant"]:
		_set_temp(s, id, 45.0)
	var sy: Systems = s.systems
	run_seconds(s, 10.0)
	var used: int = start - s.run.get_res("coolant")
	check_gt(float(used), 0.0, "cooling used coolant")
	check_eq(sy.coolant_units_used(s.player), used, "units billed match the resource change")
	check_eq(used * per + sy.coolant_carry_j(s.player), s.hazards.cooled_j, "units * j_per_unit + remainder == joules the coolant removed")
	check_lt(float(sy.coolant_carry_j(s.player)), float(per), "the remainder is less than one unit while coolant lasts")
	var guard: int = 0
	while s.run.get_res("coolant") > 0 and guard < 600:
		run_seconds(s, 1.0)
		guard += 1
	check_eq(s.run.get_res("coolant"), 0, "the coolant ran out")
	run_seconds(s, 0.2)
	check(has_event(s, "coolant_empty"), "coolant_empty was emitted")
	check_eq(s.hazards.cooling_scale, 0.0, "cooling stops at 0 units")
	var cooled: int = s.hazards.cooled_j
	run_seconds(s, 5.0)
	check_eq(s.hazards.cooled_j, cooled, "no joule is cooled without coolant")
	check_eq(start * per + sy.coolant_carry_j(s.player), s.hazards.cooled_j, "the books still balance exactly at empty")
	var empties: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == "coolant_empty":
			empties += 1
	check_eq(empties, 1, "coolant_empty is emitted once")
	s.run.add(s, "coolant", 3)
	run_seconds(s, 2.0)
	check_gt(float(s.hazards.cooled_j), float(cooled), "restocked coolant cools again")


func test_scenario_mode_uses_no_coolant() -> void:
	var s: Sim = _sim("scenario", 4, {"systems.coolant_j_per_unit": 1000})
	run_seconds(s, 20.0)
	check_gt(float(s.hazards.cooled_j), 0.0, "the coolant worked")
	check_eq(s.systems.coolant_units_used(s.player), 0, "nothing was billed")
	check_eq(s.run.get_res("coolant"), 0, "the scenario has no coolant resource and does not need one")
	check_eq(s.hazards.cooling_scale, 1.0, "cooling stays at full")


func test_energy_still_conserved_with_systems() -> void:
	var s: Sim = _sim("run", 8, {"systems.coolant_j_per_unit": 200_000})
	var e0: int = s.ship.total_energy_j()
	s.push({"type": "ignite", "room": "weapons", "level": 0.5})
	s.push({"type": "power", "room": "coolant", "bars": 3})
	run_seconds(s, 60.0)
	check_eq(s.ship.total_energy_j() - e0, s.hazards.energy_in_j - s.hazards.energy_out_j, "room energy changed by exactly what entered minus what left")


func test_enemy_world_runs_the_same_and_apart() -> void:
	var s: Sim = _sim()
	var foe := ShipWorld.new(s.db, s.db.ships["light_drill"], "enemy")
	s.enemy = foe
	s.run.set_phase(s, "combat")
	s.step()
	var sy: Systems = s.systems
	check_eq(sy.reactor_output(foe), 8, "the enemy reactor runs")
	check_eq(sy.bracing_layers(foe), 1, "the enemy has its own bracing layer")
	sy.damage_room(s, foe, foe.ship.room_index("reactor"), 4.0)
	check_eq(sy.allocated(foe), 4, "the enemy's power was cut to its reactor")
	check_eq(foe.ship.rooms[foe.ship.room_index("weapons")].sys_power, 0, "enemy cuts follow the same order")
	check_eq(sy.allocated(s.player), 7, "the player's power is untouched")
	var tagged: bool = false
	for e: Dictionary in s.events:
		if str(e["kind"]) == "power_cut":
			check_eq(str(e.get("side", "")), "enemy", "enemy power cuts are tagged with the side")
			tagged = true
	check(tagged, "the enemy had power cuts")
	check(sy.absorb_hit(s, foe), "the enemy bracing absorbs a hit")
	check_eq(sy.bracing_layers(foe), 0, "the enemy layer is spent")
	check_eq(sy.bracing_layers(s.player), 1, "the player's layer is not")
	foe.hazards.ignite(s, foe, foe.ship.rooms[foe.ship.room_index("drill")], 0.8)
	run_seconds(s, 3.0)
	check_gt(foe.ship.rooms[foe.ship.room_index("drill")].sys_damage, 0.0, "fire damages enemy systems")
	check_eq(room(s, "drill").sys_damage, 0.0, "and not the player's")
	var st: Array = sy.state()
	var enemy_state: Array = st[1]
	check_eq(enemy_state.size(), 6, "systems state lists the enemy side")
	s.enemy = null
	s.run.set_phase(s, "idle")
	s.step()
	st = sy.state()
	check_eq(st[1], [], "the enemy side is dropped after the fight")
	var foe2 := ShipWorld.new(s.db, s.db.ships["light_drill"], "enemy")
	s.enemy = foe2
	check_eq(sy.bracing_layers(foe2), 1, "a new enemy ship starts fresh")


func test_replay_matches_with_systems() -> void:
	var opts: Dictionary = {"mode": "run"}
	var s := Sim.new(db({"systems.coolant_j_per_unit": 300_000}), 21, "light_drill", opts)
	s.push({"type": "ignite", "room": "reactor", "level": 0.5})
	s.push({"type": "power", "room": "weapons", "bars": 1})
	run_seconds(s, 8.0)
	s.push({"type": "power", "room": "drill", "bars": 0})
	s.push({"type": "power", "room": "bracing", "bars": 1})
	s.push({"type": "assign", "crew": "vasquez", "room": "coolant"})
	run_seconds(s, 12.0)
	check(has_event(s, "system_damaged"), "the run had system damage")
	var again: Sim = Sim.replay(db({"systems.coolant_j_per_unit": 300_000}), 21, "light_drill", s.command_log, s.tick, opts)
	check_eq(again.state_hash(), s.state_hash(), "seed, options and command log rebuild the same run")
	check_eq(again.systems.state(), s.systems.state(), "including the systems state")


func test_lint_catches_bad_system_data() -> void:
	var d: DataDB = db()
	var errs := PackedStringArray()
	Systems.lint(d, errs)
	check(errs.is_empty(), "real systems data lints clean: " + " | ".join(errs))
	var sys: Dictionary = d.tables["systems"]
	var helm: Dictionary = sys["helm"]
	helm["fail_c"] = 50.0
	helm["needs_crew"] = "yes"
	sys.erase("coolant")
	d.tuning.erase("systems.evasion_per_bar")
	errs = PackedStringArray()
	Systems.lint(d, errs)
	var all: String = "\n".join(errs)
	check(all.contains("must be above recover_c"), "fail_c below recover_c is caught")
	check(all.contains("needs_crew"), "a wrong type is caught")
	check(all.contains("coolant.json"), "a room system without a systems file is caught")
	check(all.contains("systems.evasion_per_bar"), "a missing tuning number is caught")
