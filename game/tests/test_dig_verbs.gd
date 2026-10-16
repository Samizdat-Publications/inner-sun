extends TestCase
## M1c dig verbs (game/sim/drill/drill_verbs.gd, game/sim/systems/systems_douse.gd): hold depth and
## helm-powered side cutting, fault rock strain and rockfalls, blasts by the charge launcher, douse.
## Conserved quantities are checked with exact equality.


## A run-mode sim on light_drill, a second in, with the given bars (bracing 0 unless asked).
func _sim(drill_bars: int = 2, helm_bars: int = 1, bracing_bars: int = 0, weapon_bars: int = 0, mode: String = "run") -> Sim:
	var s := Sim.new(db(), 11, "light_drill", {"mode": mode})
	s.push({"type": "power", "room": "bracing", "bars": bracing_bars})
	s.push({"type": "power", "room": "drill", "bars": drill_bars})
	s.push({"type": "power", "room": "bridge", "bars": helm_bars})
	s.push({"type": "power", "room": "weapons", "bars": weapon_bars})
	run_seconds(s, 1.0)
	return s


func _begin(s: Sim, depth: float = 36.0) -> void:
	s.push({"type": "begin_segment", "segment": "v", "depth_m": depth, "lateral_m": 0.0})
	s.step()


func _code(s: Sim, id: String) -> int:
	for c: int in range(s.drill.materials.size()):
		if str(s.drill.materials[c].get("id", "")) == id:
			return c
	return -1


## Every cell outside the ship's footprint becomes one material (test setup only).
func _fill_all(s: Sim, code: int) -> void:
	var d: DrillSim = s.drill
	var ship := Rect2(d.ship_pos, d.ship_size)
	for r: int in range(d.rows):
		for c: int in range(d.cols):
			if not ship.has_point(Vector2((c + 0.5) * d.cell_m, (r + 0.5) * d.cell_m)):
				d.grid[r * d.cols + c] = code
	d._band_dirty = true


## A disc of one material (cell centres within radius), test setup only.
func _disc(s: Sim, centre: Vector2, radius: float, code: int) -> int:
	var d: DrillSim = s.drill
	var n: int = 0
	for r: int in range(d.rows):
		for c: int in range(d.cols):
			if Vector2((c + 0.5) * d.cell_m, (r + 0.5) * d.cell_m).distance_to(centre) <= radius:
				d.grid[r * d.cols + c] = code
				n += 1
	d._band_dirty = true
	return n


func _count(s: Sim, kind: String) -> int:
	var n: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == kind:
			n += 1
	return n


func _last(s: Sim, kind: String) -> Dictionary:
	for i: int in range(s.events.size() - 1, -1, -1):
		if str(s.events[i]["kind"]) == kind:
			return s.events[i]
	return {}


func _last_why(s: Sim, kind: String) -> String:
	for i: int in range(s.events.size() - 1, -1, -1):
		var e: Dictionary = s.events[i]
		if str(e["kind"]) == "bad_command" and str(e.get("type", "")) == kind:
			return str(e.get("why", ""))
	return ""


func _sum(a: PackedInt32Array) -> int:
	var n: int = 0
	for v: int in a:
		n += v
	return n


func _crown(s: Sim) -> Vector2:
	return Vector2(s.drill.ship_pos.x + s.drill.ship_size.x * 0.5, s.drill.ship_pos.y + s.drill.ship_size.y)


# Steering ----------------------------------------------------------------------------------------

