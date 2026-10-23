extends TestCase
## Power and ship systems: the reactor budget, automatic power cuts, fire damage and repair, heat
## failure with hysteresis, manning and the helm, bracing layers. Coolant, the enemy world, replays
## and the lint are in test_systems_more.gd.


func _sim(mode: String = "scenario", p_seed: int = 5, overrides: Dictionary = {}) -> Sim:
	return Sim.new(db(overrides), p_seed, "light_drill", {"mode": mode})


func _ri(s: Sim, id: String) -> int:
	return s.ship.room_index(id)


func _kinds(s: Sim, kind: String) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in s.events:
		if str(e["kind"]) == kind:
			out.append(str(e.get("room", "")))
	return out


## Step until the systems have had their next 10 Hz update (it runs on ticks where tick % 6 == 0).
func _update(s: Sim) -> void:
	s.step()
	while (s.tick - 1) % Sim.HAZARD_EVERY != 0:
		s.step()


func _set_temp(s: Sim, id: String, t: float) -> void:
	var r: Room = room(s, id)
	s.hazards.add_heat(r, roundi(t * r.heat_cap_j_per_k) - r.energy_j)


func test_default_allocation_fits_the_reactor() -> void:
	var s: Sim = _sim()
	s.step()
	var sy: Systems = s.systems
	check_eq(sy.reactor_output(s.player), 8, "the reactor makes its 8 bars")
	check_eq(sy.allocated(s.player), 7, "light_drill starts with 7 bars allocated")
	check_eq(sy.free_bars(s.player), 1, "one bar is free")
	check_eq(s.hazards.cooling_scale, 1.0, "two coolant bars give exactly the M0 cooling")
	check_eq(s.hazards.pump_scale, 1.0, "pumps run")
	check(not has_event(s, "power_cut"), "nothing is cut at the start")


func test_power_is_clamped_to_the_reactor() -> void:
	var s: Sim = _sim()
	s.push({"type": "power", "room": "drill", "bars": 4})
	s.step()
	check_eq(room(s, "drill").sys_power, 3, "the drill only gets the one free bar")
	s.push({"type": "power", "room": "weapons", "bars": 3})
	s.step()
	check_eq(room(s, "weapons").sys_power, 0, "a full reactor refuses more power")
	s.push({"type": "power", "room": "reactor", "bars": 2})
	s.push({"type": "power", "room": "nowhere", "bars": 2})
	s.step()
	var refused: int = 0  # Since build 6 a shortfall is refused out loud too ("no free bars").
	for e: Dictionary in s.events:
		if str(e["kind"]) == "bad_command" and str(e.get("why", "")) == "no free bars":
			refused += 1
	check_eq(refused, 2, "the drill's and the weapons' shortfalls are refused with a reason")
	check_eq(_kinds(s, "bad_command").size() - refused, 2, "power to the reactor or a missing room is a bad command")
	s.push({"type": "power", "room": "drill", "bars": 0})
	s.push({"type": "power", "room": "weapons", "bars": 3})
	s.step()
	check_eq(room(s, "weapons").sys_power, 3, "bars freed from the drill can go to weapons")
	check_eq(s.systems.allocated(s.player), 8, "the reactor is now fully used")


func test_reactor_damage_cuts_power_in_priority_order() -> void:
	var s: Sim = _sim()
	s.push({"type": "power", "room": "weapons", "bars": 1})
	s.step()
	var sy: Systems = s.systems
	var reactor: int = _ri(s, "reactor")
	sy.damage_room(s, s.player, reactor, 3.0)  # 8 -> 5 bars: weapons 1 and drill 2 go.
	check_eq(sy.reactor_output(s.player), 5, "three reactor bars broken")
	check_eq(room(s, "weapons").sys_power, 0, "weapons are cut first")
	check_eq(room(s, "drill").sys_power, 0, "then the drill")
	check_eq(room(s, "bracing").sys_power, 2, "bracing keeps its bars")
	sy.damage_room(s, s.player, reactor, 2.0)  # 5 -> 3: bracing goes.
	check_eq(room(s, "bracing").sys_power, 0, "bracing is cut next")
	check_eq(room(s, "bridge").sys_power, 1, "the helm keeps its bar")
	sy.damage_room(s, s.player, reactor, 2.0)  # 3 -> 1: helm, then one coolant bar.
	check_eq(room(s, "bridge").sys_power, 0, "the helm is cut before coolant")
	check_eq(room(s, "coolant").sys_power, 1, "coolant keeps its bars longest")
	check_eq(_kinds(s, "power_cut"), ["weapons", "drill", "bracing", "bridge", "coolant"] as Array[String], "power_cut events name the rooms in priority order")
	check_eq(_kinds(s, "system_damaged").size(), 3, "each hit is a system_damaged event")
	s.ship.rooms[reactor].sys_damage = 0.0
	run_seconds(s, 1.0)
	check_eq(room(s, "drill").sys_power, room(s, "drill").sys_want, "cut bars come back after the repair (remembered allocation)")
	check_eq(sy.allocated(s.player), 8, "every remembered allocation is back, weapons included (8 of 8 bars)")


