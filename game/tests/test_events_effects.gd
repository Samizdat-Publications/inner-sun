extends TestCase
## One test per event effect type (docs/STYLE_GUIDE.md): each changes the sim exactly as specified.


var _d: DataDB = null


## A sim whose test event has one option and one outcome with these effects. The outcome goes to a
## page without options (so the world stays frozen while the test looks), unless end_now.
func _with(effects: Array, p_seed: int = 7, mode: String = "run", end_now: bool = false) -> Sim:
	if _d == null:
		_d = db()  # Loaded once per test; the test event is rewritten on every call.
	var d: DataDB = _d
	d.table("events")["t_fx"] = {
		"id": "t_fx", "kind": "event", "layer": "test", "rows": [0, 9], "title": "T", "file": "T",
		"start": "a",
		"pages": {
			"a": {"text": "Test.", "options": [{"text": "Do it.", "outcomes": [{"weight": 1, "effects": effects}]}]},
			"b": {"text": "Done."},
		},
	}
	if not end_now:
		var pages: Dictionary = d.table("events")["t_fx"]["pages"]
		pages["a"]["options"][0]["outcomes"][0]["page"] = "b"
	var s := Sim.new(d, p_seed, "light_drill", {"mode": mode})
	s.encounter.start_event(s, "t_fx")
	return s


func _go(s: Sim) -> void:
	s.push({"type": "choose", "option": 0})
	s.step()


func _count(s: Sim, kind: String) -> int:
	var n: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == kind:
			n += 1
	return n


func test_effect_res() -> void:
	var s: Sim = _with([{"type": "res", "res": "ore", "amount": 8}, {"type": "res", "res": "gems", "amount": -5}], 7, "run", true)
	_go(s)
	check_eq(s.run.get_res("ore"), 18, "ore 10 + 8")
	check_eq(s.run.get_res("gems"), 10, "gems 15 - 5")
	check_eq(s.run.phase, "idle", "an outcome without a page ends the event")


func test_effect_res_range() -> void:
	var seen: Dictionary = {}
	for sd: int in range(1, 41):
		var s: Sim = _with([{"type": "res_range", "res": "gems", "min": 6, "max": 10}], sd)
		_go(s)
		var got: int = s.run.get_res("gems") - 15
		check(got >= 6 and got <= 10, "in range: %d" % got)
		seen[got] = true
		var again: Sim = _with([{"type": "res_range", "res": "gems", "min": 6, "max": 10}], sd)
		_go(again)
		check_eq(again.run.get_res("gems"), s.run.get_res("gems"), "same seed, same roll")
	check_eq(seen.size(), 5, "every value from 6 to 10 comes up")


func test_effect_hull() -> void:
	var s: Sim = _with([{"type": "hull", "amount": -3}])
	_go(s)
	check_eq(s.run.get_res("hull"), s.ship.hull_max - 3, "three hull lost")


func test_effect_crew_damage() -> void:
	var s: Sim = _with([{"type": "crew_damage", "target": "picked", "amount": 25}])
	_go(s)
	check_eq(s.ship.crew[0].hp, 75.0, "the picked crew member takes 25")
	check_eq(s.ship.crew[1].hp, 100.0, "the others do not")
	var all: Sim = _with([{"type": "crew_damage", "target": "all", "amount": 10}])
	_go(all)
	for c: CrewMember in all.ship.crew:
		check_eq(c.hp, 90.0, "all take 10: " + c.id)
	var rnd: Sim = _with([{"type": "crew_damage", "target": "random", "amount": 30}])
	_go(rnd)
	var hurt: int = 0
	for c: CrewMember in rnd.ship.crew:
		if c.hp == 70.0:
			hurt += 1
	check_eq(hurt, 1, "exactly one random crew member is hurt")
	var lethal: Sim = _with([{"type": "crew_damage", "target": "picked", "amount": 150}])
	_go(lethal)
	check(not lethal.ship.crew[0].alive, "enough damage kills")
	check_eq(lethal.ship.crew[0].cause_of_death, "event", "killed by the event")


