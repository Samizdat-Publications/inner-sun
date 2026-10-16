extends TestCase
## The pure and tree-less parts of the M1b controls: the world-hold rule, queued power wishes, the
## alerts and the death text. Real keyboard and mouse input needs a running scene tree, which this
## runner does not have: tests/ui_selftest.gd covers it (Main --selftest, run by tools/check.py).

func _run_sim(seed_value: int = 3) -> Sim:
	return Sim.new(db(), seed_value, "light_drill", {"mode": "run"})


func test_should_step_holds_humans_only() -> void:
	var s: Sim = _run_sim()
	check(RunScreen.should_step(s, false, true, false), "a human steps normally")
	check(not RunScreen.should_step(s, false, true, true), "a held world does not step")
	check(not RunScreen.should_step(s, true, true, false), "a paused world does not step")
	check(RunScreen.should_step(s, false, false, true), "a bot or replay is never held")
	s.push({"type": "power", "room": s.ship.rooms[0].id, "bars": 0})
	check(RunScreen.should_step(s, false, true, true), "a held world steps while orders wait")
	check(not RunScreen.should_step(s, true, true, true), "but a paused one still waits")


func test_power_orders_allowed_in_dialog_and_idle_not_store() -> void:
	var s: Sim = _run_sim()
	for phase: String in ["idle", "drill", "combat", "dialog"]:
		s.run.phase = phase
		check(PowerPanel.takes_orders(s), "power orders are allowed in %s" % phase)
	s.run.phase = "store"
	check(not PowerPanel.takes_orders(s), "but not in the store")


func test_power_wishes_stack_while_the_sim_waits() -> void:
	var s: Sim = _run_sim()
	var pp: PowerPanel = PowerPanel.build(Control.new(), s)
	var di: int = s.ship.room_with_system("drill")
	var row: int = pp._rows.find(di)
	check_gt(float(row), -1.0, "the drill has a power row")
	s.push({"type": "power", "room": s.ship.rooms[di].id, "bars": 3})
	s.step()
	check_eq(s.ship.rooms[di].sys_power, 3, "the drill starts at 3 bars")
	pp.change_bars(row, -1)
	pp.change_bars(row, -1)
	check_eq(s._pending.size(), 2, "two presses queue two orders")
	check_eq(int(s._pending[1]["bars"]), 1, "the second builds on the first")
	check_eq(pp.pending_bars(di), 1, "the panel reports the pending wish")
	s.step()
	check_eq(s.ship.rooms[di].sys_power, 1, "both apply on one step")
	check_eq(pp.pending_bars(di), -1, "the wish clears once the sim has stepped")
	pp.get_parent().free()


func test_power_wish_never_asks_for_more_than_the_reactor_has() -> void:
	var s: Sim = _run_sim()
	var pp: PowerPanel = PowerPanel.build(Control.new(), s)
	var di: int = s.ship.room_with_system("drill")
	var row: int = pp._rows.find(di)
	for i: int in range(12):
		pp.change_bars(row, 1)
	var wished: int = pp.pending_bars(di)
	var out: int = s.systems.reactor_output(s.player)
	var others: int = 0
	for ri: int in pp._rows:
		if ri != di:
			others += s.ship.rooms[ri].sys_power
	check(wished <= out - others or wished <= s.ship.rooms[di].sys_power, "the wish fits the free bars")
	s.step()
	check(s.systems.allocated(s.player) <= out, "the sim never over-allocates")
	pp.get_parent().free()


