extends TestCase
## The dig view's event follower and the helpers behind the pickups, the tally, the scanner colours, the
## map's survey marks and the store's gear lines (M1b round 3b). Nothing here draws.


func _drilling_sim() -> Sim:
	var s := Sim.new(db(), 5, "light_drill", {"mode": "run"})
	s.push({"type": "begin_segment", "segment": "dl", "depth_m": 40.0, "lateral_m": 0.0})
	s.step()
	return s


func _mined(s: Sim, mat: String, res: String, amount: int) -> void:
	s.emit("mined", {"material": mat, "res": res, "amount": amount, "x_m": 10.0, "y_m": 12.0})


func test_mined_events_become_merged_pickups_and_a_tally() -> void:
	var s: Sim = _drilling_sim()
	var dl := DigLog.new()
	dl.bind(s)
	_mined(s, "iron_ore", "ore", 2)
	_mined(s, "iron_ore", "ore", 2)
	_mined(s, "emerald", "gems", 5)
	dl.update(s, 0.0)
	check_eq(dl.pickups.size(), 2, "two cuts of the same ore merge into one text")
	check_eq(DigLog.pickup_text(dl.pickups[0]), "+4 IRON", "the merged text adds the amounts")
	check_eq(DigLog.pickup_text(dl.pickups[1]), "+5 EMERALD", "a gem has its own text")
	check_eq(dl.ore, 4, "the tally counts ore")
	check_eq(dl.gems, 5, "the tally counts gems")
	check_eq(dl.tally_text(), "THIS DIG  iron 4  emerald 5  = +4 ore +5 gems", "the tally line reads as the spec says")
	check_gt(float(DigLog.pickup_size(dl.pickups[1])), float(DigLog.pickup_size(dl.pickups[0])), "gems are drawn larger than iron")


func test_pickups_fade_and_a_new_segment_resets_the_tally() -> void:
	var s: Sim = _drilling_sim()
	var dl := DigLog.new()
	dl.bind(s)
	_mined(s, "coal", "ore", 1)
	dl.update(s, 0.0)
	dl.update(s, DigLog.MERGE_S + 0.1)
	_mined(s, "coal", "ore", 1)
	dl.update(s, 0.0)
	check_eq(dl.pickups.size(), 2, "after the merge window a new text starts")
	dl.update(s, DigLog.LIFE_S)
	check(dl.pickups.is_empty(), "texts expire")
	check_eq(dl.ore, 2, "the tally outlives the texts")
	s.emit("segment_begin", {"segment": "next"})
	dl.update(s, 0.0)
	check_eq(dl.ore, 0, "a new segment starts a new tally")
	check(dl.totals.is_empty(), "no materials yet")


func test_segment_done_builds_a_toast_that_times_out() -> void:
	var s: Sim = _drilling_sim()
	var dl := DigLog.new()
	dl.bind(s)
	s.emit("segment_done", {"segment": "dl", "time_s": 51.2, "distance_m": 60.0, "yield": {"coal": 4, "iron_ore": 14}, "ore": 18, "gems": 0, "gas_bursts": 1})
	dl.update(s, 0.0)
	check_eq(int(dl.toast.get("ore", -1)), 18, "the toast carries the ore")
	check_eq(int(dl.toast["gas_bursts"]), 1, "and the gas bursts")
	check_eq(DigLog.summary_line(dl.toast), "+18 ORE  +0 GEMS", "the one-line summary")
	check_eq(int(DigLog.last_summary(s)["ore"]), 18, "the map finds the newest arrival in the dl")
	dl.update(s, DigLog.TOAST_S + 0.1)
	check(dl.toast.is_empty(), "the toast goes away")
	check_eq(DigLog.summary_line({"ore": 0, "gems": 0}), "NOTHING WORTH TAKING", "an empty dig says so")


func test_binding_ignores_old_events() -> void:
	var s: Sim = _drilling_sim()
	_mined(s, "gold_ore", "ore", 12)
	var dl := DigLog.new()
	dl.bind(s)
	dl.update(s, 0.0)
	check(dl.pickups.is_empty(), "events from before the bind are history")


func test_pickup_colours_stay_readable_and_names_are_short() -> void:
	var coal: Color = DigLog.readable(Color.html("#1b1a1c"))
	check_gt(coal.r * 0.3 + coal.g * 0.59 + coal.b * 0.11, 0.4, "coal text is lifted off the dark rock")
	var gold: Color = Color.html("#f2c431")
	check_eq(DigLog.readable(gold), gold, "a bright colour is left alone")
	check_eq(DigLog.short_name("gem"), "QUARTZ", "the plain gem is quartz")
	check_eq(DigLog.short_name("silver_ore"), "SILVER", "ore suffixes are dropped")


