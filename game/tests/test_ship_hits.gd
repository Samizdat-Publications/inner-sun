extends TestCase
## Parity round 6a, the view side without a window: where the clicks land on the cutaway (ShipHits),
## the callouts for a purge and an environment, and the environment words on the map.

const PPM: float = 80.0


func _sim() -> Sim:
	return Sim.new(db(), 7, "light_drill", {"mode": "run"})


func test_every_door_and_hatch_is_hit_at_its_centre() -> void:
	var s: Sim = _sim()
	var seen: int = 0
	for l: Link in s.ship.links:
		var rect: Rect2 = ShipHits.hatch_rect(s.ship, l, PPM) if l.kind == Link.Kind.HATCH else ShipHits.door_rect(s.ship, l, PPM)
		var hit: Dictionary = ShipHits.link_at(s.ship, rect.get_center(), PPM)
		check(not hit.is_empty(), "link %s is hit at its centre" % l.id)
		if not hit.is_empty():
			check_eq(int(hit["link"]), l.index, "and it is the right link (%s)" % l.id)
			check_eq(str(hit["what"]), "hatch" if l.kind == Link.Kind.HATCH else "door", "named by kind (%s)" % l.id)
		seen += 1
	check_gt(float(seen), 5.0, "the ship has doors and hatches")
	check(ShipHits.link_at(s.ship, Vector2(-500.0, -500.0), PPM).is_empty(), "far away hits nothing")


func test_a_door_box_is_the_sprite_and_a_hatch_box_a_little_larger() -> void:
	var s: Sim = _sim()
	for l: Link in s.ship.links:
		if l.kind == Link.Kind.DOOR:
			var d: Rect2 = ShipHits.door_rect(s.ship, l, PPM)
			check(absf(d.size.y - l.height_m * PPM) < 0.01, "a door box is as tall as the door")
		else:
			var h: Rect2 = ShipHits.hatch_rect(s.ship, l, PPM)
			var rim: Vector2 = ShipHits.rim_size(l, PPM)
			check(absf(h.size.x - (rim.x + 8.0)) < 0.01, "a hatch box is the rim and a few px")


func test_every_room_has_a_vent_in_a_top_corner_clear_of_the_others() -> void:
	var s: Sim = _sim()
	for r: Room in s.ship.rooms:
		var v: Rect2 = ShipHits.vent_rect(s.ship, r, PPM)
		check_eq(ShipHits.vent_at(s.ship, v.get_center(), PPM), r.index, "the vent of %s is hit at its centre" % r.id)
		var rp := Rect2(r.rect.position * PPM, r.rect.size * PPM)
		check(rp.encloses(v), "%s: the vent is inside its room" % r.id)
		check(v.position.y - rp.position.y < 12.0, "%s: in the top corner" % r.id)
		for l: Link in s.ship.links:
			var box: Rect2 = ShipHits.hatch_rect(s.ship, l, PPM) if l.kind == Link.Kind.HATCH else ShipHits.door_rect(s.ship, l, PPM)
			check(not box.intersects(v), "%s: the vent is clear of %s" % [r.id, l.id])


func test_a_figure_is_hit_on_its_body_and_a_box_takes_what_is_inside() -> void:
	var s: Sim = _sim()
	var a: CrewMember = s.ship.crew[0]
	var b: CrewMember = s.ship.crew[1]
	var bridge: Room = s.ship.rooms[s.ship.room_index("bridge")]
	a.pos = Vector2(bridge.rect.position.x + 1.5, bridge.floor_y())
	b.pos = Vector2(bridge.rect.position.x + 2.6, bridge.floor_y())
	check_eq(ShipHits.crew_at(s.ship, ShipHits.figure_rect(a, PPM).get_center(), PPM), a.id, "a click on the body picks that crew member")
	check_eq(ShipHits.crew_at(s.ship, ShipHits.figure_rect(a, PPM).get_center() + Vector2(120.0, 0.0), PPM), "", "beside them picks nobody")
	var box := Rect2(bridge.rect.position * PPM, Vector2(3.3, 3.0) * PPM)
	var inside: Array[String] = ShipHits.crew_in(s.ship, box, PPM)
	check(a.id in inside and b.id in inside, "a box over two figures takes both")
	check(not s.ship.crew[2].id in inside, "and not the one in another room")
	b.alive = false
	check_eq(ShipHits.crew_at(s.ship, ShipHits.figure_rect(b, PPM).get_center(), PPM), "", "the dead are not picked")
	a.away = true
	check(ShipHits.crew_in(s.ship, box, PPM).is_empty(), "nor is anyone away on a dig")


func test_a_purged_fire_and_an_environment_have_callouts() -> void:
	var s: Sim = _sim()
	var out: Dictionary = DigCallouts.message_for(s, {"kind": "fire_out", "room": "drill", "by": "purge"})
	check_eq(str(out.get("text", "")), "PURGED: DRILL ROOM", "a purge that puts a fire out says so")
	check_eq(str(out.get("kind", "")), "good", "in the good colour")
	var env: Dictionary = DigCallouts.message_for(s, {"kind": "env_entered", "env": "rockfall_seam", "node": "n1"})
	check_eq(str(env.get("text", "")), "ROCKFALL SEAM", "entering an environment names it")
	check(DigCallouts.message_for(s, {"kind": "fire_out", "room": "drill", "by": "water"}).is_empty(), "a fire put out by water says nothing new")


func test_environment_words_wrap_and_name_it() -> void:
	var def: Dictionary = db().table("environments")["magnetite"]
	var words: PackedStringArray = SurveyMarks.env_words(def)
	check_eq(words[0], "ENVIRONMENT: MAGNETITE", "the first line names it")
	check_gt(float(words.size()), 2.0, "the blurb follows in short lines")
	for i: int in range(1, words.size()):
		check(words[i].length() <= 48, "line %d is short enough for the tooltip" % i)
	check(SurveyMarks.env_words({}).is_empty(), "no environment, no words")


func test_a_blind_run_hides_the_rival() -> void:
	var s: Sim = _sim()
	check(not s.run.rival_rooms_hidden(), "normally the rival's rooms show")
	s.run.scanner_blind = true
	check(s.run.rival_rooms_hidden(), "under magnetite they are hidden")