func test_heading_90_holds_depth_and_cuts_sideways() -> void:
	var s: Sim = _sim(2, 2)
	_begin(s)
	_fill_all(s, _code(s, "rock"))
	s.push({"type": "steer", "angle": 120.0})
	s.step()
	check_eq(s.drill.target_heading_deg, 90.0, "the heading is clamped to 90")
	while s.drill.heading_deg < 90.0:
		s.step()
	var bottom0: float = s.drill.ship_pos.y + s.drill.ship_size.y
	var x0: float = s.drill.ship_pos.x
	run_seconds(s, 2.0)
	var bottom1: float = s.drill.ship_pos.y + s.drill.ship_size.y
	check_lt(absf(bottom1 - bottom0), s.drill.cell_m, "hold depth: the bottom edge stays within a cell over 2 s")
	check_gt(s.drill.ship_pos.x - x0, 0.3, "and the ship cuts sideways")
	check(s.drill.cutting, "it is cutting rock")
	check(not s.drill.at_wall, "not at the wall yet")
	check_gt(float(s.drill.steep_ticks), 100.0, "steep ticks count the time past 60 degrees")


func test_side_speed_scales_with_a_manned_helm() -> void:
	var dx := PackedFloat64Array()
	var scale := PackedFloat64Array()
	for manned: bool in [true, false]:
		var s: Sim = _sim(2, 2)
		if not manned:
			s.push({"type": "assign", "crew": "vasquez", "room": "weapons"})
			run_seconds(s, 10.0)
		check_eq(s.systems.is_manned(s.player, s.ship.room_index("bridge")), manned, "helm manned: %s" % manned)
		_begin(s)
		_fill_all(s, _code(s, "rock"))
		s.drill.heading_deg = 90.0  # Test setup: already turned.
		s.drill.target_heading_deg = 90.0
		s.step()
		var x0: float = s.drill.ship_pos.x
		for i: int in range(60):
			s.drill.bit_wear = 0.0  # Test setup: no bit wear, so the speed is the same in both runs.
			s.step()
		dx.append(s.drill.ship_pos.x - x0)
		scale.append(s.drill.side_scale)
	check_lt(absf(scale[0] - 0.95), 1e-9, "two manned helm bars: side scale 0.35 + 2 x 0.3")
	check_lt(absf(scale[1] - 0.35), 1e-9, "unmanned: the base 0.35")
	check_lt(absf(dx[0] / dx[1] - 0.95 / 0.35), 1e-6, "side speed ratio matches the tuning (%.4f)" % (dx[0] / dx[1]))


func test_turn_rate_scales_with_helm_bars() -> void:
	var got := PackedFloat64Array()
	for bars: int in [0, 2]:
		var s: Sim = _sim(2, bars)
		_begin(s)
		s.push({"type": "steer", "angle": 90.0})
		run_seconds(s, 1.0)
		got.append(s.drill.heading_deg)
	check_lt(absf(got[0] - 18.0), 1e-6, "no helm bars: 18 deg/s (%.3f)" % got[0])
	check_lt(absf(got[1] - 39.6), 1e-6, "two manned bars: 18 x (1 + 2 x 0.6) = 39.6 deg/s (%.3f)" % got[1])


func test_at_the_wall_no_progress() -> void:
	var s: Sim = _sim(2, 2)
	_begin(s)
	_fill_all(s, _code(s, "rock"))
	var d: DrillSim = s.drill
	d._px = float(d.cols) * d.cell_m - d.ship_size.x  # Test setup: against the right wall.
	d.ship_pos.x = d._px
	d._set_footprint()
	d.heading_deg = 90.0
	d.target_heading_deg = 90.0
	run_seconds(s, 0.5)
	var p: Vector2 = d.ship_pos
	run_seconds(s, 2.0)
	check(d.at_wall, "pressed against the wall at 90 degrees: at_wall")
	check_lt(d.ship_pos.distance_to(p), 0.001, "and no progress")
	s.push({"type": "steer", "angle": 0.0})
	run_seconds(s, 4.0)
	check(not d.at_wall, "steering down leaves the wall")


# Fault rock and rockfalls ------------------------------------------------------------------------

func _until(s: Sim, kind: String, cap_s: float) -> bool:
	var cap: int = roundi(cap_s * Sim.TICK_HZ)
	while _count(s, kind) == 0 and cap > 0:
		s.step()
		cap -= 1
	return _count(s, kind) > 0