func test_scanner_tints_keep_ore_hues_and_lift_coal() -> void:
	var iron: Color = ScannerPanel.scan_tint(Color.html("#9c4a2a"), ScannerPanel.K_ORE)
	var gold: Color = ScannerPanel.scan_tint(Color.html("#f2c431"), ScannerPanel.K_ORE)
	var coal: Color = ScannerPanel.scan_tint(Color.html("#1b1a1c"), ScannerPanel.K_ORE)
	check(iron.r > iron.b, "iron stays warm")
	check(gold.r > gold.b and gold.g > gold.b, "gold stays yellow")
	check_gt(coal.g, 0.35, "coal is visible on the screen")
	check_eq(ScannerPanel.scan_tint(Color.html("#6e6152"), ScannerPanel.K_ROCK), Color.WHITE, "rock keeps its own look")
	var gas: Color = ScannerPanel.cell_color(ScannerPanel.K_GAS, 0.5, 1, 1, ScannerPanel.scan_tint(Color.html("#b4c23a"), ScannerPanel.K_GAS))
	var water: Color = ScannerPanel.cell_color(ScannerPanel.K_WATER, 0.6, 1, 1)
	check(gas.g > gas.b + 0.2 and water.b > water.g + 0.2, "gas is yellow-green and water is blue")


func test_survey_marks_pips_and_words() -> void:
	var d: DataDB = db()
	var info: Dictionary = SurveyMarks.material_info(d, "crust")
	check(info.has("iron_ore") and info.has("emerald"), "the rock table gives names and colours")
	var sv: Dictionary = {"tier": 1, "tier_name": "fair", "richness": 1.0, "ores": ["coal", "iron_ore"], "gems": ["amethyst"], "gas": true, "water": false}
	check_eq(SurveyMarks.pips(sv, 3), Vector2i(2, 3), "tier 1 of 3 tiers is two pips filled")
	var w: PackedStringArray = SurveyMarks.words(sv, 3, info, true)
	check(w[0].begins_with("RICH DEPOSIT: FAIR ROCK"), "a deposit says so")
	check(w[1].contains("COAL") and w[1].contains("IRON"), "the ores are named")
	check(w[2].contains("AMETHYST"), "the gems are named")
	check(w[3].contains("GAS") and not w[3].contains("WATER"), "only the gas is listed")
	check_eq(SurveyMarks.words({}, 3, info, false).size(), 0, "no reading, no words")


func test_map_tooltip_adds_the_survey_for_revealed_nodes_only() -> void:
	var s := Sim.new(db(), 7, "light_drill", {"mode": "run"})
	s.step()
	var m := MapView.new()
	m.bind(s)
	var first: Dictionary = s.run.node(s.run.links_from_current()[0])
	var d: PackedStringArray = m.describe(first)
	check(d.size() >= 7, "a revealed node adds the survey lines")
	var far: Dictionary = s.run.nodes[s.run.nodes.size() - 1]
	check_eq(m.describe(far).size(), 3, "an unsurveyed node keeps the plain tooltip")
	m.free()


func test_store_gear_lines_say_what_they_do() -> void:
	var s := Sim.new(db(), 9, "light_drill", {"mode": "run"})
	check_eq(StoreView.gear_effects(s.db, "tungsten_head"), "CUT +25%  WEAR -40%", "tungsten head effects")
	check_eq(StoreView.gear_effects(s.db, "diamond_head"), "CUT +50%  WEAR -65%  HARD ROCK -50%", "diamond head effects")
	check_eq(StoreView.gear_effects(s.db, "pumps"), "PUMPS x2.0", "pumps effects")
	check_eq(StoreView.gear_effects(s.db, "hull_plating"), "+5 HULL", "plating effects")
	check_eq(StoreView.gear_replaces(s, "diamond_head"), "", "nothing to replace on a fresh ship")
	Gear.fit(s, "tungsten_head")
	check_eq(StoreView.gear_replaces(s, "diamond_head"), "REPLACES TUNGSTEN DRILL HEAD", "the diamond head takes over the tungsten one")
	check_eq(StoreView.gear_replaces(s, "tungsten_head"), "", "the same tier replaces nothing")


func test_ore_and_gems_get_a_plainly_visible_wash_in_the_main_view() -> void:
	# The wash layer (RockView._ore_fill) is what shows veins and pockets in the drilling view, not
	# only on the scanner: every ore and gem cell must come out bright enough to see on dark rock,
	# even coal (whose own colour hint is almost black).
	var s := Sim.new(db(), 3, "light_drill", {"mode": "run"})
	s.push({"type": "begin_segment", "segment": "wash", "depth_m": 60.0, "lateral_m": 0.0})
	s.step()
	var v := RockView.new()
	v.setup(s.drill, 80.0)
	v.paint_all_now()
	var d: DrillSim = s.drill
	var seen: Dictionary = {}
	var worst: float = 1.0
	var cells: int = 0
	for r: int in range(d.rows):
		for c: int in range(d.cols):
			var code: int = d.grid[r * d.cols + c]
			if d.yield_res_of[code] < 0:
				continue
			var idx: int = (r / RockView.CELLS) * d.chunk_cols + c / RockView.CELLS
			var tex: ImageTexture = v._gtex[idx]
			check(tex != null, "a chunk with ore has a wash layer")
			if tex == null:
				continue
			var px: Color = tex.get_image().get_pixel((c % RockView.CELLS) * RockView.CELL_PX + 4, (r % RockView.CELLS) * RockView.CELL_PX + 4)
			var lum: float = (px.r + px.g + px.b) / 3.0
			worst = minf(worst, lum)
			seen[str(d.material(code).get("id", ""))] = true
			cells += 1
	check_gt(float(cells), 20.0, "the segment has ore to look at")
	check_gt(worst, 0.18, "even the dimmest ore cell is clearly lit (%d cells, kinds %s)" % [cells, str(seen.keys())])
	v.free()