func test_dossier_backdrop_lets_clicks_through() -> void:
	var d := Dossier.new()
	check_eq(d.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the dim backdrop ignores the mouse")
	d.free()


func test_scanner_bit_button() -> void:
	var s: Sim = _run_sim()
	var sc: ScannerPanel = ScannerPanel.build(Control.new(), s)
	check(not sc.bit_offer(), "no offer outside the drill phase")
	check(s.run.choose_node(s, s.run.links_from_current()[0]), "a segment starts")
	s.step()
	check(sc.is_live(), "the scanner is live")
	s.drill.bit_wear = 0.4
	check(not sc.bit_offer(), "no offer while the bit is fine")
	s.drill.bit_wear = 0.6
	check(sc.bit_offer(), "the offer shows past half wear")
	sc.change_bit()
	check_eq(str(s._pending[s._pending.size() - 1]["type"]), "change_bit", "the button queues change_bit")
	var bits: int = s.run.get_res("bits")
	s.step()
	check_eq(s.run.get_res("bits"), bits - 1, "a bit is spent")
	check(not sc.bit_offer(), "no offer while a bit is being fitted")
	sc.get_parent().free()


func test_alerts_warn_ahead_and_about_the_drill_room() -> void:
	# The first seed whose map holds both a fight and a hazard node (map content comes from the layer
	# data, so no seed is assumed).
	var s: Sim = null
	var fight_id: String = ""
	var hazard_id: String = ""
	for seed_value: int in range(3, 40):
		s = _run_sim(seed_value)
		fight_id = ""
		hazard_id = ""
		for n: Dictionary in s.run.nodes:
			if str(n["type"]) == "fight" and fight_id.is_empty():
				fight_id = str(n["id"])
			if str(n["type"]) == "hazard" and hazard_id.is_empty():
				hazard_id = str(n["id"])
		if not fight_id.is_empty() and not hazard_id.is_empty():
			break
	check(not fight_id.is_empty() and not hazard_id.is_empty(), "a map with a fight and a hazard node")
	s.run.phase = "drill"
	s.run.target_node = fight_id
	check(_has_text(AlertsStrip.compute(s), "HOSTILE AHEAD: power weapons (E) before you arrive"), "a fight ahead warns")
	s.run.target_node = hazard_id
	check(_has_text(AlertsStrip.compute(s), "HAZARD AHEAD"), "a hazard ahead warns")
	s.run.target_node = ""
	check(not _has_text(AlertsStrip.compute(s), "AHEAD"), "nothing ahead, no warning")
	var dr: Room = s.ship.rooms[s.ship.room_with_system("drill")]
	check(not _has_text(AlertsStrip.compute(s), "DRILL ROOM FLOODING"), "a dry drill room has no hint")
	dr.water_ml = dr.capacity_ml
	check(_has_text(AlertsStrip.compute(s), "Select one (1-3) and click the drill room"), "a deep drill room gets the flood hint")


func test_drill_stop_says_why() -> void:
	var s: Sim = _run_sim()
	s.run.phase = "idle"
	check(s.drill.begin_segment(s, "stop_test", 20.0, 0.0), "a segment begins")
	var di: int = s.ship.room_with_system("drill")
	var dr: Room = s.ship.rooms[di]
	dr.sys_power = 2
	check(AlertsStrip.drill_stop(s).is_empty(), "a powered drill with a good bit cuts quietly")
	dr.sys_power = 0
	var key: String = AlertsStrip.power_key(s.ship, di)
	check_eq(key, "R", "the drill is the R row on the starter")
	check(_has_text(AlertsStrip.compute(s), "DRILL HAS NO POWER: press R"), "no power gets a chip naming the key")
	check(str(AlertsStrip.drill_stop(s)["notice"]).begins_with("DRILL HAS NO POWER"), "and the loud notice")
	dr.sys_power = 2
	s.drill.bit_broken = true
	s.drill.bit_wear = 1.0
	check(_has_text(AlertsStrip.compute(s), "BIT BROKEN: press B (%d spare)" % s.run.get_res("bits")), "a broken bit names B and the spares")
	s.run.resources["bits"] = 0
	check(_has_text(AlertsStrip.compute(s), "BIT BROKEN: no spares"), "no spares says so")
	check(str(AlertsStrip.drill_stop(s)["notice"]).contains("trading post"), "and where to get one")
	s.run.phase = "dialog"
	check(AlertsStrip.drill_stop(s).is_empty(), "nothing outside the drill phase")


func _has_text(list: Array[Dictionary], part: String) -> bool:
	for a: Dictionary in list:
		if str(a["text"]).contains(part):
			return true
	return false


func test_death_text_names_the_killer() -> void:
	var s: Sim = _run_sim()
	check(DeathScreen.hull_text(s).contains("The rock"), "no fight and no front: the rock")
	s.run.caught = true
	check(DeathScreen.hull_text(s).contains("front"), "caught by the pursuer: the front")
	s.combat.start_fight(s, "rival_light", false)
	check(DeathScreen.hull_text(s).contains("rival rig"), "in a fight: the rival rig")
	s.combat.boss = true
	check(DeathScreen.hull_text(s).contains("gate machine"), "at the gate: the gate machine")


func test_help_page_and_chip() -> void:
	var h: HelpView = HelpView.build(Control.new())
	check(not h.is_open(), "help starts closed")
	h.toggle()
	check(h.is_open(), "toggle opens it")
	h.toggle()
	check(not h.is_open(), "toggle closes it")
	check(TopBar.HELP_CHIP.size.x > 0.0 and TopBar.HELP_CHIP.position.y >= 50.0, "the chip sits in the lower row of the top bar")
	h.get_parent().free()
