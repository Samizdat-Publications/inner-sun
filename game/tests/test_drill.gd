extends TestCase
## The drilling segment (game/sim/drill): deterministic generation, exact conservation of rock, ore,
## gems, water and heat, segment length with the drill bot, and the replay of a driven segment.

const SEG_DEPTH_M: float = 36.0


func _sim(p_seed: int, bars: int = 2, mode: String = "run") -> Sim:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": mode})
	s.push({"type": "power", "room": "bracing", "bars": 0})  # Free reactor bars so the drill can take up to 4.
	s.push({"type": "power", "room": "drill", "bars": bars})
	s.step()
	return s


func _begin(s: Sim, seg: String = "a", depth: float = SEG_DEPTH_M, lateral: float = 0.0) -> void:
	s.push({"type": "begin_segment", "segment": seg, "depth_m": depth, "lateral_m": lateral})
	s.step()


## Drive with the bot until the segment ends (or a cap). Returns the segment time in seconds.
func _drive(s: Sim, cap_s: float = 120.0) -> float:
	var bot: Bot = Bot.make("drill")
	var cap: int = roundi(cap_s * Sim.TICK_HZ)
	while s.drill.active and cap > 0:
		bot.act(s)
		s.step()
		cap -= 1
	return float(s.drill.segment_ticks) / Sim.TICK_HZ


