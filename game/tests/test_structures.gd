extends TestCase
## M1c round C: buried structures (game/sim/drill/drill_structures.gd, structure_stamp.gd,
## structure_lint.gd; docs/plans/specs/m1c_structures.md). Stamps and their lint, placement,
## crates (exactly one loot roll, paid once), the break-in (once, with its codex entry), the
## mid-segment store and event going back to "drill", and the survey's structure reading.
## Conserved quantities are checked with exact equality.


## A run-mode sim on light_drill with the drill at drill_bars, a second in.
func _sim(d: DataDB = null, p_seed: int = 11, drill_bars: int = 3) -> Sim:
	var s := Sim.new(d if d != null else db(), p_seed, "light_drill", {"mode": "run"})
	s.push({"type": "power", "room": "drill", "bars": drill_bars})
	s.push({"type": "power", "room": "bridge", "bars": 2})
	run_seconds(s, 1.0)
	return s


func _begin(s: Sim, structure: String, depth: float = 36.0, segment: String = "st") -> void:
	s.push({"type": "begin_segment", "segment": segment, "depth_m": depth, "lateral_m": 0.0,
		"survey": {"structure": structure}})
	s.step()


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


## The first cell (row-major) inside the placed stamp with this mark and, if code >= 0, this material.
func _find(s: Sim, mark: int, code: int = -1) -> int:
	var d: DrillSim = s.drill
	var cr: Rect2i = d.structures.cell_rect
	for r: int in range(cr.position.y, cr.end.y):
		for c: int in range(cr.position.x, cr.end.x):
			var i: int = r * d.cols + c
			if d.structure_marks[i] == mark and (code < 0 or d.grid[i] == code):
				return i
	return -1


func _code(s: Sim, id: String) -> int:
	return int(RockGen.codes_of(s.db.table("rock")["crust"]).get(id, -1))


func _res_total(s: Sim) -> Dictionary:
	var out: Dictionary = {}
	for r: String in RunState.RESOURCES:
		out[r] = s.run.get_res(r)
	return out


## Steer the crown toward a point (heading from the crown, clamped) and drill until `until` is true
## or the time runs out. Returns whether it happened.
func _drive_to(s: Sim, p: Vector2, kind: String, seconds: float) -> bool:
	for i: int in range(roundi(seconds * Sim.TICK_HZ)):
		if _count(s, kind) > 0:
			return true
		if s.run.phase != "drill":
			return false
		if i % 6 == 0:
			var d: DrillSim = s.drill
			var crown := Vector2(d.ship_pos.x + d.ship_size.x * 0.5, d.ship_pos.y + d.ship_size.y)
			var want: float = rad_to_deg(atan2(p.x - crown.x, maxf(p.y - crown.y, 0.5)))
			s.push({"type": "steer", "angle": clampf(want, -90.0, 90.0)})
		s.step()
	return _count(s, kind) > 0


# Data and lint ------------------------------------------------------------------------------------

func test_real_structures_lint_clean() -> void:
	var d: DataDB = db()
	var errs := PackedStringArray()
	StructureLint.lint(d, errs)
	check(errs.is_empty(), "structure lint: " + " | ".join(errs))
	var errs2 := PackedStringArray()
	Encounter.lint(d, errs2)
	check(errs2.is_empty(), "encounter lint: " + " | ".join(errs2))
	for id: String in ["mine_works", "soviet_rig", "crystal_hollow"]:
		check(d.table("structures").has(id), "structure %s is loaded" % id)
	check(d.table("stores").has("hollow_trader"), "the hollow trader is loaded")
	for id: String in ["old_workings", "rig_module", "the_hollows"]:
		check(d.table("codex").has(id), "codex %s is loaded" % id)


func _lint_errs(def: Dictionary) -> String:
	var d: DataDB = db()
	var errs := PackedStringArray()
	StructureLint.lint_one(d, def, d.table("rock")["crust"], "test.json", errs)
	return " | ".join(errs)


func _good_def() -> Dictionary:
	return {"id": "t", "name": "T", "label": "T", "codex": "old_workings",
		"legend": {"#": "steel", ".": "relic_air", "c": "crate"}, "stamp": ["####", "#.c#", "####"],
		"mirror": true, "loot": [{"weight": 1, "res": "ore", "amount": 5}], "event_chance": 0.5, "trader": "",
		"trader_chance": 0.0}


