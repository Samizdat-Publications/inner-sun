extends TestCase
## Behavior ledger rows L-MAN-01 to L-MAN-03 (docs/research/behavior-ledger.md): manned stations and
## the station skill. Each band check is a function that returns its failures, so the same check runs
## on the real rules (it must pass) and on the row's wrong values (it must fail). Wrong values are
## applied to the DataDB before Sim.new, because Systems caches its tuning and definitions.
##
## Scenario ledger_manning gives the ship, the power layout (weapons on one bar, so every station is
## powered) and the measuring window (its duration, 600 ticks).

const SCENARIO: String = "ledger_manning"
const WALK_TICKS: int = 300  ## Every variant waits this long before measuring, manned or not.
const NONE: float = -1.0  ## "No operator".
const STATIONS: Array[String] = ["drill", "weapons", "bracing", "helm"]
## station -> [operator crew id, station room, where the usual occupant goes when it is unmanned]
const POSTS: Dictionary = {
	"drill": ["okafor", "drill", "weapons"],
	"weapons": ["okafor", "weapons", "drill"],
	"bracing": ["lindqvist", "bracing", "reactor"],
	"helm": ["vasquez", "bridge", "reactor"],
}


# Setup -----------------------------------------------------------------------------------------

## A sim of the scenario on `d`: its ship, its timeline (all at 0 s) queued.
func _sim(d: DataDB) -> Sim:
	var sc: Dictionary = d.scenarios[SCENARIO]
	var s := Sim.new(d, 7, str(sc["ship"]))
	for e: Dictionary in sc.get("timeline", []):
		check_eq(float(e["at_s"]), 0.0, "ledger_manning sets everything up at 0 s")
		s.push(e["cmd"])
	return s


func _window(d: DataDB) -> int:
	return roundi(float(d.scenarios[SCENARIO]["duration_s"]) * Sim.TICK_HZ)


## Man `station` with its operator at station skill `skill` (with NONE, move the usual occupant away
## so it is unmanned), then let everyone walk for WALK_TICKS.
func _place(s: Sim, station: String, skill: float) -> void:
	var post: Array = POSTS[station]
	var c: CrewMember = s.ship.crew_by_id(str(post[0]))
	var ri: int = s.ship.room_index(str(post[1]))
	if skill == NONE:
		if c.room == ri:
			s.push({"type": "assign", "crew": c.id, "room": str(post[2])})
	else:
		c.skill_station = skill
		s.push({"type": "assign", "crew": c.id, "room": str(post[1])})
	for i: int in range(WALK_TICKS):
		s.step()
	check_eq(s.systems.is_manned(s.player, ri), skill != NONE, "%s manned after the walk (skill %.1f)" % [station, skill])


# Measurements ----------------------------------------------------------------------------------

## One station's measured performance over the scenario window: drill, mean cut speed (m/s) on
## uniform rock with the bit held fresh; weapons, 1 / ticks to a full charge of the borer (one bar);
## bracing, 1 / ticks for a spent layer to come back; helm, mean evasion.
func _measure(d: DataDB, station: String, skill: float) -> float:
	var s: Sim = _sim(d)
	_place(s, station, skill)
	var n: int = _window(d)
	match station:
		"drill":
			s.push({"type": "begin_segment", "segment": "ledger", "depth_m": 36.0, "lateral_m": 0.0})
			s.step()
			_fill_rock(s)
			var sum: float = 0.0
			for i: int in range(n):
				s.drill.bit_wear = 0.0  # Same bit every tick: a faster drill must not be slowed by wear.
				s.step()
				sum += s.drill.speed_m_s
			return sum / float(n)
		"weapons":
			s.combat.start_fight(s, "rival_light", false)
			s.combat.enemy_side = CombatSide.new()  # Unarmed rival: nothing hits the station.
			var full: float = s.combat.player_side.defs[0].charge_s - 0.000001
			var ticks: int = 0
			while s.combat.player_side.charge[0] < full and ticks < 2 * n:
				s.step()
				ticks += 1
			check(ticks < 2 * n, "the borer charged within the window")
			return 1.0 / float(ticks)
		"bracing":
			check(s.systems.absorb_hit(s, s.player), "the bracing layer takes a hit")
			var ticks: int = 0
			while s.systems.bracing_layers(s.player) < 1 and ticks < 2 * n:
				s.step()
				ticks += 1
			check(ticks < n, "the layer came back within the window")
			return 1.0 / float(ticks)
		"helm":
			var sum: float = 0.0
			for i: int in range(n):
				s.step()
				sum += s.systems.evasion(s.player)
			return sum / float(n)
	return 0.0


