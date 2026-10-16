extends TestCase
## The digging economy (M1b, docs/plans/specs/m1b_dig_sim.md): depth windows and richness in the
## rock, survey groups, exact integer yields and the "mined" events, gas pockets, the survey on the
## map (deterministic, and the rock really is what it says), and each gear effect.

const SEG_M: float = 60.0


func _rock() -> Dictionary:
	return db().table("rock")["crust"]


## A segment grid from RockGen alone (no Sim): 64 x 132 cells, the light drill's 8 x 9 m start box.
func _grid(p_seed: int, run_depth: float, survey: Dictionary = {}) -> PackedByteArray:
	var rng := RngStreams.new(p_seed).get_stream("drill/test")
	return RockGen.generate(_rock(), rng, 64, 132, 0.5, Rect2(12.0, 1.0, 8.0, 9.0), 16.0, SEG_M, run_depth, 1.0, 1.0,
			RockGen.options_of(survey))


func _code(id: String) -> int:
	return int(RockGen.codes_of(_rock()).get(id, -1))


func _count(g: PackedByteArray, code: int) -> int:
	var n: int = 0
	for v: int in g:
		if v == code:
			n += 1
	return n


func _sim(p_seed: int, bars: int = 2) -> Sim:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": bars})
	s.step()
	return s


func _begin(s: Sim, seg: String, run_depth: float = 0.0, survey: Dictionary = {}) -> void:
	s.run.depth_m = run_depth
	s.push({"type": "begin_segment", "segment": seg, "depth_m": SEG_M, "lateral_m": 0.0, "survey": survey})
	s.step()


func _fill_below(s: Sim, code: int) -> void:
	var d: DrillSim = s.drill
	var first_row: int = ceili((d.ship_pos.y + d.ship_size.y) / d.cell_m - 0.000001)
	for i: int in range(first_row * d.cols, d.grid.size()):
		d.grid[i] = code
	d._band_dirty = true


func test_depth_windows() -> void:
	var cu: int = _code("copper_ore")
	var ag: int = _code("silver_ore")
	var au: int = _code("gold_ore")
	var em: int = _code("emerald")
	var am: int = _code("amethyst")
	var deep_gold: int = 0
	for p_seed: int in range(1, 13):
		var top: PackedByteArray = _grid(p_seed, 0.0, {"richness": 2.0})
		check_eq(_count(top, cu) + _count(top, ag) + _count(top, au) + _count(top, em) + _count(top, am), 0,
				"seed %d: the first 60 m hold only coal, iron and quartz" % p_seed)
		check_gt(float(_count(top, _code("coal")) + _count(top, _code("iron_ore"))), 0.0, "seed %d: coal and iron from the top" % p_seed)
		var deep: PackedByteArray = _grid(p_seed, 420.0, {"richness": 2.0})
		deep_gold += _count(deep, au)
		# Silver starts at 180 m: in a segment from 150 m it sits only in the lower half.
		var mid: PackedByteArray = _grid(p_seed, 150.0, {"richness": 3.0})
		for i: int in range(mid.size()):
			if mid[i] == ag:
				var depth_here: float = 150.0 + (float(i / 64) + 0.5) * 0.5 - 10.0
				check(depth_here >= 179.0, "seed %d: silver cell at %.1f m, above its window" % [p_seed, depth_here])
	check_gt(float(deep_gold), 0.0, "gold turns up below 360 m")


func test_richness_scales_ore_counts() -> void:
	var poor: int = 0
	var rich: int = 0
	var ore_codes: Array[int] = [_code("coal"), _code("iron_ore"), _code("copper_ore")]
	for p_seed: int in range(1, 31):
		var a: PackedByteArray = _grid(p_seed, 120.0, {"richness": 0.6})
		var b: PackedByteArray = _grid(p_seed, 120.0, {"richness": 1.8})
		for c: int in ore_codes:
			poor += _count(a, c)
			rich += _count(b, c)
	check_gt(float(rich), float(poor) * 2.0, "three times the richness, far more ore (%d against %d)" % [rich, poor])


