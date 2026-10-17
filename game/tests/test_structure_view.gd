extends TestCase
## M1c round C part 3: the view of buried structures. The rock view paints timber, steel, crates,
## tape cases and rubble in their own looks and a structure's old air as air; the structure layer lays
## the dark room, glow and lamp and flares at the break-in; a crate opening is a floating text counted in
## the tally; the break-in banner; the scanner's outline, loot colour and legend; the map's marks; and
## the mid-segment store opening over a drill that stays active. The look itself is judged on stills.


func _sim(structure: String, p_seed: int = 11, d: DataDB = null) -> Sim:
	var s := Sim.new(d if d != null else db(), p_seed, "light_drill", {"mode": "run"})
	s.push({"type": "power", "room": "drill", "bars": 0})
	s.push({"type": "power", "room": "bridge", "bars": 2})
	run_seconds(s, 1.0)
	s.push({"type": "begin_segment", "segment": "st", "depth_m": 30.0, "lateral_m": 0.0, "survey": {"structure": structure}})
	s.step()
	return s


func _code(s: Sim, id: String) -> int:
	for c: int in range(s.drill.materials.size()):
		if str(s.drill.materials[c].get("id", "")) == id:
			return c
	return -1


## The first cell of the stamp (row-major) whose material is `id`, as {"c", "r"}, or {} when none.
func _cell(s: Sim, id: String) -> Dictionary:
	var d: DrillSim = s.drill
	var code: int = _code(s, id)
	var cr: Rect2i = d.structures.cell_rect
	for r: int in range(cr.position.y, cr.end.y):
		for c: int in range(cr.position.x, cr.end.x):
			if d.grid[r * d.cols + c] == code:
				return {"c": c, "r": r}
	return {}


## A cell of this material whose whole neighbourhood (8 cells) is old air or empty: where the room is plain.
func _deep_air(s: Sim) -> Dictionary:
	var d: DrillSim = s.drill
	var cr: Rect2i = d.structures.cell_rect
	for r: int in range(cr.position.y + 1, cr.end.y - 1):
		for c: int in range(cr.position.x + 1, cr.end.x - 1):
			var all_air: bool = true
			for dr: int in range(-1, 2):
				for dc: int in range(-1, 2):
					var code: int = d.grid[(r + dr) * d.cols + c + dc]
					if code != 0 and d.interior_of[code] != 1:
						all_air = false
			if all_air:
				return {"c": c, "r": r}
	return {}


func _avg(v: RockView, c: int, r: int) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y: int in range(RockView.CELL_PX):
		for x: int in range(RockView.CELL_PX):
			sum += v._img_a.get_pixel(c * RockView.CELL_PX + x, r * RockView.CELL_PX + y)
	var n: float = float(RockView.CELL_PX * RockView.CELL_PX)
	return Color(sum.r / n, sum.g / n, sum.b / n, sum.a / n)


# The rock view ---------------------------------------------------------------------------------------

func test_built_materials_get_kinds_and_old_air_is_air() -> void:
	var s: Sim = _sim("mine_works")
	var v := RockView.new()
	v.setup(s.drill, 80.0)
	check_eq(int(v._kind[_code(s, "timber")]), RockView.K_TIMBER, "timber has its kind (not fault rock, though it is unstable)")
	check_eq(int(v._kind[_code(s, "rubble")]), RockView.K_RUBBLE, "rubble")
	check_eq(int(v._kind[_code(s, "crate")]), RockView.K_CRATE, "crates")
	check_eq(int(v._kind[_code(s, "steel")]), RockView.K_STEEL, "steel")
	check_eq(int(v._kind[_code(s, "tape_case")]), RockView.K_TAPE, "tape cases")
	check_eq(int(v._air[_code(s, "relic_air")]), 1, "a structure's old air is painted as air")
	check_eq(int(v._air[0]), 1, "air is air")
	check_eq(int(v._air[_code(s, "timber")]), 0, "timber is solid")
	check_eq(int(v._kind[_code(s, "fault_rock")]), 4, "fault rock keeps its look")
	check_eq(RockView.built_kind("rock"), -1, "plain rock is not a built material")
	v.free()


