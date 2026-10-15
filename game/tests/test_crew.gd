extends TestCase
## Crew walk and climb where they are sent, pick sensible jobs, obey orders and handle emergencies.


func test_crew_climbs_down_the_ladder_when_ordered() -> void:
	var s := Sim.new(db(), 1, "test_tower")
	crew_auto_off(s)
	var c: CrewMember = s.ship.crew[0]
	s.push({"type": "assign", "crew": c.id, "room": "drill"})
	var climbed: bool = false
	var arrived_at: float = -1.0
	for i: int in range(900):
		s.step()
		climbed = climbed or c.climbing
		if c.room == s.ship.room_index("drill") and c.path_i >= c.path.size():
			arrived_at = s.seconds()
			break
	check(climbed, "the route used the ladder")
	check_gt(arrived_at, 0.0, "reached the drill room")
	check_lt(arrived_at, 10.0, "within 10 seconds")


func test_auto_crew_goes_to_the_nearer_fire() -> void:
	var s := Sim.new(db(), 1, "test_tower")
	s.push({"type": "ignite", "room": "reactor", "level": 0.3})
	s.push({"type": "ignite", "room": "drill", "level": 0.3})
	run_seconds(s, 0.5)
	var c: CrewMember = s.ship.crew[0]
	check_eq(c.job_kind, "extinguish", "the crew member is fighting fire")
	check_eq(c.job_room, s.ship.room_index("reactor"), "the nearer fire (next door, not down the ladder) comes first")


func test_ordered_crew_stays_where_ordered() -> void:
	var s := Sim.new(db(), 1, "test_tower")
	var c: CrewMember = s.ship.crew[0]
	s.push({"type": "assign", "crew": c.id, "room": "reactor"})
	s.push({"type": "ignite", "room": "drill", "level": 0.3})
	run_seconds(s, 10.0)
	check_eq(c.room, s.ship.room_index("reactor"), "stayed in the ordered room")
	check_gt(room(s, "drill").fire, 0.0, "the fire nobody was sent to is still burning")


func test_auto_crew_handles_fire_and_breach() -> void:
	var s := Sim.new(db(), 4, "test_tower")
	s.push({"type": "ignite", "room": "drill", "level": 0.3})
	s.push({"type": "breach", "room": "reactor", "size_m2": 0.03})
	run_seconds(s, 60.0)
	check_eq(room(s, "drill").fire, 0.0, "the fire is out")
	check_eq(room(s, "reactor").breach_m2, 0.0, "the breach is patched")
	check(has_event(s, "breach_patched"), "a breach_patched event was recorded")
	check(s.ship.crew[0].alive, "the crew member survived")
