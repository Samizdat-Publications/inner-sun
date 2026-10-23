extends TestCase
## The onboarding hints (HintDirector): every condition helper, the lines in the radio data, the once-ever
## memory in the profile (old profiles load), the 20 s pacing, the overlay and fight rules, and that a
## bot, capture or replay run never gets one. The look is judged on the captured stills.


func _scratch(p_name: String) -> String:
	var d: String = ProjectSettings.globalize_path("res://").path_join("../harness/out/test_hints").path_join(p_name).simplify_path()
	DirAccess.make_dir_recursive_absolute(d)
	for f: String in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	return d


func _code(s: Sim, id: String) -> int:
	for c: int in range(s.drill.materials.size()):
		if str(s.drill.materials[c].get("id", "")) == id:
			return c
	return -1


## A full-run sim on light_drill with a segment under way, every cell outside the ship plain granite,
## the drill still (0 bars), the pursuer far behind, nobody steering.
func _sim() -> Sim:
	var s := Sim.new(db(), 11, "light_drill", {"mode": "run"})
	s.push({"type": "power", "room": "bracing", "bars": 0})
	s.push({"type": "power", "room": "drill", "bars": 0})
	crew_auto_off(s)
	s.step()
	s.push({"type": "begin_segment", "segment": "h", "depth_m": 36.0, "lateral_m": 0.0})
	s.step()
	var d: DrillSim = s.drill
	var ship := Rect2(d.ship_pos, d.ship_size)
	var rock: int = _code(s, "rock")
	for r: int in range(d.rows):
		for c: int in range(d.cols):
			if not ship.has_point(Vector2((c + 0.5) * d.cell_m, (r + 0.5) * d.cell_m)):
				d.grid[r * d.cols + c] = rock
	d.survey["faults"] = false
	s.run.pursuer_row = -10.0
	return s


## Fill a block of cells (segment meters) with a material.
func _fill(s: Sim, id: String, x0: float, y0: float, x1: float, y1: float) -> void:
	var d: DrillSim = s.drill
	var code: int = _code(s, id)
	for r: int in range(int(y0 / d.cell_m), int(y1 / d.cell_m)):
		for c: int in range(int(x0 / d.cell_m), int(x1 / d.cell_m)):
			d.grid[r * d.cols + c] = code


func _head(s: Sim) -> Vector2:
	return MinerRoute.head(s.drill)


func _director(s: Sim, p: Profile, enabled: bool = true) -> HintDirector:
	var h := HintDirector.new()
	h.bind(s, p)
	h.enabled = enabled
	return h


func _run(h: HintDirector, seconds: float) -> void:
	for i: int in range(roundi(seconds / 0.25)):
		h._process(0.25)


# Data and profile --------------------------------------------------------------------------------

func test_every_hint_has_lines_and_a_lint_trigger() -> void:
	var s: Sim = _sim()
	var dash: String = String.chr(0x2014)
	for n: String in HintDirector.NAMES:
		check(EncounterLint.RADIO_TRIGGERS.has("hint_" + n), "the radio lint knows hint_" + n)
		for runs: int in range(4):
			var line: String = HintDirector.line_for(s, n, runs)
			check(not line.is_empty(), "%s has a line (run %d)" % [n, runs])
			check(not line.contains(dash), "%s has no em dash" % n)
			check(line.length() <= 170, "%s is short enough for the strip (%d)" % [n, line.length()])
	check_eq(HintDirector.NAMES.size(), 14, "fourteen hints in all")
	check_eq(HintDirector.line_for(s, "no_such_hint", 0), "", "an unknown hint has no line")
	check_eq(HintDirector.line_for(s, "miner", 3), HintDirector.line_for(s, "miner", 3), "the pick is a pure hash of the run count")
	check(HintDirector.line_for(s, "miner", 0).contains("parks itself") or HintDirector.line_for(s, "miner", 0).contains("stops on its own"), "the miner hint says the drill parks")
	check(HintDirector.line_for(s, "douse", 0).contains("6 seconds"), "the douse hint says the vent time")
	check(HintDirector.line_for(s, "structure", 0).contains("crates"), "the structure hint talks about crates")