func test_fault_rock_strain_schedules_rockfalls() -> void:
	var s: Sim = _sim(2, 1, 0)
	_begin(s)
	_fill_all(s, _code(s, "fault_rock"))
	check(_until(s, "rockfall_warn", 30.0), "cutting fault rock schedules a rockfall")
	var warn: Dictionary = _last(s, "rockfall_warn")
	check_eq(float(warn["in_s"]), 1.2, "warned 1.2 s ahead")
	var t_warn: int = int(warn["t"])
	var hull0: int = s.run.get_res("hull")
	check(_until(s, "rockfall", 5.0), "the rockfall lands")
	var e: Dictionary = _last(s, "rockfall")
	check_eq(int(e["t"]) - t_warn, 72, "72 ticks after the warning")
	check(not bool(e["absorbed"]), "no bracing layer: not absorbed")
	check_eq(s.run.get_res("hull"), hull0 - 1, "hull drops by exactly 1")
	check_eq(int(e["hull"]), 1, "the event says 1 hull")
	var hit: String = str(e["room"])
	check(hit == "bridge" or hit == "bracing", "a top-deck room is hit (%s)" % hit)
	var dmg: Dictionary = _last(s, "system_damaged")
	check_eq(str(dmg.get("room", "")), hit, "that room's system is damaged")
	check_eq(int(dmg.get("t", -1)), int(e["t"]), "in the same tick")
	check_gt(room(s, hit).sys_damage, 0.49, "by 0.5 bars")
	check_gt(float(s.drill.verbs.rockfalls), 0.0, "counted on the segment")
	var sum: Dictionary = s.run.summary(s)
	check_eq(int(sum["rockfalls_hit"]), 1, "the summary counts the hit")
	check_eq(int(sum["rockfall_hull"]), 1, "and the hull it cost")
	run_seconds(s, 20.0)
	check_gt(float(_count(s, "rockfall")), 1.0, "rockfalls keep coming while the ship stays in fault rock")


func test_bracing_layer_absorbs_a_rockfall() -> void:
	var s: Sim = _sim(2, 1, 2)
	check_eq(s.systems.bracing_layers(s.player), 1, "two bracing bars hold one layer")
	_begin(s)
	_fill_all(s, _code(s, "fault_rock"))
	var hull0: int = s.run.get_res("hull")
	var dmg0: float = 0.0
	for r: Room in s.ship.rooms:
		dmg0 += r.sys_damage
	check(_until(s, "rockfall", 40.0), "a rockfall lands")
	var e: Dictionary = _last(s, "rockfall")
	check(bool(e["absorbed"]), "the bracing layer soaks it")
	check(has_event(s, "bracing_absorbed"), "bracing_absorbed fires")
	check_eq(s.run.get_res("hull"), hull0, "no hull lost")
	var dmg1: float = 0.0
	for r: Room in s.ship.rooms:
		dmg1 += r.sys_damage
	check_eq(dmg1, dmg0, "no room damaged")
	check_eq(s.systems.bracing_layers(s.player), 0, "the layer is spent")
	check_eq(int(s.run.summary(s)["rockfalls_absorbed"]), 1, "the summary counts it absorbed")


func test_a_rockfall_can_end_the_run() -> void:
	var s: Sim = _sim(2, 1, 0)
	s.run.add(s, "hull", 1 - s.run.get_res("hull"))
	_begin(s)
	_fill_all(s, _code(s, "fault_rock"))
	check(_until(s, "rockfall", 30.0), "a rockfall lands")
	s.step()
	check_eq(s.run.phase, "dead", "the run is over")
	check_eq(s.run.end_cause, "rockfall", "with cause rockfall for the death screen")