func _fill_rock(s: Sim) -> void:
	var dr: DrillSim = s.drill
	var code: int = -1
	for c: int in range(dr.materials.size()):
		if str(dr.materials[c].get("id", "")) == "rock":
			code = c
	var first_row: int = ceili((dr.ship_pos.y + dr.ship_size.y) / dr.cell_m - 0.000001)
	for i: int in range(first_row * dr.cols, dr.grid.size()):
		dr.grid[i] = code
	dr._band_dirty = true


## station -> [bonus at skill 1.0, bonus at skill 2.0]. Drill, weapons and bracing: the rate over
## the unmanned rate, minus 1. Helm: evasion above what its bars give (bars x evasion_per_bar).
func _bonuses(d: DataDB) -> Dictionary:
	var out: Dictionary = {}
	for st: String in STATIONS:
		var pair: Array[float] = []
		var base: float = 0.0
		if st == "helm":
			var s: Sim = _sim(d)
			s.step()
			base = float(s.ship.rooms[s.ship.room_index("bridge")].effective_bars()) * d.tune("systems.evasion_per_bar")
		else:
			base = _measure(d, st, NONE)
		for k: float in [1.0, 2.0]:
			var got: float = _measure(d, st, k)
			pair.append(got - base if st == "helm" else got / base - 1.0)
		out[st] = pair
	return out


# Band checks -----------------------------------------------------------------------------------

func _man01_failures(b: Dictionary) -> PackedStringArray:
	var bad := PackedStringArray()
	for st: String in STATIONS:
		var pair: Array[float] = b[st]
		var lo: float = 0.02 if st == "helm" else 0.12
		var hi: float = 0.04 if st == "helm" else 0.20
		if pair[0] < lo or pair[0] > hi:
			bad.append("%s: bonus at skill 1.0 is %.4f, band %.2f to %.2f" % [st, pair[0], lo, hi])
		var ratio: float = pair[1] / pair[0] if pair[0] > 0.0 else 0.0
		if ratio < 1.5 or ratio > 2.0:
			bad.append("%s: bonus at 2.0 / at 1.0 is %.3f, band 1.5 to 2.0" % [st, ratio])
	return bad


## L-MAN-02: the station in a room with two crew gives exactly the better operator's bonus.
func _man02_failures(two: float, best_alone: float) -> PackedStringArray:
	var bad := PackedStringArray()
	if two != best_alone:
		bad.append("two crew give %.6f, the better one alone %.6f" % [two, best_alone])
	return bad


func _man03_failures(start: Array[float], hires: Array[float]) -> PackedStringArray:
	var bad := PackedStringArray()
	var all: Array[float] = start.duplicate()
	all.append_array(hires)
	var lo: float = 99.0
	var hi: float = 0.0
	for v: float in all:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if lo > 0.9 + 1e-9 or hi < 1.6 - 1e-9:
		bad.append("station skills span %.2f to %.2f, need at least 0.9 to 1.6" % [lo, hi])
	var top_hire: float = 0.0
	for v: float in hires:
		top_hire = maxf(top_hire, v)
	if top_hire < 1.5 - 1e-9:
		bad.append("the best hire is at %.2f, need one at 1.5 or more" % top_hire)
	return bad