func test_stamp_lint_catches_bad_stamps() -> void:
	check_eq(_lint_errs(_good_def()), "", "a good stamp lints clean")
	var bad_char: Dictionary = _good_def()
	bad_char["stamp"] = ["####", "#.x#", "####"]
	check(_lint_errs(bad_char).contains("not in the legend"), "a char outside the legend is caught")
	var ragged: Dictionary = _good_def()
	ragged["stamp"] = ["####", "#.c", "####"]
	check(_lint_errs(ragged).contains("rows must be equal"), "ragged rows are caught")
	var unknown: Dictionary = _good_def()
	unknown["legend"] = {"#": "unobtainium", ".": "relic_air", "c": "crate"}
	check(_lint_errs(unknown).contains("not in the rock table"), "an unknown material is caught")
	var no_loot: Dictionary = _good_def()
	no_loot["loot"] = [{"weight": 1, "res": "hull", "amount": 5}]
	check(_lint_errs(no_loot).contains("other than hull"), "hull is not loot")
	var shut: Dictionary = _good_def()
	shut["stamp"] = ["####", "####"]
	check(_lint_errs(shut).contains("no interior"), "a stamp without an interior is caught")
	var touching: Dictionary = _good_def()
	touching["legend"] = {"#": "steel", ".": "relic_air", "c": "crate", "p": "tape_case"}
	touching["stamp"] = ["#####", "#.cp#", "#####"]
	check(_lint_errs(touching).contains("touch"), "crates of two kinds touching are caught")
	var chance: Dictionary = _good_def()
	chance["trader_chance"] = 0.5
	check(_lint_errs(chance).contains("needs a trader"), "a trader chance needs a store")


func test_structure_event_lint() -> void:
	var d: DataDB = db()
	var ev: Dictionary = (d.table("events")["mine_cage"] as Dictionary).duplicate(true)
	ev["id"] = "zz_fight"
	ev["structures"] = ["mine_works", "nowhere"]
	var pages: Dictionary = ev["pages"]
	var opts: Array = (pages["intro"] as Dictionary)["options"]
	((opts[1] as Dictionary)["outcomes"] as Array)[0] = {"weight": 1, "effects": [{"type": "fight", "enemy": "rival_light"}]}
	d.table("events")["zz_fight"] = ev
	var errs := PackedStringArray()
	Encounter.lint(d, errs)
	var all: String = " | ".join(errs)
	check(all.contains("cannot start a fight"), "a structure event may not start a fight: " + all)
	check(all.contains("\"nowhere\" does not exist"), "its structures must exist: " + all)


# Placement ----------------------------------------------------------------------------------------

func test_placement_is_deterministic_inside_the_grid_and_mirrored_by_seed() -> void:
	var mirrors: Dictionary = {}
	for sd: int in range(1, 13):
		var a: Sim = _sim(null, sd)
		_begin(a, "soviet_rig")
		var b: Sim = _sim(null, sd)
		_begin(b, "soviet_rig")
		var d: DrillSim = a.drill
		check_eq(d.structures.id, "soviet_rig", "seed %d: the rig is placed" % sd)
		check_eq(d.grid, b.drill.grid, "seed %d: the same seed gives the same rock" % sd)
		check_eq(d.structures.rect, b.drill.structures.rect, "seed %d: and the same place" % sd)
		var r: Rect2 = d.structures.rect
		var grid_w: float = float(d.cols) * d.cell_m
		check(r.position.x >= 0.0 and r.end.x <= grid_w + 0.0001, "seed %d: inside the grid sideways (%s)" % [sd, r])
		check(r.end.y <= float(d.rows) * d.cell_m + 0.0001, "seed %d: above the grid bottom" % sd)
		check(r.position.y >= d.start_y + d.ship_size.y + d.cell_m - 0.0001, "seed %d: a cell clear below the shaft" % sd)
		mirrors[d.structures.mirrored] = true
		# The stamp is in the rock cell for cell (mirrored when the seed says so).
		var def: Dictionary = d.structures.def
		var stamp: Array = def["stamp"]
		var legend: Dictionary = def["legend"]
		var cr: Rect2i = d.structures.cell_rect
		var wrong: int = 0
		for y: int in range(cr.size.y):
			var line: String = stamp[y]
			for x: int in range(cr.size.x):
				var ch: String = line[cr.size.x - 1 - x] if d.structures.mirrored else line[x]
				if ch != " " and d.grid[(cr.position.y + y) * d.cols + cr.position.x + x] != _code(a, str(legend[ch])):
					wrong += 1
		check_eq(wrong, 0, "seed %d: every stamp cell holds its legend material" % sd)
		check_eq(d.structures.crates_total, 4, "seed %d: the rig holds three crates and a tape case" % sd)
		check(d.structures.interior.size.x > 0.0 and r.encloses(d.structures.interior), "seed %d: interior inside the stamp" % sd)
	check(mirrors.has(true) and mirrors.has(false), "some seeds mirror the stamp and some do not")


