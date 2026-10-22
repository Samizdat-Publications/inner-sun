extends TestCase
## Ledger rows L-DOR-01 (closed doors hold fire back; the door command) and L-DOR-02 (purging a room,
## D080). Each band check is a function returning pass or fail, run once with the real tuning and once
## with the row's Wrong value (an in-memory override), which must fail.

const SEED: int = 11
const HEAT_SAFE_MARGIN_C: float = 8.0  ## The row: rock this far above crew.heat_safe_c harms in 10 to 20 s.


# L-DOR-01 ---------------------------------------------------------------------------------------

## Spread exposure from the drill room into coolant and pumps over 5 s, through door_low open or closed.
func _exposure(d: DataDB, closed: bool) -> float:
	var r := ScenarioRun.from_scenario(d, "ledger_doors", SEED)
	if closed:
		r.sim.push({"type": "door", "link": "door_low", "open": false})
	for i: int in range(5 * Sim.TICK_HZ):
		r.step()
	var s: Sim = r.sim
	return s.hazards.spread_exposure(s.ship.room_index("drill"), s.ship.room_index("coolant"))


## Closed rate over open rate for the same door, every path summed (so a parallel wall path would show).
func _door_ratio(d: DataDB) -> float:
	var open_e: float = _exposure(d, false)
	return _exposure(d, true) / maxf(open_e, 1e-9)


func _door_band_ok(d: DataDB) -> bool:
	var ratio: float = _door_ratio(d)
	return ratio >= 0.30 and ratio <= 0.50


func test_l_dor_01() -> void:
	var ratio: float = _door_ratio(db())
	check(_door_band_ok(db()), "a closed door passes fire at 30 to 50%% of its open rate (got %.3f)" % ratio)
	check(not _door_band_ok(db({"fire.spread_closed_factor": 1.0})), "Wrong value: closed spread equal to open must fail the band")

	# One fire path per linked pair (the shared wall is not a second path); wall-only pairs keep theirs.
	var s := Sim.new(db(), SEED, "light_drill")
	for l: Link in s.ship.links:
		check_eq(s.hazards.fire_paths(l.a, l.b), 1, "one fire path %s a to b" % l.id)
		check_eq(s.hazards.fire_paths(l.b, l.a), 1, "one fire path %s b to a" % l.id)
	var t := Sim.new(db(), SEED, "test_tower")
	check_eq(t.hazards.fire_paths(t.ship.room_index("reactor"), t.ship.room_index("drill")), 1, "rooms that touch without a link keep the wall path")

	# Hatches: closed passes the same share of the hatch's own (upward) open rate.
	var up_open := _hatch_exposure(db(), false)
	var up_closed := _hatch_exposure(db(), true)
	var hr: float = up_closed / maxf(up_open, 1e-9)
	print("    closed/open fire spread: door %.3f, hatch upward %.3f" % [ratio, hr])
	check(hr >= 0.30 and hr <= 0.50, "a closed hatch passes 30 to 50%% of its open upward rate (got %.3f)" % hr)

	_crew_cross_closed_door()
	_door_command_rules()
	_door_works_paused()
	_door_replays()


func _hatch_exposure(d: DataDB, closed: bool) -> float:
	var r := ScenarioRun.from_scenario(d, "ledger_doors", SEED)
	if closed:
		r.sim.push({"type": "door", "link": "hatch_reactor_drill", "open": false})
	for i: int in range(5 * Sim.TICK_HZ):
		r.step()
	var s: Sim = r.sim
	return s.hazards.spread_exposure(s.ship.room_index("drill"), s.ship.room_index("reactor"))


func _crew_cross_closed_door() -> void:
	var s := Sim.new(db(), SEED, "light_drill")
	for l: Link in s.ship.links:  # Every route is shut, so any way there crosses a closed link.
		s.push({"type": "door", "link": l.id, "open": false})
	s.push({"type": "assign", "crew": "vasquez", "room": "bracing"})
	var crossed: bool = false
	var stayed_closed: bool = true
	for i: int in range(15 * Sim.TICK_HZ):
		s.step()
		if s.ship.crew_by_id("vasquez").room == s.ship.room_index("bracing"):
			crossed = true
		for l: Link in s.ship.links:
			if l.open:
				stayed_closed = false
	check(crossed, "crew walked from the bridge through the closed door into bracing")
	check(stayed_closed, "every link stayed closed for hazards while crew walked through")


func _link(s: Sim, link_id: String) -> Link:
	for l: Link in s.ship.links:
		if l.id == link_id:
			return l
	return null


func _last_event(s: Sim, kind: String) -> Dictionary:
	for i: int in range(s.events.size() - 1, -1, -1):
		if str(s.events[i]["kind"]) == kind:
			return s.events[i]
	return {}


