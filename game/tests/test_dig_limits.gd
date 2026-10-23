extends TestCase
## D060 dig limits: the heading cap and the scanner range grow with the helm's installed bars
## (drill.max_heading_deg_by_helm_*, drill.scanner_range_m_by_helm_*), the Crust's ore richness
## (layers/crust.json ore_richness_mult), the bots obey the cap, the lint checks the new keys.


## A run-mode sim on light_drill (helm installed at 2 bars), a second in, with a segment begun.
func _sim(p_db: DataDB = null, p_seed: int = 11, survey: Dictionary = {}) -> Sim:
	var s := Sim.new(p_db if p_db != null else db(), p_seed, "light_drill", {"mode": "run"})
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": 2})
	s.push({"type": "power", "room": "bridge", "bars": 2})
	run_seconds(s, 1.0)
	s.push({"type": "begin_segment", "segment": "lim", "depth_m": 60.0, "lateral_m": 0.0, "survey": survey})
	s.step()
	return s


func _helm(s: Sim) -> Room:
	return s.ship.rooms[s.ship.room_with_system("helm")]


## What the store's helm upgrade does (Store: sys_max += qty), as test setup.
func _upgrade_helm(s: Sim, to_bars: int) -> void:
	_helm(s).sys_max = to_bars


# The cap ----------------------------------------------------------------------------------------

func test_heading_cap_is_45_until_the_helm_upgrade() -> void:
	var s: Sim = _sim()
	check_eq(_helm(s).sys_max, 2, "light_drill starts with the helm at 2 installed bars")
	check_eq(s.drill.max_heading_deg(s), 45.0, "cap at 2 bars")
	s.push({"type": "steer", "angle": 90.0})
	s.step()
	check_eq(s.drill.target_heading_deg, 45.0, "a steer to 90 is clamped to 45")
	s.push({"type": "steer", "angle": -120.0})
	s.step()
	check_eq(s.drill.target_heading_deg, -45.0, "and to -45 the other way")
	run_seconds(s, 6.0)
	check_eq(s.drill.heading_deg, -45.0, "the heading ends at the cap")
	_upgrade_helm(s, 3)
	check_eq(s.drill.max_heading_deg(s), 90.0, "cap at 3 bars")
	s.push({"type": "steer", "angle": 90.0})
	s.step()
	check_eq(s.drill.target_heading_deg, 90.0, "after the upgrade a steer to 90 holds depth")
	run_seconds(s, 9.0)
	check_eq(s.drill.heading_deg, 90.0, "and the heading reaches 90")


func test_scanner_range_by_helm_bars() -> void:
	var s: Sim = _sim()
	check_eq(s.drill.scanner_range_m(s), 10.0, "range at 2 bars")
	_upgrade_helm(s, 3)
	check_eq(s.drill.scanner_range_m(s), 16.0, "range at 3 bars")
	_upgrade_helm(s, 4)
	check_eq(s.drill.scanner_range_m(s), 22.0, "range at 4 bars")
	_upgrade_helm(s, 0)
	check_eq(s.drill.scanner_range_m(s), 10.0, "range at 0 bars")
	_upgrade_helm(s, 40)
	check_eq(s.drill.scanner_range_m(s), 22.0, "more bars than the table names use its last entry")


func test_cap_falls_back_to_max_heading_deg_without_a_table() -> void:
	var d: DataDB = db()
	for k: String in DrillSim.helm_table_keys():
		d.tuning.erase(k)
	var s: Sim = _sim(d)
	check_eq(s.drill.max_heading_deg(s), d.tune("drill.max_heading_deg"), "no table: the single max_heading_deg")
	check_eq(s.drill.scanner_range_m(s), DrillSim.NO_RANGE_M, "no range table: the whole screen shows")


# Richness ---------------------------------------------------------------------------------------