func test_allocation_never_exceeds_output_under_abuse() -> void:
	var s: Sim = _sim("run", 9)
	var sy: Systems = s.systems
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var ids: Array[String] = ["bridge", "bracing", "reactor", "weapons", "drill", "coolant"]
	for i: int in range(600):
		var pick: int = rng.randi_range(0, 9)
		if pick < 6:
			s.push({"type": "power", "room": ids[pick], "bars": rng.randi_range(-2, 6)})
		elif pick == 6:
			sy.damage_room(s, s.player, rng.randi_range(0, 5), rng.randf_range(0.0, 3.0))
		elif pick == 7:
			s.ship.rooms[rng.randi_range(0, 5)].sys_damage = 0.0
		s.step()
		var ok: bool = sy.allocated(s.player) <= sy.reactor_output(s.player)
		for r: Room in s.ship.rooms:
			ok = ok and r.sys_power >= 0 and (r.system == "reactor" or r.sys_power <= r.intact_bars())
		if not ok:
			failures.append("after step %d the allocation broke the reactor budget (allocated %d, output %d)" % [i, sy.allocated(s.player), sy.reactor_output(s.player)])
			return


func test_fire_damages_the_system_and_crew_repair_it() -> void:
	var s: Sim = _sim("run", 3, {"systems.fire_damage_bars_per_s": 1.0})
	crew_auto_off(s)
	s.push({"type": "ignite", "room": "drill", "level": 0.5})
	run_seconds(s, 9.0)
	var r: Room = room(s, "drill")
	check_gt(r.sys_damage, 0.0, "the fire damaged the drill")
	check_eq(r.intact_bars(), 0, "a long fire wrecks all four bars")
	check_eq(r.sys_power, 0, "broken bars give their power back")
	check_eq(r.effective_bars(), 0, "a wrecked drill gives no bars")
	check(_kinds(s, "system_damaged").has("drill"), "system_damaged was emitted for the drill")
	# Put the fire out (as a dousing would) so this test is about the repair, not the firefight.
	for rr: Room in s.ship.rooms:
		rr.fire = 0.0
	var dmg: float = r.sys_damage
	for c: CrewMember in s.ship.crew:
		s.push({"type": "auto", "crew": c.id, "on": true})
	run_seconds(s, 60.0)
	check_eq(r.sys_damage, 0.0, "the crew repaired the drill (it had %.2f bars of damage)" % dmg)
	check(has_event(s, "system_repaired"), "system_repaired was emitted")
	check_eq(r.sys_power, mini(r.sys_want, r.intact_bars()), "repair hands the remembered power back")
	s.push({"type": "power", "room": "drill", "bars": 2})
	s.step()
	check_eq(r.sys_power, 2, "power can be restored after the repair")
	check_eq(s.systems.drill_bars(s.player), 2, "the drill works again")


func test_heat_failure_has_hysteresis() -> void:
	var s: Sim = _sim()
	crew_auto_off(s)
	s.step()
	var r: Room = room(s, "bridge")
	check_eq(r.effective_bars(), 1, "the helm works at room temperature")
	_set_temp(s, "bridge", 72.0)
	_update(s)
	check(r.sys_failed, "at 72 C (fail 70) the helm fails")
	check_eq(r.effective_bars(), 0, "a failed system gives no bars")
	check(_kinds(s, "system_failed").has("bridge"), "system_failed was emitted")
	_set_temp(s, "bridge", 65.0)
	_update(s)
	check(r.sys_failed, "at 65 C (between recover 60 and fail 70) it stays failed")
	_set_temp(s, "bridge", 58.0)
	_update(s)
	check(not r.sys_failed, "below 60 C it recovers")
	check_eq(r.effective_bars(), 1, "with its bar still allocated")
	check(_kinds(s, "system_recovered").has("bridge"), "system_recovered was emitted")