func test_built_materials_paint_their_own_colours() -> void:
	var s: Sim = _sim("soviet_rig")
	var v := RockView.new()
	v.setup(s.drill, 80.0)
	v.paint_all_now()
	var steel: Dictionary = _cell(s, "steel")
	check(not steel.is_empty(), "the rig has steel plates")
	var sc: Color = _avg(v, int(steel["c"]), int(steel["r"]))
	check_gt(sc.a, 0.9, "a steel cell is solid")
	check_gt(sc.b, sc.r, "steel reads cool (blue above red)")
	var air: Dictionary = _deep_air(s)
	check(not air.is_empty(), "the rig has a room")
	check_lt(_avg(v, int(air["c"]), int(air["r"])).a, 0.05, "the room's old air is left clear, not painted as rock")
	var crate: Dictionary = _cell(s, "crate")
	var cc: Color = _avg(v, int(crate["c"]), int(crate["r"]))
	check_gt(cc.r, cc.b * 1.4, "a crate reads warm (tan, red well above blue)")
	v.free()
	var s2: Sim = _sim("mine_works")
	var v2 := RockView.new()
	v2.setup(s2.drill, 80.0)
	v2.paint_all_now()
	var timber: Dictionary = _cell(s2, "timber")
	var tc: Color = _avg(v2, int(timber["c"]), int(timber["r"]))
	check_gt(tc.r, tc.b * 1.5, "timber reads brown (red well above blue)")
	check_gt(tc.r, tc.g, "and not green")
	v2.free()


func test_crates_glint_like_loot() -> void:
	var s: Sim = _sim("mine_works")
	var v := RockView.new()
	v.setup(s.drill, 80.0)
	v.paint_all_now()
	var crate: Dictionary = _cell(s, "crate")
	var ci: int = (int(crate["r"]) / RockView.CELLS) * s.drill.chunk_cols + int(crate["c"]) / RockView.CELLS
	check(v._glints[ci] != null and v._glints[ci].visible, "the chunk holding a crate has a glint layer")
	check(RockView._has_glint(RockView.K_CRATE) and RockView._has_glint(RockView.K_TAPE), "crates and tape cases glint")
	check(not RockView._has_glint(RockView.K_TIMBER), "timber does not")
	v.free()
	var s2: Sim = _sim("crystal_hollow")
	var v2 := RockView.new()
	v2.setup(s2.drill, 80.0)
	check_eq(int(v2._kind[_code(s2, "amethyst")]), 2, "the hollow's amethyst is a gem kind (glints and glows like other gems)")
	check_eq(int(v2._kind[_code(s2, "gem")]), 2, "and its quartz")
	v2.free()


func test_cutting_a_crate_repaints_like_a_fresh_view() -> void:
	var s: Sim = _sim("mine_works")
	var v := RockView.new()
	v.setup(s.drill, 80.0)
	v.paint_all_now()
	var crate: Dictionary = _cell(s, "crate")
	s.drill.take_cell(int(crate["r"]) * s.drill.cols + int(crate["c"]))
	s.step()
	v._process(0.016)
	var guard: int = 0
	while v.pending() > 0 and guard < 4000:
		v._process(0.016)
		guard += 1
	var fresh := RockView.new()
	fresh.setup(s.drill, 80.0)
	fresh.paint_all_now()
	check(v._img_a.get_data() == fresh._img_a.get_data(), "after a crate opened the mosaic equals a fresh paint")
	v.free()
	fresh.free()


# The structure layer ---------------------------------------------------------------------------------

func test_layer_builds_room_and_lamp_and_flares_at_the_break_in() -> void:
	var s: Sim = _sim("mine_works")
	var layer := StructureLayer.new()
	layer.setup(s, 80.0)
	layer._process(0.016)
	var mask: PackedByteArray = StructureLayer.lit_mask(s.drill)
	var want: int = 0
	for v: int in mask:
		want += v
	check_gt(float(want), 20.0, "the mine works has a room")
	check_eq(layer.lit_cells, want, "the layer draws exactly the old-air cells")
	check(layer.lamp.enabled, "the lamp is on while there is a structure")
	check(not layer.entered, "sealed at first")
	var before: float = layer.lamp_energy
	check_eq(StructureLayer.lamp_at(false, 0.0), StructureLayer.LAMP_BEFORE, "sealed lamp")
	var air: Dictionary = _cell(s, "relic_air")
	s.drill.take_cell(int(air["r"]) * s.drill.cols + int(air["c"]))
	s.step()
	layer._process(0.016)
	check(layer.entered, "the break-in is seen")
	check_gt(layer.lamp_energy, before * 3.0, "the lamp flares at the break-in")
	for i: int in range(150):
		layer._process(0.016)
	check_gt(layer.lamp_energy, before * 2.0, "and settles brighter than before")
	check_lt(layer.lamp_energy, StructureLayer.LAMP_FLARE * 0.7, "below the flare")
	check_gt(layer.glow_level, StructureLayer.GLOW_BEFORE * 1.5, "the glow comes up")
	var cut: PackedByteArray = StructureLayer.lit_mask(s.drill)
	var after: int = 0
	for v2: int in cut:
		after += v2
	check_eq(after, want, "cutting one old-air cell leaves it lit (it is air either way)")
	layer.free()