## Every manned_bonus and manned_dodge in the systems table at zero (on a fresh DataDB).
func _no_manned_effects() -> DataDB:
	var d: DataDB = db()
	var table: Dictionary = d.table("systems")
	for id: Variant in table.keys():
		var def: Dictionary = table[id]
		def["manned_bonus"] = 0.0
		if def.has("manned_dodge"):
			def["manned_dodge"] = 0.0
	return d


# Tests -----------------------------------------------------------------------------------------

func test_l_man_01() -> void:
	var real: Dictionary = _bonuses(db())
	var bad: PackedStringArray = _man01_failures(real)
	check(bad.is_empty(), "L-MAN-01 bands: " + " | ".join(bad))
	for st: String in STATIONS:
		var pair: Array[float] = real[st]
		print("L-MAN-01 %s: bonus %.4f at skill 1.0, %.4f at 2.0 (x%.3f)" % [st, pair[0], pair[1], pair[1] / pair[0]])
	# Wrong value 1: no manned effects at all.
	check(not _man01_failures(_bonuses(_no_manned_effects())).is_empty(), "every manned bonus at zero must fail L-MAN-01")
	# Wrong value 2: skill ignored (2.0 gives what 1.0 gives).
	var flat: PackedStringArray = _man01_failures(_bonuses(db({"systems.station_skill_gain": 0.0})))
	var ratio_failed: bool = false
	for f: String in flat:
		if f.contains("2.0 / at 1.0"):
			ratio_failed = true
	check(ratio_failed, "station_skill_gain 0 must fail the second clause (got: %s)" % " | ".join(flat))
	# The helm dodges nothing without effective bars, even manned.
	var s: Sim = _sim(db())
	run_seconds(s, 1.0)
	check_gt(s.systems.evasion(s.player), 0.0, "a powered, manned helm dodges")
	s.push({"type": "power", "room": "bridge", "bars": 0})
	s.step()
	check(s.systems.is_manned(s.player, s.ship.room_index("bridge")), "Vasquez still mans the helm")
	check_eq(s.systems.evasion(s.player), 0.0, "an unpowered helm gives no evasion, manned or not")


func test_l_man_02() -> void:
	var d: DataDB = db()
	var weapons_bonus: float = float(d.table("systems")["weapons"]["manned_bonus"])
	# Two crew at the weapons station: Okafor (1.0) and Vasquez (2.0).
	var two: Sim = _sim(d)
	var w: int = two.ship.room_index("weapons")
	two.ship.crew_by_id("okafor").skill_station = 1.0
	two.ship.crew_by_id("vasquez").skill_station = 2.0
	two.push({"type": "assign", "crew": "okafor", "room": "weapons"})
	two.push({"type": "assign", "crew": "vasquez", "room": "weapons"})
	run_seconds(two, 8.0)
	var manning: int = 0
	for c: CrewMember in two.ship.crew:
		if c.room == w and two.systems.is_manned(two.player, w):
			manning += 1
	check_eq(manning, 2, "both stand at the weapons station")
	check_eq(two.systems.operator(two.player, w).id, "vasquez", "the better one runs it")
	var got_two: float = two.systems.weapon_bonus(two.player)
	# Vasquez alone at 2.0.
	var one: Sim = _sim(d)
	one.ship.crew_by_id("vasquez").skill_station = 2.0
	one.push({"type": "assign", "crew": "vasquez", "room": "weapons"})
	run_seconds(one, 8.0)
	var got_one: float = one.systems.weapon_bonus(one.player)
	var bad: PackedStringArray = _man02_failures(got_two, got_one)
	check(bad.is_empty(), "L-MAN-02: " + " | ".join(bad))
	print("L-MAN-02: two crew %.6f, the better alone %.6f" % [got_two, got_one])
	# Wrong rule: bonuses summed over the crew manning the room.
	var summed: float = 1.0
	for c: CrewMember in two.ship.crew:
		if c.room == w and c.alive and not c.climbing and c.path_i >= c.path.size() and (c.job_kind == "go" or c.job_kind == ""):
			summed += weapons_bonus * two.systems.skill_scale(c.skill_station)
	check(not _man02_failures(summed, got_one).is_empty(), "summing the bonus over the crew must fail L-MAN-02 (%.6f)" % summed)
	# A tie goes to the lowest crew index (Vasquez is crew 0).
	two.ship.crew_by_id("vasquez").skill_station = 1.0
	check_eq(two.systems.operator(two.player, w).id, "vasquez", "a tie goes to the lowest crew index")
	# Arrival: the bonus is on within one crew decision (15 ticks) of the operator arriving.
	var s: Sim = _sim(d)
	s.push({"type": "assign", "crew": "okafor", "room": "weapons"})
	var arrived: int = -1
	var on: int = -1
	for i: int in range(600):
		s.step()
		if arrived < 0:
			for e: Dictionary in s.events:
				if str(e["kind"]) == "arrive" and str(e.get("crew", "")) == "okafor" and str(e.get("room", "")) == "weapons":
					arrived = int(e["t"])
		if on < 0 and s.systems.weapon_bonus(s.player) > 1.0:
			on = s.tick - 1
		if arrived >= 0 and on >= 0:
			break
	check(arrived >= 0 and on >= 0, "Okafor arrived (%d) and the bonus came on (%d)" % [arrived, on])
	check(on - arrived >= 0 and on - arrived <= Sim.THINK_EVERY, "bonus on %d ticks after arriving" % (on - arrived))
	print("L-MAN-02: bonus on %d ticks after the operator arrived" % (on - arrived))
	# Another job in the station room gives nothing: a fire there turns Okafor into a firefighter.
	s.push({"type": "ignite", "room": "weapons", "level": 0.4})
	var fighting: bool = false
	for i: int in range(2 * Sim.THINK_EVERY):
		s.step()
		var ok: CrewMember = s.ship.crew_by_id("okafor")
		if ok.job_kind == "extinguish" and ok.room == w:
			fighting = true
			break
	check(fighting, "Okafor fights the weapons-room fire")
	check_eq(s.systems.weapon_bonus(s.player), 1.0, "a crew member fighting a fire does not man the station")