## Ore and gem units in a freshly generated segment (cells times their yield amount).
func _units(s: Sim) -> int:
	var d: DrillSim = s.drill
	var n: int = 0
	for code: int in range(DrillSim.MAX_CODES):
		if d.yield_res_of[code] >= 0:
			n += d.generated[code] * d.yield_amount_of[code]
	return n


func test_crust_ore_is_about_20_percent_richer() -> void:
	var plain_db: DataDB = db()
	(plain_db.table("layers")["crust"] as Dictionary)["ore_richness_mult"] = 1.0  # Test setup: the old Crust.
	# 1.3 more ore and gem features give about 20% more units: overlapping features and the start
	# shaft eat part of the extra (measured: x1.12 units at 1.2, x1.19 at 1.3).
	check_eq(float(db().table("layers")["crust"]["ore_richness_mult"]), 1.3, "the Crust's richness factor")
	var rich: int = 0
	var plain: int = 0
	var survey: Dictionary = {"richness": 1.0, "gems": true, "water": true, "gas": true, "faults": true}
	for p_seed: int in range(1, 41):
		rich += _units(_sim(db(), p_seed, survey))
		plain += _units(_sim(plain_db, p_seed, survey))
	var ratio: float = float(rich) / float(maxi(plain, 1))
	print("D060 ore and gem units over 40 seeds: %d with the factor, %d without (x%.3f)" % [rich, plain, ratio])
	check_gt(ratio, 1.15, "ore and gem units rise at least 15%")
	check_lt(ratio, 1.25, "and at most 25%")


func test_richness_leaves_water_and_gas_alone() -> void:
	var plain_db: DataDB = db()
	(plain_db.table("layers")["crust"] as Dictionary)["ore_richness_mult"] = 1.0
	var survey: Dictionary = {"richness": 1.0, "gems": false, "water": true, "gas": true, "faults": true}
	var a: Sim = _sim(db(), 5, survey)
	var b: Sim = _sim(plain_db, 5, survey)
	var wa: int = 0
	var wb: int = 0
	for code: int in range(DrillSim.MAX_CODES):
		if a.drill.water_of[code] == 1 or a.drill.gas_of[code] == 1 or a.drill.unstable_of[code] == 1:
			wa += 1 if a.drill.generated[code] > 0 else 0
			wb += 1 if b.drill.generated[code] > 0 else 0
	check_eq(wa, wb, "the same hazard materials appear with or without the factor")


# Bots -------------------------------------------------------------------------------------------

## The greedy policy (it asks for up to 80 degrees) drives one segment; returns the steepest steer
## order in the command log and the steepest heading seen.
func _greedy_segment(p_seed: int, helm_bars: int) -> Vector2:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
	s.run.add(s, "charges", 6)
	if helm_bars != 2:
		_upgrade_helm(s, helm_bars)
	s.step()
	s.push({"type": "begin_segment", "segment": "cap%d" % p_seed, "depth_m": 50.0, "lateral_m": 2.0,
			"survey": {"richness": 1.9, "gems": true}})
	s.step()
	var bot: PolicyBot = PolicyBot.make_policy("greedy")
	var steepest: float = 0.0
	var cap: int = 60 * 240
	while s.drill.active and cap > 0 and not s.run.is_over():
		bot.act(s)
		s.step()
		cap -= 1
		steepest = maxf(steepest, absf(s.drill.heading_deg))
	var most: float = 0.0
	for c: Dictionary in s.command_log:
		if str(c["type"]) == "steer":
			most = maxf(most, absf(float(c.get("angle", 0.0))))
	return Vector2(most, steepest)


func test_policy_bot_never_steers_past_the_cap() -> void:
	var most: float = 0.0
	for p_seed: int in [1, 2, 3]:
		var r: Vector2 = _greedy_segment(p_seed, 2)
		check_lt(r.x, 45.0 + 0.001, "seed %d: no steer order past 45 (got %.1f)" % [p_seed, r.x])
		check_lt(r.y, 45.0 + 0.001, "seed %d: the heading never passes 45 (got %.1f)" % [p_seed, r.y])
		most = maxf(most, r.x)
	check_gt(most, 30.0, "the bot does steer hard (the scan is not vacuous)")