func test_no_structure_leaves_the_rock_as_before() -> void:
	var a: Sim = _sim()
	a.push({"type": "begin_segment", "segment": "st", "depth_m": 36.0, "lateral_m": 0.0})
	a.step()
	var b: Sim = _sim()
	_begin(b, "")
	check_eq(a.drill.grid, b.drill.grid, "a survey without a structure gives the same rock as no survey key")
	check(not a.drill.structures.has_structure(), "nothing placed")
	check_eq(_count(a, "structure_placed"), 0, "no structure_placed event")


# Crates and break-in -------------------------------------------------------------------------------

func test_a_crate_pays_exactly_one_roll_once() -> void:
	var s: Sim = _sim(null, 11, 0)
	_begin(s, "soviet_rig")
	var d: DrillSim = s.drill
	var crate: int = _find(s, StructureStamp.MARK_INTERIOR, _code(s, "crate"))
	check(crate >= 0, "the rig has a crate cell")
	var before: Dictionary = _res_total(s)
	d.take_cell(crate)
	s.step()
	check_eq(_count(s, "loot"), 1, "one loot event for the first cut cell")
	var loot: Dictionary = _last(s, "loot")
	check_eq(str(loot["structure"]), "soviet_rig", "the loot names the structure")
	var res: String = str(loot["res"])
	var amount: int = int(loot["amount"])
	var ok_row: bool = false
	for row: Variant in (d.structures.def["loot"] as Array):
		if str((row as Dictionary)["res"]) == res and int((row as Dictionary)["amount"]) == amount:
			ok_row = true
	check(ok_row, "the payout is one row of the rig's loot table (%s %d)" % [res, amount])
	var after: Dictionary = _res_total(s)
	for r: String in RunState.RESOURCES:
		check_eq(int(after[r]), int(before[r]) + (amount if r == res else 0), "%s changed by exactly the roll" % r)
	check_eq(d.structures.loot_res[RunState.RESOURCES.find(res)], amount, "the segment counts the loot")
	# The rest of the same crate is already opened: cutting it pays nothing more.
	var cr: Rect2i = d.structures.cell_rect
	var more: int = 0
	for r: int in range(cr.position.y, cr.end.y):
		for c: int in range(cr.position.x, cr.end.x):
			var i: int = r * d.cols + c
			if d.grid[i] == _code(s, "crate") and d.burst_marks[i] == 1:
				d.take_cell(i)
				more += 1
	s.step()
	check_eq(more, 3, "the crate's other three cells were marked open by the first cut")
	check_eq(_count(s, "loot"), 1, "cutting the rest of the crate pays nothing more")
	check_eq(d.structures.crates_opened, 1, "one crate opened")


func test_tape_case_pays_its_own_table() -> void:
	var s: Sim = _sim(null, 11, 0)
	_begin(s, "soviet_rig")
	var tape: int = _find(s, StructureStamp.MARK_INTERIOR, _code(s, "tape_case"))
	check(tape >= 0, "the rig has a sealed tape case")
	var cells0: int = s.run.get_res("cells")
	s.drill.take_cell(tape)
	s.step()
	var loot: Dictionary = _last(s, "loot")
	check_eq(str(loot.get("res", "")), "cells", "the tape case pays cells")
	check_eq(int(loot.get("amount", 0)), 3, "three of them")
	check_eq(s.run.get_res("cells") - cells0, 3, "exactly three cells were added")


