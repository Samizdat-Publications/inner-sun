extends TestCase
## The M1 skeleton: phases, module dispatch, run resources, death, the repair job, the conservation
## entry points, run-mode replays and per-side random streams (docs/ARCHITECTURE.md).


func _run_sim(p_seed: int = 7) -> Sim:
	return Sim.new(db(), p_seed, "light_drill", {"mode": "run"})


func test_run_mode_starts_idle_with_ship_resources() -> void:
	var s: Sim = _run_sim()
	check_eq(s.run.phase, "idle", "a run starts at its first node, idle")
	check_eq(s.run.get_res("hull"), s.ship.hull_max, "hull starts full")
	check_eq(s.run.get_res("cells"), 8, "power cells come from the ship's start_resources")
	var scen := Sim.new(db(), 7, "light_drill")
	check_eq(scen.run.phase, "scenario", "without options the sim runs a scenario")


func test_frozen_phase_stops_the_world() -> void:
	var s: Sim = _run_sim()
	s.push({"type": "ignite", "room": "drill", "level": 0.4})
	s.step()
	s.run.set_phase(s, "dialog")
	var fire: float = room(s, "drill").fire
	var e0: int = s.ship.total_energy_j()
	var pos: Vector2 = s.ship.crew[0].pos
	run_seconds(s, 5.0)
	check_eq(room(s, "drill").fire, fire, "fire does not grow while a dialog is open")
	check_eq(s.ship.total_energy_j(), e0, "no heat moves while frozen")
	check_eq(s.ship.crew[0].pos, pos, "crew stand still while frozen")
	check_eq(s.tick, 301, "the tick still advances (commands stay ordered)")
	s.run.set_phase(s, "idle")
	run_seconds(s, 2.0)
	check(room(s, "drill").fire != fire, "the world resumes in idle")


func test_module_dispatch_and_known_commands() -> void:
	var s: Sim = _run_sim()
	s.push({"type": "power", "room": "bridge", "bars": 0})  # Free reactor bars so only capacity limits the drill.
	s.push({"type": "power", "room": "drill", "bars": 99})
	s.step()
	check_eq(room(s, "drill").sys_power, room(s, "drill").sys_max, "power goes to Systems and clamps to capacity")
	var known: PackedStringArray = Sim.known_commands()
	for kind: String in ["assign", "power", "steer", "target", "choose", "buy", "leave"]:
		check(known.has(kind), "known commands include " + kind)
	var seen: Dictionary = {}
	for kind: String in known:
		check(not seen.has(kind), "command type declared once: " + kind)
		seen[kind] = true


func test_resources_clamp_and_emit() -> void:
	var s: Sim = _run_sim()
	var before: int = s.events.size()
	check_eq(s.run.add(s, "ore", 5), 5, "adds ore")
	check_eq(s.run.add(s, "ore", -1000), -15, "never below zero")
	check_eq(s.run.add(s, "hull", 50), 0, "hull never above the ship's maximum")
	check_eq(s.events.size(), before + 2, "each real change is one event")
	check_eq(str(s.events[before]["kind"]), "resource", "the event is a resource event")


func test_hull_zero_ends_the_run() -> void:
	var s: Sim = _run_sim()
	s.run.add(s, "hull", -s.ship.hull_max)
	s.step()
	check_eq(s.run.phase, "dead", "the run is over")
	check_eq(s.run.end_cause, "hull", "killed by hull loss")
	var t: int = s.tick
	var hash_dead: String = s.state_hash()
	run_seconds(s, 1.0)
	check_eq(s.tick, t + 60, "ticks keep counting")
	check(s.state_hash() != hash_dead, "only the tick changed")
	check_eq(s.run.phase, "dead", "stays dead")


func test_crew_repair_damaged_system() -> void:
	var s: Sim = _run_sim(3)
	var r: Room = room(s, "weapons")
	r.sys_damage = 2.0
	check_eq(r.intact_bars(), 1, "two of three bars are broken")
	run_seconds(s, 40.0)
	check_eq(r.sys_damage, 0.0, "the crew repaired the weapons system on their own")
	var fixed: bool = false
	for e: Dictionary in s.events:
		if str(e["kind"]) == "system_repaired":
			fixed = true
	check(fixed, "a system_repaired event was emitted")


func test_add_heat_and_water_keep_the_books() -> void:
	var s: Sim = _run_sim()
	var h: HazardSim = s.hazards
	var e0: int = s.ship.total_energy_j()
	var in0: int = h.energy_in_j - h.energy_out_j
	h.add_heat(room(s, "drill"), 5_000_000)
	h.add_heat(room(s, "bridge"), -1_250_000)
	run_seconds(s, 3.0)
	check_eq(s.ship.total_energy_j() - e0, (h.energy_in_j - h.energy_out_j) - in0, "heat added from outside is counted exactly")
	var r: Room = room(s, "coolant")
	var put: int = h.add_water(r, r.capacity_ml * 2)
	check_eq(put, r.capacity_ml, "water from outside is clamped to the room")
	check_eq(h.water_in_ml, put, "and counted")


func test_run_mode_replay_matches() -> void:
	var opts: Dictionary = {"mode": "run", "known_codex": ["kola_well", "byrd_1947"]}
	var s := Sim.new(db(), 11, "light_drill", opts)
	s.push({"type": "ignite", "room": "weapons", "level": 0.3})
	run_seconds(s, 2.0)
	s.push({"type": "power", "room": "coolant", "bars": 3})
	s.push({"type": "assign", "crew": "okafor", "room": "weapons"})
	run_seconds(s, 6.0)
	var again: Sim = Sim.replay(db(), 11, "light_drill", s.command_log, s.tick, opts)
	check_eq(again.state_hash(), s.state_hash(), "seed, options and command log rebuild the same run")
	check(again.run.knows("byrd_1947"), "the known codex is part of the run")
	check_eq(Array(again.run.known_codex), ["byrd_1947", "kola_well"], "the known codex is kept sorted")


func test_enemy_world_has_its_own_streams() -> void:
	var s: Sim = _run_sim()
	var foe := ShipWorld.new(s.db, s.db.ships["light_drill"], "enemy")
	check_eq(foe.stream_name("fire"), "enemy/fire", "enemy streams are prefixed")
	check_eq(s.player.stream_name("fire"), "fire", "player streams keep their names")
	s.enemy = foe
	foe.hazards.ignite(s, foe, foe.ship.rooms[0], 0.3)
	var last: Dictionary = s.events[s.events.size() - 1]
	check_eq(str(last.get("side", "")), "enemy", "enemy events are tagged with their side")
	s.run.set_phase(s, "combat")
	run_seconds(s, 2.0)
	check(foe.ship.rooms[0].fire != 0.3, "the enemy ship's world runs (its fire changed: the enemy crew fight it)")
	check_eq(room(s, "bridge").fire, 0.0, "and it does not touch the player's ship")