func _door_command_rules() -> void:
	var s := Sim.new(db(), SEED, "light_drill")
	s.push({"type": "door", "link": "no_such_door", "open": false})
	s.step()
	var bad: Dictionary = _last_event(s, "bad_command")
	check(str(bad.get("type", "")) == "door" and str(bad.get("why", "")) == "no such link", "a missing link is refused with a reason (%s)" % str(bad))
	s.push({"type": "door", "link": "door_mid", "open": true})
	s.step()
	bad = _last_event(s, "bad_command")
	check(str(bad.get("why", "")) == "already open" and int(bad["t"]) == s.tick - 1, "opening an open door is refused (%s)" % str(bad))
	check(not has_event(s, "door"), "refused commands emit no door event")
	s.push({"type": "door", "link": "door_mid", "open": false})
	s.step()
	var ev: Dictionary = _last_event(s, "door")
	check(str(ev.get("link", "")) == "door_mid" and ev.get("open", true) == false, "a change emits door {link, open} (%s)" % str(ev))
	check(not _link(s, "door_mid").open, "door_mid is closed")


func _door_works_paused() -> void:
	var s := Sim.new(db(), SEED, "light_drill")
	s.run.phase = "dialog"  # A dossier is open: the world does not run, commands still apply.
	check(not s.run.world_running(), "the world is held in a dossier")
	s.push({"type": "door", "link": "hatch_bridge_reactor", "open": false})
	check(_link(s, "hatch_bridge_reactor").open, "a command pushed while paused waits for the next step")
	s.step()
	check(not _link(s, "hatch_bridge_reactor").open, "the door command applied while the world was held")
	check(has_event(s, "door"), "and emitted its door event")


func _door_replays() -> void:
	var s := Sim.new(db(), SEED, "light_drill")
	crew_auto_off(s)
	s.push({"type": "ignite", "room": "reactor", "level": 0.8})
	run_seconds(s, 2.0)
	s.push({"type": "door", "link": "door_mid", "open": false})
	run_seconds(s, 3.0)
	s.push({"type": "purge", "room": "reactor", "open": true})
	run_seconds(s, 3.0)
	s.push({"type": "purge", "room": "reactor", "open": false})
	s.push({"type": "door", "link": "door_mid", "open": true})
	run_seconds(s, 4.0)
	var again: Sim = Sim.replay(db(), SEED, s.ship_id, s.command_log, s.tick)
	check_eq(again.state_hash(), s.state_hash(), "a replay of door and purge commands gives the same hash")


# L-DOR-02 ---------------------------------------------------------------------------------------

## Seconds from the purge opening until the drill-room fire is out (-1 if it never goes out in 30 s).
func _purge_out_s(d: DataDB, neighbour_burns: bool) -> float:
	var r := ScenarioRun.from_scenario(d, "ledger_purge", SEED)
	if neighbour_burns:
		r.sim.push({"type": "ignite", "room": "coolant", "level": 1.0})
	var opened_t: int = -1
	for i: int in range(40 * Sim.TICK_HZ):
		r.step()
		for k: int in range(r.sim.events.size() - 1, -1, -1):
			var e: Dictionary = r.sim.events[k]
			if int(e["t"]) < r.sim.tick - 1:
				break
			if str(e["kind"]) == "purge" and opened_t < 0:
				opened_t = int(e["t"])
			if str(e["kind"]) == "fire_out" and str(e["room"]) == "drill" and opened_t >= 0:
				check_eq(str(e["by"]), "purge", "the purge put the fire out")
				return float(int(e["t"]) - opened_t) / Sim.TICK_HZ
	return -1.0


func _purge_fire_ok(d: DataDB) -> bool:
	var alone: float = _purge_out_s(d, false)
	var with_n: float = _purge_out_s(d, true)
	return alone >= 3.0 and alone <= 6.0 and with_n >= 6.0 and with_n <= 12.0


## Seconds until a purged room starting at its design temperature reaches crew-harm heat (-1: never
## within 60 s), the coolant at its normal bars.
func _purge_harm_s(d: DataDB, room_id: String, doors_closed: bool, rock_c: float) -> float:
	var s := Sim.new(d, SEED, "light_drill")
	s.ship.rock_temp_c = rock_c
	crew_auto_off(s)
	if doors_closed:
		for l: Link in s.ship.links:
			s.push({"type": "door", "link": l.id, "open": false})
	s.push({"type": "purge", "room": room_id, "open": true})
	var safe: float = d.tune("crew.heat_safe_c")
	var r: Room = room(s, room_id)
	for i: int in range(60 * Sim.TICK_HZ):
		s.step()
		if r.temp_c() >= safe:
			return float(s.tick - 1) / Sim.TICK_HZ
	return -1.0


func _purge_heat_ok(d: DataDB, verbose: bool = false) -> bool:
	var ok: bool = true
	var hot: float = d.tune("crew.heat_safe_c") + HEAT_SAFE_MARGIN_C
	var s := Sim.new(d, SEED, "light_drill")
	for rm: Room in s.ship.rooms:
		for closed: bool in [false, true]:
			var t: float = _purge_harm_s(d, rm.id, closed, hot)
			if verbose:
				print("    purge harm %s doors %s: %.2f s" % [rm.id, "closed" if closed else "open", t])
			if t < 10.0 or t > 20.0:
				ok = false
		if _purge_harm_s(d, rm.id, false, 46.0) >= 0.0:
			ok = false
	return ok