func test_profile_remembers_hints_and_old_profiles_load() -> void:
	var dir: String = _scratch("seen")
	var p: Profile = Profile.load_from(dir)
	check(p.hints_seen.is_empty(), "a fresh profile has seen none")
	p.hints_seen.append("pause")
	p.hints_seen.append("blast")
	check(p.save(), "saved")
	var q: Profile = Profile.load_from(dir)
	check_eq(Array(q.hints_seen), ["blast", "pause"], "the hints come back, sorted")
	var old: String = _scratch("old")
	var f: FileAccess = FileAccess.open(old.path_join(Profile.FILE_NAME), FileAccess.WRITE)
	f.store_string('{"version": 1, "runs": 3, "known_codex": ["mohole"]}')
	f.close()
	var o: Profile = Profile.load_from(old)
	check_eq(o.runs, 3, "an old profile still loads")
	check(o.hints_seen.is_empty(), "with no hints seen")


# Conditions --------------------------------------------------------------------------------------

func test_power_and_steer() -> void:
	var s: Sim = _sim()
	check(HintDirector.drilling(s), "the sim is drilling")
	check(HintDirector.drill_unpowered(s), "the drill sits at 0 bars")
	s.push({"type": "power", "room": "drill", "bars": 2})
	s.step()
	check(not HintDirector.drill_unpowered(s), "powered, it is not")
	check(HintDirector.never_steered(s), "nobody has steered yet")
	s.push({"type": "steer", "angle": 15.0})
	s.step()
	check(not HintDirector.never_steered(s), "a steer order ends the steering hint")
	var sc := Sim.new(db(), 3, "light_drill")
	check(not HintDirector.drilling(sc), "a scenario sim is never drilling for the hints")


func test_clusters_blast_and_seam() -> void:
	var s: Sim = _sim()
	var head: Vector2 = _head(s)
	check(HintDirector.clusters(s.drill, head, 14.0, 3.0).is_empty(), "plain granite has no clusters")
	check(not HintDirector.blast_worth(s) and not HintDirector.seam_beside(s), "and nothing to teach")
	# A rich lump 8 m to the side and 6 m down: 5 x 5 cells of iron ore (2 ore each) is worth 50.
	_fill(s, "iron_ore", head.x + 8.0, head.y + 6.0, head.x + 10.5, head.y + 8.5)
	var cl: Array[Dictionary] = HintDirector.clusters(s.drill, head, 14.0, 3.0)
	check_eq(cl.size(), 1, "one lump")
	check_eq(int(cl[0]["cells"]), 25, "25 cells")
	check_eq(float(cl[0]["value"]), 50.0, "worth 50 ore units")
	check(HintDirector.blast_worth(s), "a rich lump inside charge range, launcher and charges aboard")
	s.run.add(s, "charges", -s.run.get_res("charges"))
	check(not HintDirector.blast_worth(s), "no charges, no blast hint")
	# A flat seam level with the head, 6 m long.
	var s2: Sim = _sim()
	var h2: Vector2 = _head(s2)
	_fill(s2, "coal", h2.x + 4.0, h2.y - 0.5, h2.x + 10.0, h2.y + 1.0)
	check(HintDirector.seam_beside(s2), "a wide seam level with the head")
	s2.drill.target_heading_deg = 90.0
	check(not HintDirector.seam_beside(s2), "already turned to hold depth: no hint")
	var s3: Sim = _sim()
	var h3: Vector2 = _head(s3)
	_fill(s3, "coal", h3.x + 4.0, h3.y + 8.0, h3.x + 10.0, h3.y + 9.5)
	check(not HintDirector.seam_beside(s3), "a seam far below the head is not level with it")


func test_miner_worth() -> void:
	var s: Sim = _sim()
	var head: Vector2 = _head(s)
	_fill(s, "gem", head.x + 5.0, head.y + 2.0, head.x + 7.0, head.y + 4.0)
	check(HintDirector.miner_worth(s), "a gem cluster off the path, front far behind, two crew")
	s.run.pursuer_row = s.run.ship_row_f(s) - 1.0
	check(not HintDirector.miner_worth(s), "the front is too close")
	s.run.pursuer_row = -10.0
	s.ship.crew[0].alive = false
	s.ship.crew[1].alive = false
	check(not HintDirector.miner_worth(s), "a lone crew member stays aboard")


func test_bracing() -> void:
	var s: Sim = _sim()
	s.drill.survey["faults"] = true
	var head: Vector2 = _head(s)
	_fill(s, "fault_rock", head.x - 3.0, head.y + 2.0, head.x + 3.0, head.y + 3.0)
	check_eq(s.systems.bracing_layers(s.player), 0, "no bracing layers up")
	check(HintDirector.fault_unbraced(s), "fault rock 2 m ahead and no layers")
	var far: Sim = _sim()
	far.drill.survey["faults"] = true
	var hf: Vector2 = _head(far)
	_fill(far, "fault_rock", hf.x - 3.0, hf.y + 9.0, hf.x + 3.0, hf.y + 10.0)
	check(not HintDirector.fault_unbraced(far), "fault rock 9 m ahead is not within 4 m")