func test_survey_groups_switch_features() -> void:
	for p_seed: int in range(1, 9):
		var off: PackedByteArray = _grid(p_seed, 200.0, {"gems": [], "gas": false, "water": false})
		for id: String in ["gem", "amethyst", "gas_pocket", "water_pocket"]:
			check_eq(_count(off, _code(id)), 0, "seed %d: no %s when the survey found none" % [p_seed, id])
		var on: PackedByteArray = _grid(p_seed, 200.0, {"gems": ["gem"], "gas": true, "water": true})
		check_gt(float(_count(on, _code("gas_pocket"))), 0.0, "seed %d: gas when the survey found gas" % p_seed)
		check_gt(float(_count(on, _code("gem")) + _count(on, _code("amethyst"))), 0.0, "seed %d: gems when found" % p_seed)


func test_yields_are_exact_integers_and_mined_events_add_up() -> void:
	for p_seed: int in [3, 4, 5]:
		var s: Sim = _sim(p_seed, 3)
		var ore0: int = s.run.get_res("ore")
		var gems0: int = s.run.get_res("gems")
		_begin(s, "dig%d" % p_seed, 300.0, {"richness": 1.9, "gems": ["gem"], "gas": false, "water": true})
		var bot := DrillBot.new()
		bot.max_detour_m = 9.0
		bot.noise_budget = 1000.0
		var cap: int = 60 * 240
		while s.drill.active and cap > 0:
			bot.act(s)
			s.step()
			cap -= 1
		var d: DrillSim = s.drill
		check(not d.active, "seed %d: the segment ended" % p_seed)
		var by_event: Dictionary = {}
		var ev_res: Dictionary = {"ore": 0, "gems": 0}
		var mined_events: int = 0
		for e: Dictionary in s.events:
			if str(e["kind"]) == "mined":
				mined_events += 1
				by_event[str(e["material"])] = int(by_event.get(str(e["material"]), 0)) + int(e["amount"])
			elif str(e["kind"]) == "resource" and (str(e["res"]) == "ore" or str(e["res"]) == "gems"):
				ev_res[str(e["res"])] = int(ev_res[str(e["res"])]) + int(e["amount"])
		var want_ore: int = 0
		var want_gems: int = 0
		for code: int in range(1, DrillSim.MAX_CODES):
			if d.yield_res_of[code] < 0:
				continue
			var want: int = d.mined[code] * d.yield_amount_of[code]
			check_eq(d.yield_mat[code], want, "seed %d: %s pays cells x yield exactly" % [p_seed, d.materials[code]["id"]])
			check_eq(int(by_event.get(str(d.materials[code]["id"]), 0)), want, "seed %d: mined events sum to the yield" % p_seed)
			if RunState.RESOURCES[d.yield_res_of[code]] == "ore":
				want_ore += want
			else:
				want_gems += want
		check_eq(s.run.get_res("ore") - ore0, want_ore, "seed %d: ore added == ore of cut cells" % p_seed)
		check_eq(s.run.get_res("gems") - gems0, want_gems, "seed %d: gems added == gems of cut cells" % p_seed)
		check_eq(int(ev_res["ore"]), want_ore, "seed %d: resource events book the ore" % p_seed)
		check_eq(int(ev_res["gems"]), want_gems, "seed %d: resource events book the gems" % p_seed)
		var done: Dictionary = {}
		for e: Dictionary in s.events:
			if str(e["kind"]) == "segment_done":
				done = e
		check_eq(int(done.get("ore", -1)), want_ore, "seed %d: segment_done ore total" % p_seed)
		check_eq(int(done.get("gems", -1)), want_gems, "seed %d: segment_done gems total" % p_seed)
		var sum_yield: int = 0
		for k: Variant in (done.get("yield", {}) as Dictionary).keys():
			sum_yield += int((done["yield"] as Dictionary)[k])
		check_eq(sum_yield, want_ore + want_gems, "seed %d: segment_done per-material yields add up" % p_seed)
		check_gt(float(want_ore), 0.0, "seed %d: something was mined" % p_seed)
		check_lt(float(mined_events), float(d.mined[0] + 400), "seed %d: mined events stay few (%d)" % [p_seed, mined_events])