func test_break_in_fires_once_and_learns_the_codex() -> void:
	var d0: DataDB = db()
	(d0.table("structures")["soviet_rig"] as Dictionary)["event_chance"] = 0.0
	var s: Sim = _sim(d0, 11, 0)
	_begin(s, "soviet_rig")
	check(not s.run.knows("rig_module"), "the rig's codex entry is not known yet")
	var air: int = _find(s, StructureStamp.MARK_INTERIOR, _code(s, "relic_air"))
	s.drill.take_cell(air)
	s.step()
	check_eq(_count(s, "structure_entered"), 1, "one break-in")
	check_eq(str(_last(s, "structure_entered")["label"]), "SOVIET RIG MODULE", "with its label")
	check(s.run.knows("rig_module"), "the codex entry is learned")
	check_eq(str(_last(s, "structure_outcome")["outcome"]), "none", "no event at event_chance 0")
	check_eq(s.run.phase, "drill", "still drilling")
	for k: int in range(3):
		var more: int = _find(s, StructureStamp.MARK_INTERIOR, _code(s, "relic_air"))
		s.drill.take_cell(more)
		s.step()
	check_eq(_count(s, "structure_entered"), 1, "still one break-in after more interior cuts")
	check_eq(_count(s, "codex"), 1, "and one codex event")


func test_the_footprint_breaks_in_by_drilling() -> void:
	var s: Sim = _sim()
	_begin(s, "mine_works", 40.0)
	var target: Vector2 = s.drill.structures.interior.get_center()
	check(_drive_to(s, target, "structure_entered", 120.0), "drilling toward the gallery breaks into it")


func test_a_blast_opens_the_interior_and_a_crate() -> void:
	var d0: DataDB = db()
	(d0.table("structures")["soviet_rig"] as Dictionary)["event_chance"] = 0.0
	var s: Sim = _sim(d0, 11, 0)
	_begin(s, "soviet_rig")
	var d: DrillSim = s.drill
	var crate: int = _find(s, StructureStamp.MARK_INTERIOR, _code(s, "crate"))
	var before: Dictionary = _res_total(s)
	d.verbs.blast_point = Vector2((float(crate % d.cols) + 1.0) * d.cell_m, (float(crate / d.cols) + 1.0) * d.cell_m)
	d.verbs.detonate(s, d)
	s.step()
	check_eq(_count(s, "structure_entered"), 1, "a blast into the interior is a break-in")
	check(_count(s, "loot") >= 1, "and it opens the crate it hits")
	var paid: Dictionary = {}  ## Crate loot plus whatever rock yield the blast circle reached.
	for e: Dictionary in s.events:
		if str(e["kind"]) == "loot" or str(e["kind"]) == "mined":
			paid[str(e["res"])] = int(paid.get(str(e["res"]), 0)) + int(e["amount"])
	for r: String in RunState.RESOURCES:
		check_eq(s.run.get_res(r) - int(before[r]), int(paid.get(r, 0)), "%s changed by exactly the loot and yield" % r)


# Mid-segment store and event -----------------------------------------------------------------------

func test_mid_segment_store_returns_to_drill_with_the_ship_where_it_was() -> void:
	var d0: DataDB = db()
	(d0.table("structures")["crystal_hollow"] as Dictionary)["trader_chance"] = 1.0
	var s: Sim = _sim(d0, 11, 0)
	_begin(s, "crystal_hollow")
	var air: int = _find(s, StructureStamp.MARK_INTERIOR, _code(s, "relic_air"))
	s.drill.take_cell(air)
	s.step()
	check_eq(s.run.phase, "store", "the break-in opened the hollow trader")
	check_eq(s.encounter.store_id, "hollow_trader", "the right store")
	check_eq(str(_last(s, "structure_outcome")["outcome"]), "trader", "the outcome says trader")
	var pos: Vector2 = s.drill.ship_pos
	var tick_seg: int = s.drill.segment_ticks
	run_seconds(s, 3.0)
	check_eq(s.drill.ship_pos, pos, "the ship does not move while the store is open")
	check_eq(s.drill.segment_ticks, tick_seg, "the segment clock is paused")
	check(s.drill.active, "the drill stays active")
	var gems0: int = s.run.get_res("gems")
	var coolant0: int = s.run.get_res("coolant")
	s.push({"type": "buy", "item": 0, "qty": 1})
	s.step()
	check_eq(gems0 - s.run.get_res("gems"), 8, "coolant costs 8 gems here")
	check_eq(s.run.get_res("coolant") - coolant0, 5, "and gives exactly 5 coolant")
	s.push({"type": "leave"})
	s.step()
	check_eq(s.run.phase, "drill", "leaving the store goes back to drilling, not idle")
	check_eq(s.drill.ship_pos.y >= pos.y, true, "the ship carries on from where it was")
	check_eq(s.drill.ship_pos.x, pos.x, "at the same x")
	s.push({"type": "power", "room": "drill", "bars": 3})
	run_seconds(s, 80.0)
	check_eq(_count(s, "segment_done"), 1, "the segment still arrives")
	check_eq(s.run.phase, "idle", "and the run is idle after it")