func test_fire_bit_crew_pause_fight() -> void:
	var s: Sim = _sim()
	check(not HintDirector.fire_to_douse(s) and not HintDirector.pause_due(s), "a calm ship has none")
	var r: Room = s.ship.rooms[0]
	r.fire = 0.5
	check(s.run.get_res("coolant") > 0, "coolant in stock")
	check(HintDirector.fire_to_douse(s), "a room burning above 0.3 with coolant")
	check(HintDirector.pause_due(s), "the first fire is the pause hint")
	check(HintDirector.hazard_unattended(s), "and nobody is heading to it")
	var crew: CrewMember = s.ship.crew[0]
	crew.job_kind = "extinguish"
	crew.job_room = r.index
	check(not HintDirector.hazard_unattended(s), "a crew member on the way covers it")
	r.fire = 0.2
	check(not HintDirector.fire_to_douse(s), "a smaller fire is not a douse")
	r.fire = 0.0
	check(not HintDirector.bit_broken(s), "a whole bit")
	s.drill.bit_broken = true
	check(HintDirector.bit_broken(s), "a broken bit")
	check(not HintDirector.fight_on(s), "no fight yet")
	s.combat.start_fight(s, "rival_light", false)
	check(HintDirector.fight_on(s) and HintDirector.in_fight(s), "a fight")
	check(HintDirector.pause_due(s), "the first fight is also a pause hint")
	check(not HintDirector.drilling(s), "a fight is not drilling")


func test_structure_near() -> void:
	var s: Sim = _sim()
	s.drill.structures.id = ""
	check(not HintDirector.structure_near(s), "no structure")
	var head: Vector2 = _head(s)
	s.drill.structures.id = "mine_works"
	s.drill.structures.rect = Rect2(head.x + 6.0, head.y + 10.0, 8.0, 5.0)
	check(HintDirector.structure_near(s), "a structure 12 m off")
	s.drill.structures.rect = Rect2(head.x + 6.0, head.y + 30.0, 8.0, 5.0)
	check(not HintDirector.structure_near(s), "30 m off is too far")
	s.drill.structures.rect = Rect2(head.x - 1.0, head.y + 1.0, 8.0, 5.0)
	s.drill.structures.entered = true
	check(not HintDirector.structure_near(s), "broken into: no more hint")


func test_overlay_hints() -> void:
	check(HintDirector.requisitions_due(true, 3), "the death screen with research")
	check(not HintDirector.requisitions_due(true, 0), "no research to spend")
	check(not HintDirector.requisitions_due(false, 3), "not on the death screen")
	check(HintDirector.map_due(true) and not HintDirector.map_due(false), "the map hint follows the map")
	check(HintDirector.allowed_now("map", true, false), "the map hint may show over the map")
	check(not HintDirector.allowed_now("power", true, false), "other hints wait while an overlay is open")
	check(not HintDirector.allowed_now("miner", false, true), "no drill hints in a fight")
	check(HintDirector.allowed_now("weapons", false, true) and HintDirector.allowed_now("pause", false, true), "the fight hints may")


# Pacing and memory -------------------------------------------------------------------------------

## Powered, steered and a crew member on the fire, so only the hints a test is about can fire.
func _quiet(s: Sim) -> void:
	s.push({"type": "power", "room": "drill", "bars": 2})
	s.push({"type": "steer", "angle": 0.0})
	s.step()
	s.ship.crew[0].job_kind = "extinguish"
	s.ship.crew[0].job_room = 0


func test_once_ever_and_pacing() -> void:
	var s: Sim = _sim()
	_quiet(s)
	var p: Profile = Profile.load_from(_scratch("pace"))
	var h: HintDirector = _director(s, p)
	s.drill.bit_broken = true
	s.ship.rooms[0].fire = 0.5
	_run(h, 1.0)
	check_eq(h.shown.size(), 1, "one hint at once")
	check_eq(h.shown[0], "bit", "the bit comes before the douse")
	check(p.hints_seen.has("bit"), "remembered in the profile")
	_run(h, 15.0)
	check_eq(h.shown.size(), 1, "nothing else inside 20 s")
	_run(h, 6.0)
	check_eq(h.shown.size(), 2, "the next one after the gap")
	check_eq(h.shown[1], "douse", "the douse")
	_run(h, 60.0)
	check_eq(h.shown.size(), 3, "then the pause hint (the fire), and nothing repeats")
	check_eq(h.shown[2], "pause", "the first fire also teaches Space")
	check_eq(Array(Profile.load_from(p.dir).hints_seen), ["bit", "douse", "pause"], "saved to disk")
	# A new run with the same profile gives none of them again.
	var s2: Sim = _sim()
	_quiet(s2)
	s2.drill.bit_broken = true
	s2.ship.rooms[0].fire = 0.5
	var h2: HintDirector = _director(s2, Profile.load_from(p.dir))
	_run(h2, 60.0)
	check(h2.shown.is_empty(), "a new run does not repeat them")


