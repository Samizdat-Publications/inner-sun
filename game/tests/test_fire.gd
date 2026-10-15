extends TestCase
## Fire spreads if ignored, dies if fought, and water puts it out.


func test_fire_spreads_up_the_hatch_if_ignored() -> void:
	var s := Sim.new(db(), 5, "test_tower")
	crew_auto_off(s)
	s.push({"type": "ignite", "room": "drill", "level": 0.4})
	run_seconds(s, 120.0)
	check_gt(room(s, "bridge").fire, 0.0, "the drill-room fire climbed into the bridge within 120 s")
	check(has_event(s, "fire_spread"), "a fire_spread event was recorded")


func test_fire_dies_if_fought() -> void:
	var s := Sim.new(db(), 5, "test_tower")
	s.push({"type": "ignite", "room": "drill", "level": 0.4})
	run_seconds(s, 45.0)
	check_eq(room(s, "drill").fire, 0.0, "the crew put the drill-room fire out")
	check(has_event(s, "fire_out"), "a fire_out event was recorded")
	check(s.ship.crew[0].alive, "the firefighter survived")


func test_water_puts_fire_out() -> void:
	var s := Sim.new(db(), 5, "test_tower")
	crew_auto_off(s)
	s.push({"type": "ignite", "room": "drill", "level": 0.6})
	s.step()
	var drill: Room = room(s, "drill")
	drill.water_ml = roundi(1.0 * drill.floor_area_m2() * Room.ML_PER_M3)
	run_seconds(s, 10.0)
	check_eq(drill.fire, 0.0, "a meter of water put the fire out")