func test_mid_segment_event_returns_to_drill() -> void:
	var d0: DataDB = db()
	(d0.table("structures")["mine_works"] as Dictionary)["event_chance"] = 1.0
	var s: Sim = _sim(d0, 11, 0)
	_begin(s, "mine_works")
	var air: int = _find(s, StructureStamp.MARK_INTERIOR, _code(s, "relic_air"))
	s.drill.take_cell(air)
	s.step()
	check_eq(s.run.phase, "dialog", "the break-in started an event")
	check_eq(s.encounter.event_id, "mine_cage", "the mine works event")
	var pos: Vector2 = s.drill.ship_pos
	run_seconds(s, 2.0)
	check_eq(s.drill.ship_pos, pos, "the ship waits while the page is open")
	s.push({"type": "choose", "option": 1})
	s.step()
	var guard: int = 0
	while s.run.phase == "dialog" and guard < 5:
		s.push({"type": "choose", "option": 0})
		s.step()
		guard += 1
	check_eq(s.run.phase, "drill", "the event ends back in the drill phase")
	check_eq(s.drill.ship_pos.x, pos.x, "the ship is where it was")
	check(s.encounter.used.has("mine_cage"), "the event counts as used")
	# Once per run: a second mine works this run finds no event left.
	s.push({"type": "power", "room": "drill", "bars": 3})
	run_seconds(s, 80.0)
	check_eq(s.run.phase, "idle", "the segment ended")
	_begin(s, "mine_works", 36.0, "st2")
	var air2: int = _find(s, StructureStamp.MARK_INTERIOR, _code(s, "relic_air"))
	s.drill.take_cell(air2)
	s.step()
	check_eq(str(_last(s, "structure_outcome")["outcome"]), "none", "the event does not repeat in a run")
	check_eq(s.run.phase, "drill", "so the drill carries on")


# Survey ---------------------------------------------------------------------------------------------

func test_survey_structures_are_deterministic_and_in_their_windows() -> void:
	var d: DataDB = db()
	var rock: Dictionary = d.table("rock")["crust"]
	var step_m: float = float((d.table("layers")["crust"] as Dictionary)["row_depth_m"])
	var seen: Dictionary = {}
	for sd: int in range(1, 41):
		var a := Sim.new(d, sd, "light_drill", {"mode": "run"})
		var b := Sim.new(d, sd, "light_drill", {"mode": "run"})
		check_eq(var_to_str(a.run.map), var_to_str(b.run.map), "seed %d: the same surveys" % sd)
		for n: Dictionary in a.run.nodes:
			var sv: Dictionary = n["survey"]
			if int(n["row"]) == 0:
				continue
			check(sv.has("structure"), "every reading has a structure key")
			var sid: String = str(sv.get("structure", ""))
			if sid.is_empty():
				continue
			seen[sid] = int(seen.get(sid, 0)) + 1
			var mid: float = (float(int(n["row"]) - 1) + 0.5) * step_m
			var ok: bool = false
			for e: Variant in (rock["structures"] as Array):
				var ed: Dictionary = e
				if str(ed["structure"]) == sid and mid >= float(ed.get("from_depth_m", 0.0)) \
						and mid < float(ed.get("to_depth_m", 1.0e12)):
					ok = true
			check(ok, "seed %d: %s sits in its depth window (mid %.0f m)" % [sd, sid, mid])
	for sid: String in ["mine_works", "soviet_rig", "crystal_hollow"]:
		check_gt(float(seen.get(sid, 0)), 0.0, "%s shows up in 40 runs" % sid)


func test_survey_structure_draws_leave_the_other_readings_alone() -> void:
	var d: DataDB = db()
	var layer: Dictionary = d.table("layers")["crust"]
	var rock: Dictionary = d.table("rock")["crust"]
	var a: Dictionary = Survey.roll(layer["survey"], rock, false, 120.0, 60.0, RngStreams.new(3).get_stream("survey"), 2,
			RngStreams.new(3).get_stream("survey/structure"))
	var b: Dictionary = Survey.roll(layer["survey"], rock, false, 120.0, 60.0, RngStreams.new(3).get_stream("survey"), 2,
			RngStreams.new(99).get_stream("survey/structure"))
	for k: String in ["tier", "gems", "gas", "water", "faults"]:
		check_eq(a[k], b[k], "%s comes from the survey stream alone" % k)