func test_gas_pocket_sets_the_drill_room_on_fire() -> void:
	var s: Sim = _sim(4, 2)
	_begin(s, "gas")
	var d: DrillSim = s.drill
	var gas: int = _code("gas_pocket")
	_fill_below(s, _code("rock"))
	var row: int = ceili((d.ship_pos.y + d.ship_size.y) / d.cell_m - 0.000001) + 2
	var c0: int = floori(d.ship_pos.x / d.cell_m + 0.000001) + 2
	for r: int in range(row, row + 2):
		for c: int in range(c0, c0 + 4):
			d.grid[r * d.cols + c] = gas
	var r_drill: Room = room(s, "drill")
	check_eq(r_drill.fire, 0.0, "no fire before")
	var cap: int = 60 * 20
	var noise_before: float = 0.0
	while not has_event(s, "gas_burst") and cap > 0:
		noise_before = d.noise_segment
		s.step()
		cap -= 1
	check(has_event(s, "gas_burst"), "the gas pocket was cut")
	check(r_drill.fire >= 0.3 - 0.0001, "the drill room is burning at 0.3 or more (%.2f)" % r_drill.fire)
	check_gt(d.noise_segment - noise_before, s.db.tune("drill.gas_noise") - 0.001, "a burst of noise")
	run_seconds(s, 4.0)
	var bursts: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == "gas_burst":
			bursts += 1
			check_eq(int(e["cells"]), 8, "the whole connected pocket is counted")
			check_eq(str(e["room"]), "drill", "the drill room burns")
	check_eq(bursts, 1, "one connected pocket ignites once")
	check_eq(d.mined[gas], 8, "all eight gas cells were cut")
	check_eq(d.gas_bursts, 1, "booked once")


func test_survey_is_deterministic_and_is_the_rock() -> void:
	var a := Sim.new(db(), 31, "light_drill", {"mode": "run"})
	var b := Sim.new(db(), 31, "light_drill", {"mode": "run"})
	var c := Sim.new(db(), 32, "light_drill", {"mode": "run"})
	var same: bool = true
	var differs: bool = false
	for i: int in range(a.run.nodes.size()):
		var sa: Dictionary = a.run.nodes[i]["survey"]
		same = same and sa == (b.run.nodes[i]["survey"] as Dictionary)
		if i < c.run.nodes.size():
			differs = differs or sa != (c.run.nodes[i]["survey"] as Dictionary)
		if int(a.run.nodes[i]["row"]) == 0:
			check(sa.is_empty(), "the start has no survey")
			continue
		check(sa.has("tier") and sa.has("ores") and sa.has("gems") and sa.has("gas") and sa.has("water"), "node %d has a full survey" % i)
		if str(a.run.nodes[i]["type"]) == "deposit":
			check(int(sa["tier"]) >= 2, "a deposit is rich or better")
	check(same, "the same seed gives the same surveys")
	check(differs, "another seed gives other surveys")
	# The segment's rock is generated from the reading of the node it leads to.
	var id: String = a.run.links_from_current()[0]
	a.push({"type": "choose_node", "node": id})
	a.step()
	check_eq(a.drill.survey, RockGen.options_of(a.run.node(id)["survey"] as Dictionary), "the drill uses the node's survey")
	var ok_seen: int = 0
	for p_seed: int in range(1, 41):
		var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
		for n: Dictionary in s.run.nodes:
			if str(n["type"]) == "deposit":
				ok_seen += 1
	check_gt(float(ok_seen), 40.0, "deposit nodes appear on most maps (%d in 40)" % ok_seen)