func _counts(grid: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(DrillSim.MAX_CODES)
	for i: int in range(grid.size()):
		out[grid[i]] += 1
	return out


func _sum(a: PackedInt32Array) -> int:
	var n: int = 0
	for v: int in a:
		n += v
	return n


func _code(s: Sim, id: String) -> int:
	for c: int in range(s.drill.materials.size()):
		if str(s.drill.materials[c].get("id", "")) == id:
			return c
	return -1


## Fill every cell below the ship's footprint with one material (test setup only).
func _fill_below(s: Sim, code: int) -> void:
	var d: DrillSim = s.drill
	var first_row: int = ceili((d.ship_pos.y + d.ship_size.y) / d.cell_m - 0.000001)
	for i: int in range(first_row * d.cols, d.grid.size()):
		d.grid[i] = code
	s.drill._band_dirty = true


func test_generation_is_deterministic_per_seed_and_segment() -> void:
	var a: Sim = _sim(5)
	_begin(a, "edge_1")
	var b: Sim = _sim(5)
	_begin(b, "edge_1")
	check_eq(a.drill.grid, b.drill.grid, "same seed and segment id give the same rock")
	var c: Sim = _sim(5)
	_begin(c, "edge_2")
	check(a.drill.grid != c.drill.grid, "another segment id gives other rock")
	var e: Sim = _sim(6)
	_begin(e, "edge_1")
	check(a.drill.grid != e.drill.grid, "another seed gives other rock")
	check_eq(a.drill.rows * a.drill.cols, a.drill.grid.size(), "grid is rows x cols")
	var counts: PackedInt32Array = _counts(a.drill.grid)
	for code: int in range(DrillSim.MAX_CODES):
		counts[code] += a.drill.mined[code] if code > 0 else -_sum(a.drill.mined)
	check_eq(counts, a.drill.generated, "generated counts == grid now + cut cells (one tick has run)")
	check_gt(float(counts[_code(a, "iron_ore")]), 0.0, "the rock has ore veins")
	check_gt(float(counts[_code(a, "hard_rock")]), 0.0, "the rock has hard rock")
	var d: DrillSim = a.drill
	for r: int in range(d.rows):
		for col: int in range(d.cols):
			var x: float = (col + 0.5) * d.cell_m
			var y: float = (r + 0.5) * d.cell_m
			if x > d.ship_pos.x and x < d.ship_pos.x + d.ship_size.x and y > d.ship_pos.y and y < d.ship_pos.y + d.ship_size.y:
				check_eq(d.grid[r * d.cols + col], 0, "the ship starts in an open shaft (cell %d,%d)" % [col, r])


func test_rock_ore_gems_and_water_are_conserved_exactly() -> void:
	var total_mined: int = 0
	for p_seed: int in [1, 2, 3, 4]:
		var s: Sim = _sim(p_seed, 3)
		var ore0: int = s.run.get_res("ore")
		var gems0: int = s.run.get_res("gems")
		_begin(s, "c%d" % p_seed, SEG_DEPTH_M, 3.0)
		var fresh: PackedInt32Array = s.drill.generated
		var first: PackedInt32Array = _counts(s.drill.grid)
		for code: int in range(1, DrillSim.MAX_CODES):
			check_eq(first[code] + s.drill.mined[code], fresh[code], "seed %d: material %d after the first tick" % [p_seed, code])
		_drive(s)
		var d: DrillSim = s.drill
		check(not d.active, "seed %d: the segment ended" % p_seed)
		var now: PackedInt32Array = _counts(d.grid)
		var want_ore: int = 0
		var want_gems: int = 0
		var chunk_sum: int = 0
		var mined_sum: int = 0
		for code: int in range(1, DrillSim.MAX_CODES):
			check_eq(now[code] + d.mined[code], fresh[code], "seed %d: material %d cells now + mined == generated" % [p_seed, code])
			mined_sum += d.mined[code]
			if d.yield_res_of[code] == RunState.RESOURCES.find("ore"):
				want_ore += d.mined[code] * d.yield_amount_of[code]
			if d.yield_res_of[code] == RunState.RESOURCES.find("gems"):
				want_gems += d.mined[code] * d.yield_amount_of[code]
		check_eq(now[0] - fresh[0], mined_sum, "seed %d: every cut cell became air" % p_seed)
		for v: int in d.chunk_changes:
			chunk_sum += v
		check_eq(chunk_sum, mined_sum, "seed %d: chunk change counters count every cut cell" % p_seed)
		check_eq(s.run.get_res("ore") - ore0, want_ore, "seed %d: ore added == ore yield of cut cells" % p_seed)
		check_eq(s.run.get_res("gems") - gems0, want_gems, "seed %d: gems added == gem yield of cut cells" % p_seed)
		check_eq(d.yielded[RunState.RESOURCES.find("ore")], want_ore, "seed %d: yielded books the ore" % p_seed)
		var water_cells: int = d.mined[_code(s, "water_pocket")]
		check_eq(d.water_in_ml + d.lost_water_ml, water_cells * d.water_cell_ml, "seed %d: pocket water in + lost == cells cut x cell water" % p_seed)
		total_mined += want_ore + want_gems
	check_gt(float(total_mined), 0.0, "the bot collected some ore or gems over four seeds")


func test_drill_heat_is_booked_in_the_hazard_books() -> void:
	var s := Sim.new(db(), 9, "light_drill", {"mode": "run"})
	var e0: int = s.ship.total_energy_j()
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": 4})
	_begin(s, "heat")
	_drive(s)
	run_seconds(s, 2.0)
	var h: HazardSim = s.hazards
	check_gt(float(s.drill.heat_added_j), 0.0, "drilling added heat")
	check_eq(s.ship.total_energy_j() - e0, h.energy_in_j - h.energy_out_j, "ship energy change == heat in - heat out, exactly")


func test_segment_length_with_the_drill_bot() -> void:
	var t2 := PackedFloat64Array()
	var t4 := PackedFloat64Array()
	var inside: int = 0
	# The 30 to 65 s window was set at base_speed_m_s 0.85 (D026); it scales with the tuned base speed.
	var k: float = 0.85 / db().tune("drill.base_speed_m_s")
	var lo_s: float = 30.0 * k
	var hi_s: float = 65.0 * k
	for p_seed: int in range(1, 21):
		var s2: Sim = _sim(p_seed, 2)
		_begin(s2, "len", SEG_DEPTH_M, float(p_seed % 7) - 3.0)
		t2.append(_drive(s2))
		if t2[t2.size() - 1] >= lo_s and t2[t2.size() - 1] <= hi_s:
			inside += 1
		var s4: Sim = _sim(p_seed, 4)
		_begin(s4, "len", SEG_DEPTH_M, float(p_seed % 7) - 3.0)
		t4.append(_drive(s4))
	print("DRILL segment seconds at 2 bars: ", t2)
	print("DRILL segment seconds at 4 bars: ", t4)
	check(inside >= 19, "at 2 bars at least 19 of 20 36 m segments take %.0f to %.0f s (got %d)" % [lo_s, hi_s, inside])
	var sum2: float = 0.0
	var sum4: float = 0.0
	for i: int in range(20):
		sum2 += t2[i]
		sum4 += t4[i]
		check_lt(t4[i], t2[i], "seed %d: 4 bars is faster than 2" % (i + 1))
	check_lt(sum4, sum2, "4 bars is faster on average")


func test_zero_bars_does_not_move() -> void:
	var s: Sim = _sim(3, 0)
	_begin(s)
	var p: Vector2 = s.drill.ship_pos
	run_seconds(s, 5.0)
	check_eq(s.drill.ship_pos, p, "no power, no movement")
	check_eq(s.run.phase, "drill", "still drilling")
	check_eq(s.drill.heat_added_j, 0, "no heat without power")


func test_hard_rock_is_slower_than_rock() -> void:
	var speeds: Array[float] = []
	for id: String in ["rock", "hard_rock"]:
		var s: Sim = _sim(4, 2)
		_begin(s)
		_fill_below(s, _code(s, id))
		run_seconds(s, 2.0)
		speeds.append(s.drill.speed_m_s)
	check_gt(speeds[0], 0.0, "rock is drilled")
	check_lt(speeds[1], speeds[0] * 0.5, "hard rock is much slower than rock")


func test_water_pocket_burst_floods_and_breaches_the_drill_room() -> void:
	var s: Sim = _sim(4, 2)
	_begin(s)
	var d: DrillSim = s.drill
	var water: int = _code(s, "water_pocket")
	_fill_below(s, _code(s, "rock"))
	var row: int = ceili((d.ship_pos.y + d.ship_size.y) / d.cell_m - 0.000001) + 2
	var c0: int = floori(d.ship_pos.x / d.cell_m + 0.000001) + 2
	for r: int in range(row, row + 2):
		for c: int in range(c0, c0 + 5):
			d.grid[r * d.cols + c] = water
	var r_drill: Room = room(s, "drill")
	var breach0: float = r_drill.breach_m2
	var cap: int = 60 * 20
	while not has_event(s, "pocket_burst") and cap > 0:
		s.step()
		cap -= 1
	check(has_event(s, "pocket_burst"), "the pocket burst")
	check_gt(r_drill.breach_m2, breach0 + 0.009, "the burst opened a breach in the drill room")
	check_gt(float(r_drill.water_ml), 0.0, "water poured into the drill room")
	run_seconds(s, 4.0)
	var bursts: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == "pocket_burst":
			bursts += 1
			check_eq(int(e["cells"]), 10, "the whole connected pocket is counted")
	check_eq(bursts, 1, "one connected pocket bursts once")
	check_eq(d.mined[water], 10, "all ten water cells were cut")
	check_eq(d.water_in_ml + d.lost_water_ml, 10 * d.water_cell_ml, "every millilitre is booked")
	check_eq(d.water_cell_ml, 750000, "a 0.5 m cell times a 3 m deep room holds 0.75 m3")


func test_bit_wear_change_and_break() -> void:
	var s: Sim = _sim(4, 3)
	_begin(s)
	_fill_below(s, _code(s, "dense_rock"))
	run_seconds(s, 8.0)
	var d: DrillSim = s.drill
	check_gt(d.bit_wear, 0.0, "cutting wears the bit")
	var bits0: int = s.run.get_res("bits")
	s.push({"type": "change_bit"})
	run_seconds(s, 1.0)
	check_eq(s.run.get_res("bits"), bits0 - 1, "a bit was spent")
	var y: float = d.ship_pos.y
	var worn: float = d.bit_wear
	check_eq(d.speed_m_s, 0.0, "drilling stops while the bit is changed")
	run_seconds(s, 4.5)
	check_eq(d.ship_pos.y, y, "no movement during the change")
	check_eq(d.bit_wear, worn, "the old bit stays on until the change is done")
	var cap: int = 120
	while not has_event(s, "bit_changed") and cap > 0:
		s.step()
		cap -= 1
	check(has_event(s, "bit_changed"), "bit_changed was emitted 6 s after the order")
	check_lt(d.bit_wear, 0.001, "the new bit is fresh (one tick of cutting at most)")
	s.run.add(s, "bits", -100)
	s.push({"type": "change_bit"})
	run_seconds(s, 0.5)
	check_eq(d.bit_change_left_s, 0.0, "no bits left: no change")
	d.bit_wear = 0.995
	run_seconds(s, 3.0)
	check(d.bit_broken, "the bit broke at full wear")
	var broken: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == "bit_broken":
			broken += 1
	check_eq(broken, 1, "bit_broken is emitted once")


func test_noise_is_louder_at_four_bars() -> void:
	var per_m: Array[float] = []
	for bars: int in [2, 4]:
		var s: Sim = _sim(4, bars)
		_begin(s)
		_fill_below(s, _code(s, "rock"))
		while s.drill.distance_m < 6.0:
			s.step()
		per_m.append(s.drill.noise_segment / s.drill.distance_m)
		check_eq(s.drill.noise_total, s.drill.noise_segment, "the run total includes the segment")
	check_gt(per_m[1], per_m[0] * 2.0, "4 bars makes far more noise per meter than 2")


func test_heat_at_four_bars_in_hard_rock() -> void:
	var temps: Array[float] = []
	for bars: int in [2, 4]:
		var s: Sim = _sim(4, bars)
		_begin(s)
		_fill_below(s, _code(s, "rock" if bars == 2 else "hard_rock"))
		run_seconds(s, 25.0)
		temps.append(room(s, "drill").temp_c())
	print("DRILL drill room after 25 s: 2 bars in rock %.1f C, 4 bars in hard rock %.1f C" % [temps[0], temps[1]])
	check_lt(temps[0], 45.0, "2 bars in rock keeps the drill room fine")
	check_gt(temps[1], 60.0, "4 bars in hard rock gets the drill room dangerously hot")


func test_replay_of_a_driven_segment() -> void:
	var opts: Dictionary = {"mode": "run"}
	var s := Sim.new(db(), 21, "light_drill", opts)
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": 3})
	s.push({"type": "begin_segment", "segment": "r1", "depth_m": 30.0, "lateral_m": -5.0})
	s.step()
	_drive(s)
	run_seconds(s, 1.0)
	check(has_event(s, "segment_done"), "the segment finished")
	var steers: int = 0
	for c: Dictionary in s.command_log:
		if str(c["type"]) == "steer":
			steers += 1
	check_gt(float(steers), 1.0, "the bot steered")
	var again: Sim = Sim.replay(db(), 21, "light_drill", s.command_log, s.tick, opts)
	check_eq(again.state_hash(), s.state_hash(), "seed, options and command log rebuild the same segment")
	check_eq(again.drill.grid, s.drill.grid, "including every cut cell")


func test_run_mode_segment_returns_to_idle() -> void:
	var s: Sim = _sim(8, 2)
	check_eq(s.run.phase, "idle", "a run starts idle")
	var d0: float = s.run.depth_m
	_begin(s, "n1", 12.0)
	check_eq(s.run.phase, "drill", "begin_segment switches to drilling")
	_begin(s, "n2", 12.0)
	check(has_event(s, "bad_command"), "a second segment cannot start mid-segment")
	_drive(s)
	check_eq(s.run.phase, "idle", "arrival returns to idle")
	check(has_event(s, "segment_done"), "segment_done was emitted")
	check(s.run.depth_m >= d0 + 12.0, "the run went 12 m deeper")
	check_gt(s.ship.rock_temp_c, 40.0, "the rock is warmer deeper down")
	var p: Vector2 = s.drill.ship_pos
	run_seconds(s, 1.0)
	check_eq(s.drill.ship_pos, p, "nothing drills outside the drill phase")


func test_drill_scenario_reaches_the_node() -> void:
	# The scenario's 60 s was set at base_speed_m_s 0.85; scale it to the tuned base speed (plus 10 s),
	# so the test keeps checking that the segment ends and the scenario gets its phase back.
	var d: DataDB = db()
	var sc: Dictionary = d.scenarios["drill_segment"]
	sc["duration_s"] = maxf(float(sc["duration_s"]), ceilf(60.0 * 0.85 / d.tune("drill.base_speed_m_s")) + 10.0)
	var r := ScenarioRun.from_scenario(d, "drill_segment", 1)
	r.play_to_end()
	check(has_event(r.sim, "segment_done"), "the scenario's segment finished within its time")
	check_eq(r.sim.run.phase, "scenario", "a scenario returns to its own phase")


func test_lint_catches_broken_rock_tables() -> void:
	var d: DataDB = db()
	var t: Dictionary = (d.table("rock")["crust"] as Dictionary).duplicate(true)
	var mats: Array = t["materials"]
	(mats[2] as Dictionary)["code"] = 1
	(mats[5] as Dictionary)["yield"] = {"res": "unobtainium", "amount": 1}
	(t["strata"][0] as Dictionary)["material"] = "cheese"
	(t["features"][0] as Dictionary)["material"] = "mithril"
	d.tables["rock"]["broken"] = t
	d.tuning.erase("drill.turn_deg_s")
	var errs := PackedStringArray()
	DrillSim.lint(d, errs)
	var all: String = "\n".join(errs)
	check(all.contains("duplicate code 1"), "a duplicate code is caught")
	check(all.contains("unobtainium"), "a yield naming an unknown resource is caught")
	check(all.contains("cheese"), "a stratum naming a missing material is caught")
	check(all.contains("mithril"), "a feature naming a missing material is caught")
	check(all.contains("drill.turn_deg_s"), "a missing tuning key is caught")
	var clean := PackedStringArray()
	DrillSim.lint(db(), clean)
	check(clean.is_empty(), "the real rock data lints clean: " + " | ".join(clean))


func test_bot_detours_for_ore_and_gems_within_its_noise_budget() -> void:
	var greedy_sum: int = 0
	var plain_sum: int = 0
	for p_seed: int in range(1, 7):
		for greedy: bool in [true, false]:
			var s: Sim = _sim(p_seed, 2)
			_begin(s, "greed", SEG_DEPTH_M, 2.0)
			var bot := DrillBot.new()
			if not greedy:
				bot.noise_budget = -1.0
			while s.drill.active:
				bot.act(s)
				s.step()
			var got: int = s.drill.yielded[RunState.RESOURCES.find("ore")] + s.drill.yielded[RunState.RESOURCES.find("gems")]
			if greedy:
				greedy_sum += got
			else:
				plain_sum += got
	check_gt(float(greedy_sum), float(plain_sum) * 1.5, "detours collect far more ore and gems (%d against %d)" % [greedy_sum, plain_sum])


func test_drill_speed_smoke() -> void:
	var s: Sim = _sim(2, 2)
	var n: int = 0
	for with_bot: bool in [false, true]:
		s = _sim(2, 2)
		_begin(s, "bench", 60.0)
		var bot: Bot = Bot.make("drill" if with_bot else "auto")
		var t0: int = Time.get_ticks_usec()
		n = 0
		while s.drill.active and n < 6000:
			bot.act(s)
			s.step()
			n += 1
		var secs: float = float(Time.get_ticks_usec() - t0) / 1_000_000.0
		print("DRILL bench (%s): %d ticks of a segment in %.3f s = %.0f ticks/s" % ["drill bot" if with_bot else "no bot", n, secs, float(n) / maxf(secs, 0.000001)])
	var t1: int = Time.get_ticks_usec()
	for i: int in range(20):
		s.state_hash()
	print("DRILL state_hash with the grid: %.0f us" % (float(Time.get_ticks_usec() - t1) / 20.0))
	check_gt(float(n), 100.0, "the segment ran")