func test_layer_without_a_structure_is_dark() -> void:
	var s: Sim = _sim("")
	var layer := StructureLayer.new()
	layer.setup(s, 80.0)
	layer._process(0.016)
	check(not layer.lamp.enabled, "no structure, no lamp")
	check_eq(layer.lit_cells, 0, "no room")
	layer.free()


func test_room_images_are_smooth_masks() -> void:
	var lit := PackedByteArray([0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0])
	var imgs: Array[Image] = StructureLayer.room_images(lit, 4, 3)
	check_eq(imgs[0].get_width(), (4 + 2) * StructureLayer.CELL_PX, "one cell of margin each side")
	check_eq(imgs[0].get_height(), (3 + 2) * StructureLayer.CELL_PX, "and in height")
	var mid: Color = imgs[0].get_pixel(2 * StructureLayer.CELL_PX + 4, 2 * StructureLayer.CELL_PX + 4)
	check_gt(mid.a, 0.8, "inside the room the mask is solid")
	check_lt(imgs[0].get_pixel(1, 1).a, 0.01, "outside it is clear")
	check_gt(imgs[1].get_pixel(2 * StructureLayer.CELL_PX + 4, 2 * StructureLayer.CELL_PX + 4).r, 0.1, "the glow is warm inside")


# Crates, the tally and the banner --------------------------------------------------------------------

func test_a_crate_opening_is_a_floating_text_counted_in_the_tally() -> void:
	var s: Sim = _sim("mine_works")
	var dl := DigLog.new()
	dl.bind(s)
	s.emit("loot", {"structure": "mine_works", "res": "coolant", "amount": 4, "x_m": 16.25, "y_m": 16.75})
	s.emit("loot", {"structure": "mine_works", "res": "", "amount": 0, "x_m": 18.25, "y_m": 16.75})
	dl.update(s, 0.0)
	check_eq(dl.crates, 2, "two crates counted")
	check_eq(int(dl.loot.get("coolant", 0)), 4, "the loot is totalled by resource")
	check_eq(dl.pickups.size(), 2, "each crate is a floating text")
	check_eq(DigLog.pickup_text(dl.pickups[0]), "CRATE: +4 COOLANT", "it says what the crate paid")
	check_eq(DigLog.pickup_text(dl.pickups[1]), "CRATE: EMPTY", "an empty crate says so")
	check(bool(dl.pickups[0]["abs"]), "it starts on the crate, not at the crown")
	check_eq(int(dl.pickups[0]["slot"]), 0, "the first crate text sits on its crate")
	check_eq(int(dl.pickups[1]["slot"]), 1, "the second is stacked above, so neighbours do not overprint")
	check_eq(float(dl.pickups[0]["y_m"]), 16.75, "at the crate's own position")
	check_gt(float(DigLog.pickup_size(dl.pickups[0])), 28.0, "bigger than a plain ore text")
	s.emit("segment_done", {"segment": "st", "time_s": 5.0, "distance_m": 14.0, "mined": {}, "yield": {}, "ore": 0, "gems": 0,
			"gas_bursts": 0, "structure": "mine_works", "entered": true, "crates": 2})
	dl.update(s, 0.0)
	check_eq(int(dl.toast.get("crates", -1)), 2, "the arrival summary carries the crates")
	check_eq(str(dl.toast.get("structure", "")), "mine_works", "and the structure")
	check_eq(int((dl.toast.get("loot", {}) as Dictionary).get("coolant", 0)), 4, "and the loot")
	var line: String = DigTally.structure_line(dl.toast)
	check(line.contains("OLD MINE WORKS") and line.contains("BROKEN INTO") and line.contains("CRATES 2/"), "the toast line names it: " + line)
	check_eq(DigTally.structure_line({"structure": ""}), "", "no structure, no line")


func test_tally_counts_crates_while_drilling() -> void:
	var s: Sim = _sim("mine_works")
	check_eq(DigTally.crates_text(s), "crates 0/%d" % s.drill.structures.crates_total, "crates opened over total")
	check_eq(DigTally.crates_text(_sim("crystal_hollow")), "", "a hollow has no crates: nothing to count")
	check_eq(DigTally.crates_text(_sim("")), "", "no structure: nothing to count")