func test_gear_tungsten_and_diamond_heads() -> void:
	var speed := PackedFloat64Array()
	var wear := PackedFloat64Array()
	var hard := PackedFloat64Array()
	for g: String in ["", "tungsten_head", "diamond_head"]:
		for mat: String in ["rock", "hard_rock"]:
			var s: Sim = _sim(4, 2)
			if not g.is_empty():
				Gear.fit(s, g)
			_begin(s, "gear")
			_fill_below(s, _code(mat))
			run_seconds(s, 3.0)
			if mat == "rock":
				speed.append(s.drill.speed_m_s)
				wear.append(s.drill.bit_wear / maxf(s.drill.distance_m, 0.001))
			else:
				hard.append(s.drill.speed_m_s)
	check(absf(speed[1] / speed[0] - 1.25) < 0.01, "tungsten cuts 1.25 times faster (%.3f)" % (speed[1] / speed[0]))
	check(absf(wear[1] / wear[0] - 0.6) < 0.01, "tungsten wears 0.6 as much per meter (%.3f)" % (wear[1] / wear[0]))
	check(absf(speed[2] / speed[0] - 1.5) < 0.01, "diamond cuts 1.5 times faster (%.3f)" % (speed[2] / speed[0]))
	check(absf(wear[2] / wear[0] - 0.35) < 0.01, "diamond wears 0.35 as much per meter (%.3f)" % (wear[2] / wear[0]))
	check(absf(hard[2] / hard[0] - 3.0) < 0.02, "diamond in basalt: 1.5 x speed / 0.5 x hardness = 3 (%.3f)" % (hard[2] / hard[0]))
	check(absf(hard[1] / hard[0] - 1.25) < 0.01, "tungsten does not soften basalt (%.3f)" % (hard[1] / hard[0]))


func test_gear_slots_replace_and_refuse() -> void:
	var s: Sim = _sim(5)
	check_eq(Gear.refusal(s, "tungsten_head"), "", "a first head fits")
	Gear.fit(s, "tungsten_head")
	check(not Gear.refusal(s, "tungsten_head").is_empty(), "the same head twice is refused")
	Gear.fit(s, "diamond_head")
	check_eq(Array(s.run.gear), ["diamond_head"], "the diamond head replaces the tungsten one")
	check_eq(s.run.gear_x("cut_speed_x"), 1.5, "only the fitted head counts")
	check(not Gear.refusal(s, "tungsten_head").is_empty(), "a worse head is refused")
	check(not Gear.refusal(s, "nothing").is_empty(), "unknown gear is refused")


func test_gear_hull_plating() -> void:
	var s: Sim = _sim(5)
	var max0: int = s.ship.hull_max
	s.run.add(s, "hull", -10)
	var hull0: int = s.run.get_res("hull")
	Gear.fit(s, "hull_plating")
	check_eq(s.ship.hull_max, max0 + 5, "plating: +5 maximum hull")
	check_eq(s.run.get_res("hull"), hull0 + 5, "plating: +5 hull")
	Gear.fit(s, "hull_plating")
	check_eq(s.ship.hull_max, max0 + 10, "a second plate stacks")
	check(not Gear.refusal(s, "hull_plating").is_empty(), "two plates at most")


func test_gear_pumps_double_the_pump_rate() -> void:
	var out := PackedInt32Array()
	for g: bool in [false, true]:
		var s: Sim = _sim(6)
		if g:
			Gear.fit(s, "pumps")
		run_seconds(s, 0.5)  # The systems set the pump scale at the hazard rate.
		s.hazards.add_water(room(s, "drill"), 2000000)  # Deep water in both pump rooms: pumps never run dry.
		s.hazards.add_water(room(s, "coolant"), 2000000)
		var w0: int = s.ship.total_water_ml()
		var out0: int = s.hazards.water_out_ml
		run_seconds(s, 1.0)
		check_eq(s.hazards.pump_scale, 2.0 if g else 1.0, "pump scale with%s pumps" % ("" if g else "out"))
		var pumped: int = s.hazards.water_out_ml - out0
		check_eq(w0 - s.ship.total_water_ml(), pumped, "every pumped millilitre is booked as water out")
		out.append(pumped)
	check_gt(float(out[1]), float(out[0]) * 1.95, "the pumps move twice the water (%d against %d)" % [out[1], out[0]])
	check_lt(float(out[1]), float(out[0]) * 2.05, "and not more (%d against %d)" % [out[1], out[0]])