func test_effect_crew_join_walks_to_station() -> void:
	var s: Sim = _with([{"type": "crew_join", "pool": "survivors"}])
	_go(s)
	check_eq(s.ship.crew.size(), 4, "one crew member joined")
	var c: CrewMember = s.ship.crew[3]
	check(c.id.ends_with("_1"), "a unique id: pool member plus a counter: " + c.id)
	check_eq(s.encounter.joined.size(), 1, "the pool member is recorded")
	check(c.id.begins_with(s.encounter.joined[0]), "the id comes from the pool member")
	check_eq(s.ship.rooms[c.start_room].id, "weapons", "station: the first system room with nobody stationed")
	check_eq(s.ship.rooms[c.room].id, "drill", "they board at the drill room")
	check(has_event(s, "crew_joined"), "crew_joined is emitted")
	_go(s)
	check_eq(s.run.phase, "idle", "the event ended")
	run_seconds(s, 30.0)
	check_eq(s.ship.rooms[c.room].id, "weapons", "they walked to their station")
	check_eq(c.path_i, c.path.size(), "and finished the route")
	check_lt(absf(c.pos.x - room(s, "weapons").center_floor().x), 0.01, "standing at the station")
	var arrived: bool = false
	for e: Dictionary in s.events:
		if str(e["kind"]) == "arrive" and str(e["crew"]) == c.id:
			arrived = true
	check(arrived, "the walk ends with an arrive event")
	# A second joiner: every system room but drill and coolant is taken; drill comes first.
	EventEffects.join(s, s.encounter, "survivors", "ruiz" if s.encounter.joined[0] != "ruiz" else "duarte")
	check_eq(s.ship.crew[4].id.right(2), "_2", "the counter makes ids unique")
	check_eq(s.ship.rooms[s.ship.crew[4].start_room].id, "drill", "the next free station")
	check_eq(EventEffects.roll_member(s, s.encounter, "survivors", "events").is_empty(), false, "four left in the pool")


func test_crew_join_pool_runs_out() -> void:
	var s: Sim = _with([{"type": "crew_join", "pool": "survivors"}])
	for m: String in ["duarte", "kowalczyk", "adeyemi", "sorensen", "takahara", "ruiz"]:
		EventEffects.join(s, s.encounter, "survivors", m)
	check_eq(s.ship.crew.size(), 9, "six joined")
	check_eq(s.ship.rooms[s.ship.crew[8].start_room].id, "reactor", "with every station taken, the room with the fewest (first on ties)")
	_go(s)
	check_eq(s.ship.crew.size(), 9, "nobody is left to join")
	check(has_event(s, "crew_pool_empty"), "and the sim says so")


func test_effect_crew_lose() -> void:
	var s: Sim = _with([{"type": "crew_lose", "target": "picked"}])
	_go(s)
	var c: CrewMember = s.ship.crew[0]
	check(not c.alive, "permadeath")
	check_eq(c.cause_of_death, "event", "cause: event")
	var died: bool = false
	for e: Dictionary in s.events:
		if str(e["kind"]) == "crew_died" and str(e["crew"]) == c.id and str(e["cause"]) == "event":
			died = true
	check(died, "crew_died with cause event")
	var r: Sim = _with([{"type": "crew_lose", "target": "random"}])
	_go(r)
	var dead: int = 0
	for m: CrewMember in r.ship.crew:
		if not m.alive:
			dead += 1
	check_eq(dead, 1, "one random crew member lost")


func test_losing_the_last_crew_ends_the_run() -> void:
	var s: Sim = _with([{"type": "crew_lose", "target": "picked"}])
	EventEffects.kill(s, s.ship.crew[1])
	EventEffects.kill(s, s.ship.crew[2])
	_go(s)
	s.step()
	check_eq(s.run.phase, "dead", "the run is over")
	check_eq(s.run.end_cause, "crew_event", "lost to an event")
	check_eq(s.encounter.event_id, "", "no page is left open")


