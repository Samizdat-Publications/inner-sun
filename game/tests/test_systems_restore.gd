extends TestCase
## Remembered allocations: power comes back after a repair or when the reactor recovers; an overheated
## reactor limps at half output.


func _run_sim(p_seed: int = 5) -> Sim:
	return Sim.new(db(), p_seed, "light_drill", {"mode": "run"})


func test_power_returns_after_repair() -> void:
	var s: Sim = _run_sim()
	var drill: Room = room(s, "drill")
	check_eq(drill.sys_power, 2, "the drill starts with 2 bars")
	s.systems.damage_room(s, s.player, drill.index, 3.0)
	check_eq(drill.sys_power, 1, "damage leaves one intact bar powered")
	check_eq(drill.sys_want, 2, "the chosen allocation is remembered")
	drill.sys_damage = 0.0
	run_seconds(s, 0.5)
	check_eq(drill.sys_power, 2, "after the repair the drill is back at 2 bars")
	var restored: bool = false
	for e: Dictionary in s.events:
		if str(e["kind"]) == "power_restored" and str(e["room"]) == "drill":
			restored = true
	check(restored, "a power_restored event was emitted")


func test_explicit_choice_replaces_the_memory() -> void:
	var s: Sim = _run_sim()
	s.push({"type": "power", "room": "drill", "bars": 0})
	s.step()
	check_eq(room(s, "drill").sys_want, 0, "turning the drill off is remembered as off")
	s.systems.damage_room(s, s.player, room(s, "drill").index, 1.0)
	room(s, "drill").sys_damage = 0.0
	run_seconds(s, 0.5)
	check_eq(room(s, "drill").sys_power, 0, "a repair does not turn it back on")


func test_overheated_reactor_limps_at_half() -> void:
	var s: Sim = _run_sim()
	var reactor: Room = room(s, "reactor")
	var before: int = s.systems.allocated(s.player)
	check_eq(before, 7, "seven bars allocated at the start")
	s.hazards.add_heat(reactor, roundi(reactor.heat_cap_j_per_k * 90.0))
	run_seconds(s, 0.5)
	check(reactor.sys_failed, "the reactor overheated")
	check_eq(s.systems.reactor_output(s.player), 4, "half of 8 bars")
	check_eq(s.systems.allocated(s.player), 4, "allocations were cut to fit")
	check_gt(float(room(s, "coolant").sys_power), 0.0, "coolant keeps power (highest priority)")
	s.hazards.add_heat(reactor, -roundi(reactor.heat_cap_j_per_k * 90.0))
	run_seconds(s, 0.5)
	check(not reactor.sys_failed, "the reactor recovered")
	check_eq(s.systems.allocated(s.player), before, "every remembered allocation came back")