func test_scenario_rockfall_damages_rooms_only() -> void:
	var s: Sim = _sim(2, 1, 0, 0, "scenario")
	var hull0: int = s.run.get_res("hull")
	_begin(s)
	_fill_all(s, _code(s, "fault_rock"))
	check(_until(s, "rockfall", 30.0), "a rockfall lands in a scenario too")
	check_eq(s.run.get_res("hull"), hull0, "no run hull in scenario mode")
	check_eq(int(_last(s, "rockfall")["hull"]), 0, "the event says no hull")
	check(has_event(s, "system_damaged"), "a room is damaged")


func test_survey_faults_put_fault_rock_in_the_segment() -> void:
	for faults: bool in [true, false]:
		var found: int = 0
		for p_seed: int in range(1, 6):
			var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
			s.push({"type": "begin_segment", "segment": "f%d" % p_seed, "depth_m": 60.0, "lateral_m": 0.0,
					"survey": {"faults": faults}})
			s.step()
			found += s.drill.generated[_code(s, "fault_rock")]
		if faults:
			check_gt(float(found), 100.0, "a survey with faults gives fault zones (%d cells over 5 seeds)" % found)
		else:
			check_eq(found, 0, "no faults in the survey, no fault rock")
	var layer: Dictionary = db().table("layers")["crust"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var deep: int = 0
	for i: int in range(200):
		var sv: Dictionary = Survey.roll(layer["survey"], {}, false, 0.0, 60.0, rng, 10)
		check(sv.has("faults"), "a reading says faults")
		if bool(sv["faults"]):
			deep += 1
	check(deep > 80 and deep < 160, "row 10: about 55 percent of readings have faults (%d of 200)" % deep)


# Blasts ------------------------------------------------------------------------------------------

func test_blast_preconditions() -> void:
	var s: Sim = _sim(0, 1, 0, 0)
	s.push({"type": "blast", "x_m": 10.0, "y_m": 20.0})
	s.step()
	check_eq(_last_why(s, "blast"), "not drilling", "idle: not drilling")
	_begin(s)
	var d: DrillSim = s.drill
	var p: Vector2 = _crown(s) + Vector2(0.0, 4.0)
	check_eq(d.blast_ready(s), "power weapons", "weapons unpowered")
	s.push({"type": "blast", "x_m": p.x, "y_m": p.y})
	s.step()
	check_eq(_last_why(s, "blast"), "power weapons", "refused: power weapons")
	s.push({"type": "power", "room": "weapons", "bars": 1})
	s.step()
	check_eq(d.blast_ready(s), "", "weapons at one bar and charges aboard: ready")
	for far: Vector2 in [_crown(s) + Vector2(0.0, 20.0), d.ship_pos + d.ship_size * 0.5, Vector2(-1.0, 5.0)]:
		s.push({"type": "blast", "x_m": far.x, "y_m": far.y})
		s.step()
		check_eq(_last_why(s, "blast"), "out of range", "out of range: %s" % str(far))
	var charges0: int = s.run.get_res("charges")
	s.push({"type": "blast", "x_m": p.x, "y_m": p.y})
	s.step()
	check_eq(s.run.get_res("charges"), charges0 - 1, "one charge spent at once")
	check(d.verbs.blast_pending, "the charge is in flight")
	var fired: Dictionary = _last(s, "blast_fired")
	check_eq(float(fired["fuse_s"]), 0.6, "with a 0.6 s fuse")
	s.push({"type": "blast", "x_m": p.x, "y_m": p.y})
	s.step()
	check_eq(_last_why(s, "blast"), "reloading", "a second blast at once: reloading")
	run_seconds(s, 5.0)
	check_eq(d.blast_ready(s), "", "reloaded after 5 s")
	s.run.add(s, "charges", -s.run.get_res("charges"))
	check_eq(d.blast_ready(s), "no charges", "no charges")
	s.run.add(s, "charges", 2)
	s.ship.weapons = PackedStringArray(["borer_turret"])  # Test setup: no launcher mounted.
	check_eq(d.blast_ready(s), "no launcher", "no charge weapon mounted")


func test_blast_clears_the_circle_and_pays_exactly() -> void:
	var s: Sim = _sim(0, 1, 0, 1)
	_begin(s)
	var d: DrillSim = s.drill
	_fill_all(s, _code(s, "rock"))
	var p: Vector2 = _crown(s) + Vector2(3.0, 5.0)
	_disc(s, p + Vector2(0.5, 0.0), 1.0, _code(s, "copper_ore"))
	_disc(s, p + Vector2(-1.0, 0.5), 0.6, _code(s, "emerald"))
	var circle: PackedInt32Array = d.verbs.circle_cells(d, p)
	var want_cells: int = 0
	var want_ore: int = 0
	var want_gems: int = 0
	for i: int in circle:
		var m: int = d.grid[i]
		if m == 0:
			continue
		want_cells += 1
		if d.yield_res_of[m] == RunState.RESOURCES.find("ore"):
			want_ore += d.yield_amount_of[m]
		elif d.yield_res_of[m] == RunState.RESOURCES.find("gems"):
			want_gems += d.yield_amount_of[m]
	check_gt(float(want_ore), 0.0, "ore in the circle")
	check_gt(float(want_gems), 0.0, "gems in the circle")
	var mined0: int = _sum(d.mined)
	var ore0: int = s.run.get_res("ore")
	var gems0: int = s.run.get_res("gems")
	var charges0: int = s.run.get_res("charges")
	var noise0: float = d.noise_total
	var air0: int = 0
	for v: int in d.grid:
		if v == 0:
			air0 += 1
	s.push({"type": "blast", "x_m": p.x, "y_m": p.y})
	s.step()
	check_eq(d.verbs.blast_fuse_ticks, 35, "the fuse burns down")
	run_seconds(s, 0.6)
	check(has_event(s, "blast"), "the charge went off")
	var e: Dictionary = _last(s, "blast")
	check_eq(int(e["cells"]), want_cells, "the event counts the cleared cells")
	for i: int in circle:
		check_eq(d.grid[i], 0, "cell %d in the circle is air" % i)
	var air1: int = 0
	for v: int in d.grid:
		if v == 0:
			air1 += 1
	check_eq(air1 - air0, want_cells, "exactly the cells in the circle became air")
	check_eq(_sum(d.mined) - mined0, want_cells, "mined rose by exactly the cleared cells")
	check_eq(s.run.get_res("ore") - ore0, want_ore, "ore rose by exactly the yield")
	check_eq(s.run.get_res("gems") - gems0, want_gems, "gems rose by exactly the yield")
	check_eq(int(e["ore"]), want_ore, "the event's ore")
	check_eq(int(e["gems"]), want_gems, "the event's gems")
	check_eq(s.run.get_res("charges"), charges0 - 1, "one charge spent")
	check_eq(d.noise_total - noise0, 15.0, "the blast made exactly its noise (the drill is off)")
	var chunk_sum: int = 0
	for v: int in d.chunk_changes:
		chunk_sum += v
	check_eq(chunk_sum, _sum(d.mined), "chunk counters count every cleared cell")
	var m: Dictionary = _last(s, "mined")
	check_eq(Vector2(float(m["x_m"]), float(m["y_m"])), Vector2(snappedf(p.x, 0.01), snappedf(p.y, 0.01)), "mined events at the blast point")
	check_eq(d.verbs.strain, 0, "blasts add no strain")
	check_eq(int(s.run.summary(s)["blasts"]), 1, "the summary counts the blast")


func test_blast_burns_gas_far_safely_and_near_with_fire() -> void:
	for near: bool in [false, true]:
		var s: Sim = _sim(0, 1, 0, 1)
		_begin(s)
		var d: DrillSim = s.drill
		_fill_all(s, _code(s, "rock"))
		var p: Vector2 = _crown(s) + (Vector2(0.0, 1.5) if near else Vector2(0.0, 7.0))
		var gas: int = _disc(s, p + Vector2(0.0, 1.0), 1.2, _code(s, "gas_pocket"))
		s.push({"type": "blast", "x_m": p.x, "y_m": p.y})
		run_seconds(s, 1.0)
		var e: Dictionary = _last(s, "blast")
		check(bool(e["burned"]), "near %s: the gas pocket burned off" % near)
		var left: int = 0
		for v: int in d.grid:
			if v == _code(s, "gas_pocket"):
				left += 1
		check_eq(left, 0, "near %s: the whole connected pocket is gone (%d cells)" % [near, gas])
		var fire: float = room(s, "drill").fire
		if near:
			check_gt(fire, 0.0, "a blast within 3 m lights the drill room")
			check(has_event(s, "gas_burst"), "like a gas burst")
		else:
			check_eq(fire, 0.0, "far from the ship: no fire")
			check(not has_event(s, "gas_burst"), "and no gas burst")


func test_blast_drains_a_water_pocket_without_ship_water() -> void:
	var s: Sim = _sim(0, 1, 0, 1)
	_begin(s)
	var d: DrillSim = s.drill
	_fill_all(s, _code(s, "rock"))
	var p: Vector2 = _crown(s) + Vector2(-4.0, 4.0)
	var wcode: int = _code(s, "water_pocket")
	var cells: int = _disc(s, p + Vector2(-1.5, 0.0), 1.5, wcode)
	var water0: int = room(s, "drill").water_ml
	var in0: int = s.hazards.water_in_ml
	s.push({"type": "blast", "x_m": p.x, "y_m": p.y})
	run_seconds(s, 1.0)
	check(bool(_last(s, "blast")["drained"]), "the pocket drained")
	for v: int in d.grid:
		if v == wcode:
			check(false, "a water pocket cell is left")
			break
	check_eq(d.verbs.drained_cells, cells, "every cell of the connected pocket drained")
	check_eq(d.mined[wcode], cells, "and counted in mined")
	check_eq(room(s, "drill").water_ml, water0, "no water entered the drill room")
	check_eq(s.hazards.water_in_ml, in0, "no water entered the ship")
	check_eq(d.lost_water_ml, 0, "nothing counted as lost ship water")
	check_eq(d.water_in_ml + d.lost_water_ml, (d.mined[wcode] - d.verbs.drained_cells) * d.water_cell_ml,
			"pocket water books: in + lost == cut (not drained) cells x cell water")
	check(not has_event(s, "pocket_burst"), "no breach")


# Douse -------------------------------------------------------------------------------------------

func test_douse_needs_power_and_coolant_and_books_heat_exactly() -> void:
	var s: Sim = _sim(0, 1, 0, 0)
	crew_auto_off(s)
	s.step()
	var h: HazardSim = s.hazards
	s.push({"type": "douse", "room": "weapons"})
	s.step()
	check_eq(_last_why(s, "douse"), "no fire", "nothing burning")
	s.push({"type": "ignite", "room": "weapons", "level": 0.9})
	s.push({"type": "power", "room": "coolant", "bars": 0})
	run_seconds(s, 1.0)
	check_eq(s.systems.douse_ready(s, "weapons"), "power coolant", "the coolant system needs a bar")
	s.push({"type": "douse", "room": "weapons"})
	s.step()
	check_eq(_last_why(s, "douse"), "power coolant", "refused without coolant power")
	s.push({"type": "power", "room": "coolant", "bars": 1})
	s.step()
	var r: Room = room(s, "weapons")
	check_eq(s.systems.douse_ready(s, "weapons"), "", "ready")
	var coolant0: int = s.run.get_res("coolant")
	var billed0: int = s.systems.coolant_units_used(s.player)
	var want_j: int = clampi(r.energy_j - ceili(r.start_temp_c * r.heat_cap_j_per_k), 0, 300000)
	var e0: int = s.ship.total_energy_j()
	var in0: int = h.energy_in_j
	var out0: int = h.energy_out_j
	s.push({"type": "douse", "room": "weapons"})
	s.step()
	var e: Dictionary = _last(s, "doused")
	check(not e.is_empty(), "doused")
	var before: float = float(e["fire_before"])
	check_lt(absf(float(e["fire_after"]) - maxf(0.0, before - 0.6)), 0.0011, "fire down by 0.6")
	var billed: int = s.systems.coolant_units_used(s.player) - billed0
	check_eq(s.run.get_res("coolant"), coolant0 - 1 - billed, "exactly one coolant unit spent by the douse")
	check_gt(float(want_j), 0.0, "the burning room is above its design temperature")
	check_eq(int(e["heat_j"]), want_j, "up to 300 kJ taken, never below design temperature")
	check_eq(s.ship.total_energy_j() - e0, (h.energy_in_j - in0) - (h.energy_out_j - out0), "heat books balance exactly")
	s.push({"type": "douse", "room": "weapons"})
	s.step()
	check_eq(_last_why(s, "douse"), "venting" if r.fire > 0.0 else "no fire", "a second douse at once is refused")
	run_seconds(s, 3.0)
	s.push({"type": "ignite", "room": "weapons", "level": 0.9})
	s.run.add(s, "coolant", -s.run.get_res("coolant"))
	s.step()
	check_eq(s.systems.douse_ready(s, "weapons"), "no coolant", "no coolant units left")
	check_eq(int(s.run.summary(s)["douses"]), 1, "the summary counts the douse")


func test_douse_never_cools_below_design_temperature() -> void:
	var s: Sim = _sim(0, 1, 0, 0)
	crew_auto_off(s)
	var r: Room = room(s, "weapons")
	s.push({"type": "ignite", "room": "weapons", "level": 0.5})
	s.step()
	r.set_temp_c(r.start_temp_c + 0.5)  # Test setup: barely above the design temperature.
	var e0: int = s.ship.total_energy_j()
	var want: int = r.energy_j - ceili(r.start_temp_c * r.heat_cap_j_per_k)
	var in0: int = s.hazards.energy_in_j
	var out0: int = s.hazards.energy_out_j
	s.push({"type": "douse", "room": "weapons"})
	s.step()
	check_eq(int(_last(s, "doused")["heat_j"]), want, "only the heat above design temperature is taken")
	check_eq(s.ship.total_energy_j() - e0, (s.hazards.energy_in_j - in0) - (s.hazards.energy_out_j - out0), "books exact")
	check_eq(r.fire, 0.0, "a 0.5 fire is out")
	check(has_event(s, "fire_out"), "fire_out by douse")


# Determinism -------------------------------------------------------------------------------------

func test_dig_verbs_replay_to_the_same_hash() -> void:
	var opts: Dictionary = {"mode": "run"}
	var s := Sim.new(db(), 31, "light_drill", opts)
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": 2})
	s.push({"type": "power", "room": "weapons", "bars": 1})
	s.step()
	s.push({"type": "begin_segment", "segment": "det", "depth_m": 30.0, "lateral_m": 4.0,
			"survey": {"faults": true, "gas": true, "water": true}})
	s.step()
	s.push({"type": "steer", "angle": 90.0})
	run_seconds(s, 3.0)
	var c: Vector2 = _crown(s)
	s.push({"type": "blast", "x_m": c.x - 3.0, "y_m": c.y + 4.0})
	run_seconds(s, 6.0)
	s.push({"type": "blast", "x_m": c.x + 2.0, "y_m": c.y + 6.0})
	s.push({"type": "steer", "angle": -30.0})
	s.push({"type": "ignite", "room": "bridge", "level": 0.8})
	s.step()
	s.push({"type": "douse", "room": "bridge"})
	run_seconds(s, 20.0)
	check(has_event(s, "blast"), "blasts happened")
	check(has_event(s, "doused"), "a douse happened")
	var again: Sim = Sim.replay(db(), 31, "light_drill", s.command_log, s.tick, opts)
	check_eq(again.state_hash(), s.state_hash(), "seed, options and commands give the same hash")
	check_eq(again.drill.grid, s.drill.grid, "and the same rock")