func test_effect_fight() -> void:
	for mode: String in ["run", "scenario"]:
		var s: Sim = _with([{"type": "fight", "enemy": "rival_light"}], 7, mode)
		_go(s)
		check(not has_event(s, "fight_start"), "the fight waits until the page is read (%s)" % mode)
		_go(s)
		check(has_event(s, "fight_start"), "start_fight was called (%s)" % mode)
		check_eq(s.run.phase, "combat", "the fight takes over (%s)" % mode)
		check(s.enemy != null, "the rival ship is built (%s)" % mode)
		check_eq(s.encounter.pending_fight, "", "nothing left queued")


func test_effect_hazard_fire_breach_heat() -> void:
	var s: Sim = _with([{"type": "hazard", "kind": "fire", "room": "system:drill", "level": 0.4}])
	_go(s)
	check_eq(room(s, "drill").fire, 0.4, "the drill room is on fire")
	check(has_event(s, "fire_started"), "fire_started")
	var b: Sim = _with([{"type": "hazard", "kind": "breach", "room": "random", "level": 0.03}])
	_go(b)
	var holed: int = 0
	for r: Room in b.ship.rooms:
		if r.breach_m2 > 0.0:
			holed += 1
			check_eq(r.breach_m2, 0.03, "a 0.03 m2 breach")
	check_eq(holed, 1, "one random room is breached")
	var h: Sim = _with([{"type": "hazard", "kind": "heat", "room": "system:reactor", "level": 250}])
	var e0: int = room(h, "reactor").energy_j
	var total0: int = h.ship.total_energy_j()
	var in0: int = h.hazards.energy_in_j
	_go(h)
	check_eq(room(h, "reactor").energy_j - e0, 250_000, "250 kJ into the reactor room, exactly")
	check_eq(h.hazards.energy_in_j - in0, 250_000, "and counted in")
	check_eq(h.ship.total_energy_j() - total0, 250_000, "nothing else moved (the world is frozen)")
	_go(h)
	run_seconds(h, 2.0)
	check_eq(h.ship.total_energy_j() - total0, (h.hazards.energy_in_j - h.hazards.energy_out_j) - in0, "the books balance once the world runs")


func test_effect_system_damage() -> void:
	var s: Sim = _with([{"type": "system_damage", "system": "weapons", "bars": 2}])
	_go(s)
	check_eq(room(s, "weapons").sys_damage, 2.0, "two bars broken")
	check_eq(room(s, "weapons").intact_bars(), 1, "one left")
	var over: Sim = _with([{"type": "system_damage", "system": "helm", "bars": 9}])
	_go(over)
	check_eq(room(over, "bridge").sys_damage, 2.0, "never more than the system has")


func test_effect_codex() -> void:
	var s: Sim = _with([{"type": "codex", "id": "mohole"}])
	_go(s)
	check(s.run.knows("mohole"), "learned")
	check_eq(Array(s.run.learned), ["mohole"], "in the run's learned list")
	check_eq(_count(s, "codex"), 1, "one codex event")


func test_effect_pursuer() -> void:
	var s: Sim = _with([{"type": "pursuer", "rows": 0.5}])
	var before: float = s.run.pursuer_row
	_go(s)
	check_eq(s.run.pursuer_row, before + 0.5, "the pursuer moved half a row closer")


func test_effect_reveal() -> void:
	var s: Sim = _with([{"type": "reveal", "rows": 3}])
	_go(s)
	check_eq(s.run.reveal_bonus, 3, "the scanner sees three rows further")


func test_effect_store() -> void:
	var s: Sim = _with([{"type": "store", "store": "crust_trader"}])
	_go(s)
	check_eq(s.run.phase, "dialog", "the outcome page shows first")
	_go(s)
	check_eq(s.run.phase, "store", "the event ends into the store")
	check_eq(s.encounter.store_id, "crust_trader", "the store is open")
	check_eq(s.encounter.event_id, "", "the event is closed")
	s.push({"type": "leave"})
	s.step()
	check_eq(s.run.phase, "idle", "leaving returns to idle")