func test_hot_reactor_limps_at_half() -> void:
	var s: Sim = _sim()
	crew_auto_off(s)
	s.step()
	_set_temp(s, "reactor", 97.0)
	_update(s)
	check_eq(s.systems.reactor_output(s.player), 4, "an overheated reactor limps at half output")
	check_eq(s.systems.allocated(s.player), 4, "allocations are cut to fit")
	check_gt(s.hazards.cooling_scale, 0.0, "and the coolant (highest priority) keeps running")


func test_manning_drives_evasion_and_steering() -> void:
	var s: Sim = _sim()
	run_seconds(s, 1.0)
	var sy: Systems = s.systems
	var bridge: int = _ri(s, "bridge")
	check(sy.is_manned(s.player, bridge), "Vasquez is at the helm at the start")
	# Vasquez runs the helm at station skill 1.3: manned_dodge 0.03 x (1 + 0.75 x 0.3) on top of the bars.
	check_lt(absf(sy.evasion(s.player) - 0.09675), 1e-9, "one helm bar, manned: 6 percent plus her 3.675 percent dodge")
	check_eq(sy.steer_rate_scale(s.player), 1.6, "and faster steering")
	check_lt(absf(sy.side_cut_scale(s.player) - 0.65), 1e-9, "and faster side cutting")
	s.push({"type": "power", "room": "bridge", "bars": 2})
	s.step()
	check_lt(absf(sy.evasion(s.player) - 0.15675), 1e-9, "two bars: 12 percent plus her dodge")
	check_eq(sy.weapon_bonus(s.player), 1.0, "nobody is at the weapons station")
	s.push({"type": "assign", "crew": "vasquez", "room": "weapons"})
	s.step()
	check(not sy.is_manned(s.player, bridge), "the helm is unmanned as soon as she starts walking")
	run_seconds(s, 10.0)
	check(not sy.is_manned(s.player, bridge), "the helm stays unmanned")
	check_eq(sy.evasion(s.player), 0.0, "an unmanned helm gives no evasion")
	check_eq(sy.steer_rate_scale(s.player), 1.0, "and base steering")
	check_eq(sy.side_cut_scale(s.player), 0.35, "and base side cutting")
	check(sy.is_manned(s.player, _ri(s, "weapons")), "she now mans the weapons")
	check_lt(absf(sy.weapon_bonus(s.player) - 1.18375), 1e-9, "a manned weapons station: 15 percent x her skill scale 1.225")
	check_eq(sy.drill_bonus(s.player), 1.0, "the drill room is unmanned")


func test_bracing_layers_absorb_and_recharge() -> void:
	var s: Sim = _sim()
	s.step()
	var sy: Systems = s.systems
	check_eq(sy.bracing_layers(s.player), 1, "two bracing bars hold one layer")
	check(sy.absorb_hit(s, s.player), "the layer absorbs a hit")
	check(not sy.absorb_hit(s, s.player), "the next hit gets through")
	check(has_event(s, "bracing_absorbed"), "bracing_absorbed was emitted")
	# Lindqvist mans the bracing at station skill 0.9: 360 ticks / (1 + 0.15 x 0.925) = 316, counted
	# in hazard steps: back at 318 ticks (5.3 s).
	run_seconds(s, 5.2)
	check_eq(sy.bracing_layers(s.player), 0, "not recharged before 5.3 s")
	run_seconds(s, 0.2)
	check_eq(sy.bracing_layers(s.player), 1, "recharged after 5.3 s")
	# Four bars hold two layers, recharged one at a time.
	room(s, "bracing").sys_max = 4
	s.push({"type": "power", "room": "drill", "bars": 0})
	s.push({"type": "power", "room": "bracing", "bars": 4})
	s.step()
	check_eq(room(s, "bracing").sys_power, 4, "four bars powered")
	check_eq(sy.max_layers(s.player), 2, "max layers follow the bars")
	run_seconds(s, 6.1)
	check_eq(sy.bracing_layers(s.player), 2, "the second layer charged")
	sy.absorb_hit(s, s.player)
	sy.absorb_hit(s, s.player)
	run_seconds(s, 6.2)
	check_eq(sy.bracing_layers(s.player), 1, "one layer back after one recharge time")
	run_seconds(s, 6.0)
	check_eq(sy.bracing_layers(s.player), 2, "both back after two")
	s.push({"type": "power", "room": "bracing", "bars": 1})
	_update(s)
	check_eq(sy.bracing_layers(s.player), 0, "one bar holds no layer: they drop at once")