func test_power_and_steer_timers() -> void:
	var s: Sim = _sim()
	var p: Profile = Profile.load_from(_scratch("timers"))
	var h: HintDirector = _director(s, p)
	_run(h, 2.0)
	check(h.shown.is_empty(), "2 s at 0 bars is not yet")
	_run(h, 2.0)
	check_eq(h.shown.size(), 1, "3 s at 0 bars gives the power hint")
	check_eq(h.shown[0], "power", "it is the power hint")
	s.push({"type": "power", "room": "drill", "bars": 2})
	s.step()
	_run(h, 30.0)
	check_eq(h.shown.size(), 2, "20 s into the dive with no steering gives the steer hint")
	check_eq(h.shown[1], "steer", "the steer hint")


func test_never_in_bot_capture_or_replay_runs() -> void:
	var s: Sim = _sim()
	s.drill.bit_broken = true
	var p: Profile = Profile.load_from(_scratch("off"))
	var h: HintDirector = _director(s, p, false)
	_run(h, 60.0)
	check(h.shown.is_empty(), "a director that is not enabled shows nothing")
	check(p.hints_seen.is_empty(), "and remembers nothing")
	var h2: HintDirector = _director(s, null, true)
	_run(h2, 60.0)
	check(h2.shown.is_empty(), "no profile (a scenario) shows nothing")
	# The dev flag shows one hint without recording it.
	var h3: HintDirector = _director(s, p, false)
	h3.force = "miner"
	_run(h3, 3.0)
	check_eq(h3.shown, ["miner"] as Array[String], "--hint forces the one hint about 2 s in")
	check(p.hints_seen.is_empty(), "a forced hint is not remembered")
	_run(h3, 30.0)
	check_eq(h3.shown.size(), 1, "and only once")


func test_hints_leave_the_sim_alone() -> void:
	var a: Sim = _sim()
	var b: Sim = _sim()
	var h: HintDirector = _director(b, Profile.load_from(_scratch("alone")))
	b.drill.bit_broken = true
	a.drill.bit_broken = true
	for i: int in range(240):
		a.step()
		b.step()
		h._process(Sim.DT)
	check_eq(a.state_hash(), b.state_hash(), "a sim with a director attached ends in the same state")
	check(not h.shown.is_empty(), "and the director did speak")


func test_glow_targets_sit_on_the_screen() -> void:
	var s: Sim = _sim()
	var rs := RunScreen.new()
	rs.build(s, Profile.load_from(_scratch("glow")))
	var screen_rect := Rect2(0.0, 0.0, 1920.0, 1080.0)
	for n: String in HintDirector.NAMES:
		var r: Rect2 = rs.hints.target_rect(n)
		if n == "douse" or n == "requisitions":
			check(r.size == Vector2.ZERO, "%s has no rect until Main (or the open death screen) gives one" % n)
			continue
		check(r.size.x > 20.0 and r.size.y > 10.0, "%s has a target (%s)" % [n, str(r)])
		check(screen_rect.encloses(r), "%s sits on the screen (%s)" % [n, str(r)])
	var row: Rect2 = rs.hints.target_rect("bracing")
	check(row.size.y < 120.0 and row.position.x >= 0.0, "bracing glows its own power row, not the whole panel")
	check(rs.hints.target_rect("pause").position.x > 1300.0, "the pause hint points at the top bars clock")
	rs.free()


## M1d: parking is a choice, so the PARKED notice draws in amber; every other stop stays alarm red.
func test_parked_notice_is_amber() -> void:
	var s: Sim = _sim()
	var rs := RunScreen.new()
	rs.build(s, Profile.load_from(_scratch("notice")))
	rs.set_notice("PARKED: OKAFOR IS OUTSIDE. G recalls.", "miner")
	check(rs.notice_is_calm(), "a parked drill's notice is calm (amber)")
	rs.set_notice("DRILL HAS NO POWER. Press 4.", "power")
	check(not rs.notice_is_calm(), "no power is an alarm (red)")
	rs.set_notice("", "")
	check(not rs.notice_is_calm(), "an empty notice falls back to red")
	rs.free()
