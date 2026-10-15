extends TestCase
## Water runs downhill through hatches, collects in the lowest room, and is conserved exactly.


func test_water_runs_down_the_hatch_into_the_lowest_room() -> void:
	var s := Sim.new(db({"water.pump_m3_s": 0.0}), 9, "test_tower")
	crew_auto_off(s)
	s.push({"type": "breach", "room": "reactor", "size_m2": 0.04})
	run_seconds(s, 30.0)
	var drill: Room = room(s, "drill")
	var upper: int = room(s, "bridge").water_ml + room(s, "reactor").water_ml
	check_gt(float(drill.water_ml), 0.0, "water reached the drill room below")
	check_gt(float(drill.water_ml), float(upper), "most of the water collected in the lowest room")
	check_lt(room(s, "bridge").level_m(), 0.25, "the room with the hatch drains and stays shallow")


func test_water_is_conserved_exactly() -> void:
	var s := Sim.new(db(), 9, "test_tower")
	crew_auto_off(s)
	s.push({"type": "breach", "room": "reactor", "size_m2": 0.05})
	run_seconds(s, 90.0)
	var total: int = s.ship.total_water_ml()
	check_eq(total, s.hazards.water_in_ml - s.hazards.water_out_ml, "water in the ship equals what came in minus what was pumped")
	check_gt(float(s.hazards.water_out_ml), 0.0, "the pump removed some water")


func test_full_room_takes_no_more_water() -> void:
	var s := Sim.new(db({"water.pump_m3_s": 0.0}), 9, "test_tower")
	crew_auto_off(s)
	var drill: Room = room(s, "drill")
	drill.water_ml = drill.capacity_ml
	s.push({"type": "breach", "room": "drill", "size_m2": 0.05})
	run_seconds(s, 5.0)
	check_eq(drill.water_ml, drill.capacity_ml, "a full room stays exactly full")
	check(drill.is_full(), "the room reports full")