# Lint -------------------------------------------------------------------------------------------

func _lint_text(d: DataDB) -> String:
	return "\n".join(d.lint())


func test_lint_accepts_the_new_keys_and_rejects_bad_ones() -> void:
	var errs := PackedStringArray()
	DrillLint.lint(db(), errs)
	check(errs.is_empty(), "the real drill tuning and layers lint clean: " + " | ".join(errs))
	var d: DataDB = db()
	d.tuning.erase("drill.scanner_range_m_by_helm_0")
	check(_lint_text(d).contains("missing number \"drill.scanner_range_m_by_helm_0\""), "a missing range entry is caught")
	d = db()
	d.tuning.erase("drill.max_heading_deg_by_helm_0")
	check(_lint_text(d).contains("missing number \"drill.max_heading_deg_by_helm_0\""), "a missing heading entry is caught")
	d = db({"drill.max_heading_deg_by_helm_3": 120.0})
	check(_lint_text(d).contains("max_heading_deg_by_helm_3"), "a heading cap past 90 is caught")
	d = db({"drill.scanner_range_m_by_helm_4": 0.0})
	check(_lint_text(d).contains("scanner_range_m_by_helm_4"), "a zero range is caught")
	d = db({"drill.scanner_range_m_by_helm_12": 30.0})
	check(_lint_text(d).contains("scanner_range_m_by_helm_12"), "a bar count past the table is caught")
	d = db()
	(d.table("layers")["crust"] as Dictionary)["ore_richness_mult"] = "lots"
	check(_lint_text(d).contains("ore_richness_mult"), "a non-numeric richness factor is caught")


func test_lint_rejects_a_non_numeric_table_entry() -> void:
	var root: String = "user://test_dig_limits"
	DirAccess.make_dir_recursive_absolute(root.path_join("tuning"))
	var f: FileAccess = FileAccess.open(root.path_join("tuning/drill.json"), FileAccess.WRITE)
	f.store_string("{\"drill\": {\"max_heading_deg_by_helm_0\": \"forty five\", \"scanner_range_m_by_helm_0\": 10.0}}")
	f.close()
	var d: DataDB = DataDB.load_all(root)
	var all: String = _lint_text(d)
	check(all.contains("drill.max_heading_deg_by_helm_0 must be a number"), "a non-numeric heading entry is caught")
	check(all.contains("missing number \"drill.max_heading_deg_by_helm_0\""), "and counts as missing")
	DirAccess.remove_absolute(root.path_join("tuning/drill.json"))
	DirAccess.remove_absolute(root.path_join("tuning"))
	DirAccess.remove_absolute(root)


# View geometry ----------------------------------------------------------------------------------

func test_scanner_range_geometry() -> void:
	var head := Vector2(16.0, 9.0)
	var cell: float = 0.5
	for r: int in range(0, 60):
		var span: Vector2i = ScannerExtras.row_span(r, cell, 64, head, 10.0)
		for c: int in range(64):
			var inside: bool = c >= span.x and c < span.y
			if inside != ScannerExtras.cell_in_range(c, r, cell, head, 10.0):
				check(false, "row %d col %d: row_span and cell_in_range disagree" % [r, c])
				return
	check(ScannerExtras.rect_in_range(Rect2(20.0, 12.0, 4.0, 4.0), head, 10.0), "a box 5 m off is in range")
	check(not ScannerExtras.rect_in_range(Rect2(20.0, 25.0, 4.0, 4.0), head, 10.0), "a box 16 m off is not")
	check_eq(ScannerDraw.heading_text(45.0, 45.0, 45.0), "HDG +45 MAX", "the readout shows the cap")
	check_eq(ScannerDraw.heading_text(12.0, 30.0, 45.0), "HDG +12  TGT +30", "below the cap: heading and target")