func test_l_man_03() -> void:
	var d: DataDB = db()
	var start: Array[float] = []
	for cd: Dictionary in d.ships["light_drill"].get("crew", []):
		var sk: Dictionary = cd.get("skills", {})
		start.append(float(sk.get("station", 1.0)))
	var hires: Array[float] = []
	for m: Dictionary in d.table("crew")["survivors"].get("members", []):
		var sk: Dictionary = m.get("skills", {})
		hires.append(float(sk.get("station", 1.0)))
	var bad: PackedStringArray = _man03_failures(start, hires)
	check(bad.is_empty(), "L-MAN-03: " + " | ".join(bad))
	print("L-MAN-03: starting crew %s, hires %s" % [str(start), str(hires)])
	# The ship reads it into the crew.
	var s: Sim = _sim(d)
	for i: int in range(start.size()):
		check_eq(s.ship.crew[i].skill_station, start[i], "crew %d reads its station skill from the ship data" % i)
	# Wrong value: everyone at 1.0.
	var flat_start: Array[float] = []
	flat_start.resize(start.size())
	flat_start.fill(1.0)
	var flat_hires: Array[float] = []
	flat_hires.resize(hires.size())
	flat_hires.fill(1.0)
	check(not _man03_failures(flat_start, flat_hires).is_empty(), "every station skill at 1.0 must fail L-MAN-03")
	# The lint keeps station skills above zero, on ships and in hire pools.
	var broken: DataDB = db()
	var crew0: Dictionary = (broken.ships["light_drill"]["crew"] as Array)[0]
	(crew0["skills"] as Dictionary)["station"] = 0.0
	var m0: Dictionary = (broken.table("crew")["survivors"]["members"] as Array)[0]
	(m0["skills"] as Dictionary)["station"] = -1.0
	var all: String = "\n".join(broken.lint())
	check(all.contains("light_drill") and all.contains("skill \"station\" must be a number above zero"), "a ship crew station skill of 0 is caught")
	check(all.contains("survivors"), "a hire's station skill below zero is caught")
