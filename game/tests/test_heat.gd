extends TestCase
## Heat behaves as designed: it rises through hatches, coolant fights it, and energy is conserved
## exactly (every joule that leaves a room arrives in another, or is counted entering or leaving).


func _energy_into(cool_id: String, hot_id: String) -> int:
	var s := Sim.new(db({"heat.hull_kw_per_m2_k": 0.0}), 1, "test_tower")
	s.hazards.coolant_on = false
	room(s, hot_id).set_temp_c(150.0)
	var e0: int = room(s, cool_id).energy_j
	run_seconds(s, 20.0)
	return room(s, cool_id).energy_j - e0


func test_heat_rises_through_the_hatch() -> void:
	var upward: int = _energy_into("bridge", "drill")
	var downward: int = _energy_into("drill", "bridge")
	check_gt(float(upward), 0.0, "a hot lower room warms the room above")
	check_gt(float(upward), 3.0 * float(downward), "heat moves up a hatch much more than down (up %d J, down %d J)" % [upward, downward])


func test_energy_is_conserved_exactly() -> void:
	var s := Sim.new(db(), 3, "test_tower")
	var e0: int = s.ship.total_energy_j()
	s.push({"type": "ignite", "room": "drill", "level": 0.5})
	s.push({"type": "breach", "room": "reactor", "size_m2": 0.03})
	run_seconds(s, 60.0)
	var gained: int = s.ship.total_energy_j() - e0
	check_eq(gained, s.hazards.energy_in_j - s.hazards.energy_out_j, "room energy changed by exactly what entered minus what left")


func test_coolant_keeps_rooms_cooler() -> void:
	var with_cool := Sim.new(db(), 2, "test_tower")
	var without := Sim.new(db(), 2, "test_tower")
	without.hazards.coolant_on = false
	run_seconds(with_cool, 120.0)
	run_seconds(without, 120.0)
	var a: float = room(with_cool, "bridge").temp_c()
	var b: float = room(without, "bridge").temp_c()
	check_gt(b - a, 4.0, "coolant holds the bridge well below the rock heat (with %.1f C, without %.1f C)" % [a, b])