func test_l_dor_02() -> void:
	var alone: float = _purge_out_s(db(), false)
	var with_n: float = _purge_out_s(db(), true)
	print("    purge fire out: alone %.2f s, linked neighbour burning %.2f s" % [alone, with_n])
	check(alone >= 3.0 and alone <= 6.0, "a full fire alone in a purged room is out in 3 to 6 s (got %.2f)" % alone)
	check(with_n >= 6.0 and with_n <= 12.0, "with a linked neighbour burning, out in 6 to 12 s (got %.2f)" % with_n)
	check(_purge_fire_ok(db()), "fire band passes")
	check(not _purge_fire_ok(db({"fire.purge_out_per_s": 0.0})), "Wrong value: a purge that leaves the fire burning must fail")

	check(_purge_heat_ok(db(), true), "every purged room reaches crew-harm heat in 10 to 20 s at rock +8 C, doors open and closed, and never at rock 46 C")
	check(not _purge_heat_ok(db({"heat.purge_kw_per_k": 0.0})), "Wrong value: a purge with no heat inflow must fail the heat clause")

	_purge_conserves_energy()
	_no_fire_into_purged_room()
	_purge_command_rules()


func _purge_conserves_energy() -> void:
	var s := Sim.new(db(), SEED, "light_drill")
	s.ship.rock_temp_c = 70.0
	crew_auto_off(s)
	var e0: int = s.ship.total_energy_j()
	s.push({"type": "ignite", "room": "drill", "level": 1.0})
	s.push({"type": "door", "link": "door_low", "open": false})
	s.push({"type": "purge", "room": "drill", "open": true})
	s.push({"type": "purge", "room": "bridge", "open": true})
	run_seconds(s, 20.0)
	s.push({"type": "purge", "room": "drill", "open": false})
	run_seconds(s, 20.0)
	var gained: int = s.ship.total_energy_j() - e0
	check_eq(gained, s.hazards.energy_in_j - s.hazards.energy_out_j, "with purges, room energy changed by exactly what entered minus what left")


## Coolant and pumps sits next to a full drill-room fire through an open door, with the rock hot enough
## to autoignite it. Unpurged it catches; purged it never does, and no exposure builds up into it.
func _coolant_catches(purged: bool) -> bool:
	var s := Sim.new(db(), SEED, "light_drill")
	s.ship.rock_temp_c = 160.0
	s.hazards.coolant_on = false
	crew_auto_off(s)
	s.push({"type": "ignite", "room": "drill", "level": 1.0})
	if purged:
		s.push({"type": "purge", "room": "coolant", "open": true})
	var c: int = s.ship.room_index("coolant")
	var caught: bool = false
	for i: int in range(60 * Sim.TICK_HZ):
		s.step()
		if purged and i == 30:
			s.push({"type": "ignite", "room": "coolant", "level": 0.5})  # A hit or strike: no effect.
		if s.ship.rooms[c].fire > 0.0:
			caught = true
		if purged and s.hazards.spread_exposure(s.ship.room_index("drill"), c) != 0.0:
			check(false, "no spread exposure builds into a purged room")
			return true
	if purged:
		check(s.ship.rooms[c].temp_c() > 100.0, "the purged room was hot enough to autoignite (%.1f C)" % s.ship.rooms[c].temp_c())
	return caught


func _no_fire_into_purged_room() -> void:
	check(_coolant_catches(false), "control: an unpurged neighbour catches fire")
	check(not _coolant_catches(true), "a purged room never starts or catches a fire")


func _purge_command_rules() -> void:
	var s := Sim.new(db(), SEED, "light_drill")
	s.push({"type": "purge", "room": "attic", "open": true})
	s.step()
	check_eq(str(_last_event(s, "bad_command").get("why", "")), "no such room", "a purge of a missing room is refused")
	s.push({"type": "purge", "room": "bridge", "open": false})
	s.step()
	check_eq(str(_last_event(s, "bad_command").get("why", "")), "already closed", "closing a closed purge is refused")
	s.push({"type": "purge", "room": "bridge", "open": true})
	s.step()
	var ev: Dictionary = _last_event(s, "purge")
	check(str(ev.get("room", "")) == "bridge" and ev.get("open", false) == true, "a purge emits purge {room, open} (%s)" % str(ev))
	check(s.hazards.is_purged(s.ship.room_index("bridge")), "the bridge purge is open")
	var h0: String = s.state_hash()
	var s2 := Sim.new(db(), SEED, "light_drill")
	s2.push({"type": "purge", "room": "attic", "open": true})
	s2.step()
	s2.push({"type": "purge", "room": "bridge", "open": false})
	s2.step()
	s2.push({"type": "purge", "room": "reactor", "open": true})
	s2.step()
	check(h0 != s2.state_hash(), "the purge state is part of the world hash")