func test_banner_shows_the_label_and_waits_out_an_overlay() -> void:
	var s: Sim = _sim("soviet_rig")
	var b := StructureBanner.new()
	b.bind(s)
	check(not b.is_showing(), "nothing before a break-in")
	s.emit("structure_entered", {"structure": "soviet_rig", "label": "SOVIET RIG MODULE"})
	b._process(0.1)
	check(b.is_showing(), "the break-in shows the plaque")
	check_eq(b.label, "SOVIET RIG MODULE", "with the label")
	var covered: Array = [true]
	b.hide_when = func() -> bool: return bool(covered[0])
	var age: float = b.age
	b._process(3.0)
	check_eq(b.age, age, "its clock stops while an overlay covers the world")
	covered[0] = false
	b._process(StructureBanner.SHOW_S)
	check(not b.is_showing(), "and it goes after its time")
	check_eq(StructureBanner.radio_line(s, "soviet_rig", "st"), StructureBanner.radio_line(s, "soviet_rig", "st"), "the TOPSIDE line is chosen without randomness")
	var lines: PackedStringArray = StructureBanner.wrap("one two three four five six seven eight nine ten", 17, 120.0, 2)
	check(lines.size() <= 2 and lines.size() >= 1, "a long line wraps to at most two")
	b.free()


# Scanner and map -------------------------------------------------------------------------------------

func test_scanner_shows_the_outline_and_loot() -> void:
	var s: Sim = _sim("mine_works")
	var sc: ScannerPanel = ScannerPanel.build(Control.new(), s)
	sc._refresh_image()
	check_eq(sc._kind[_code(s, "crate")], ScannerPanel.K_LOOT, "crates are loot on the glass")
	check_eq(sc._kind[_code(s, "tape_case")], ScannerPanel.K_LOOT, "and tape cases")
	check_eq(sc._kind[_code(s, "relic_air")], ScannerPanel.K_VOID, "old air is a void")
	check_eq(sc._kind[_code(s, "timber")], ScannerPanel.K_FAULT, "timber props hatch like fault rock (they are unstable)")
	check(ScannerPanel.cell_color(ScannerPanel.K_LOOT, 0.4, 1, 1).r > 0.9, "loot is amber")
	var screen: Rect2 = ScannerPanel.SCREEN
	var box: Rect2 = ScannerExtras.structure_box(s, screen, ScannerPanel.LOOK_AHEAD_M)
	check_gt(box.size.x, 10.0, "the mine works is in range of a 30 m look")
	check(screen.encloses(box), "and clipped to the screen")
	var near: Rect2 = ScannerExtras.structure_box(s, screen, 3.0)
	check(near.size.x <= 0.0 or near.size.y <= 0.0 or screen.encloses(near), "out of a short look it is gone or clipped")
	var s2: Sim = _sim("")
	check_eq(ScannerExtras.structure_box(s2, screen, ScannerPanel.LOOK_AHEAD_M), Rect2(), "a segment without one draws no outline")
	sc.free()


func test_map_marks_name_the_structure() -> void:
	var d: DataDB = db()
	var info: Dictionary = SurveyMarks.material_info(d, "crust")
	var sv: Dictionary = {"tier": 1, "tier_name": "fair", "ores": [], "gems": [], "gas": false, "water": false, "faults": false, "structure": "mine_works"}
	check_eq(SurveyMarks.structure_label(sv, info), "OLD MINE WORKS", "the label comes from the structure data")
	var w: PackedStringArray = SurveyMarks.words(sv, 3, info, false)
	check_eq(w[w.size() - 1], "BURIED: OLD MINE WORKS", "the tooltip says what is buried")
	sv["structure"] = ""
	check_eq(SurveyMarks.words(sv, 3, info, false).size(), 4, "no structure, no extra line")
	check_eq(SurveyMarks.structure_label({}, info), "", "no reading, no label")


# The mid-segment store -------------------------------------------------------------------------------

func test_the_trader_opens_over_a_live_drill_and_the_rock_stays() -> void:
	var d0: DataDB = db()
	(d0.table("structures")["crystal_hollow"] as Dictionary)["trader_chance"] = 1.0
	var s: Sim = _sim("crystal_hollow", 11, d0)
	var rv := RockView.new()
	rv.setup(s.drill, 80.0)
	var store: StoreView = StoreView.build(Control.new(), s)
	var air: Dictionary = _cell(s, "relic_air")
	s.drill.take_cell(int(air["r"]) * s.drill.cols + int(air["c"]))
	s.step()
	check(store.is_open(), "the store is open over the drilling view")
	check(s.drill.active, "the drill stays active under it")
	check_eq(rv.serial, s.drill.grid_serial, "so the rock view keeps its rock (no rebuild, the camera stays)")
	var sc: ScannerPanel = ScannerPanel.build(Control.new(), s)
	check(not sc.is_live(), "the scanner has no signal while the store is open")
	s.push({"type": "leave"})
	s.step()
	check(not store.is_open(), "leaving closes it")
	check_eq(s.run.phase, "drill", "and the dig resumes")
	check_eq(rv.serial, s.drill.grid_serial, "on the same rock")
	check(sc.is_live(), "and the scanner is back")
	rv.free()
	sc.free()
