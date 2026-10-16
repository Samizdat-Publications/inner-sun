extends TestCase
## The run-screen UI pieces: what they read from the sim and which commands they push. The pieces
## are Controls, but none of this needs a window: nothing here is drawn.

func _sim(known: Array = []) -> Sim:
	return Sim.new(db(), 7, "light_drill", {"mode": "run", "known_codex": known})


func test_calm_run_has_no_alerts() -> void:
	var s: Sim = _sim()
	run_seconds(s, 2.0)
	check_eq(AlertsStrip.compute(s).size(), 0, "a fresh run has no alerts")


func test_alerts_are_worst_first_and_name_the_room() -> void:
	var s: Sim = _sim()
	var weapons: Room = room(s, "weapons")
	weapons.breach_m2 = 0.2
	room(s, "drill").fire = 0.5
	s.run.add(s, "coolant", -(s.run.get_res("coolant") - 3))
	s.run.add(s, "hull", -(s.run.get_res("hull") - 5))
	var list: Array[Dictionary] = AlertsStrip.compute(s)
	check(list.size() >= 4, "fire, breach, hull and coolant all show")
	check_eq(str(list[0]["kind"]), "fire", "the fire is first")
	check_eq(str(list[0]["room"]), "drill", "and names the drill room")
	check(str(list[0]["text"]).contains("DRILL ROOM"), "the text names the room")
	var kinds: PackedStringArray = PackedStringArray()
	for a: Dictionary in list:
		kinds.append(str(a["kind"]))
	check(kinds.has("breach") and kinds.has("hull") and kinds.has("coolant"), "all kinds present: %s" % ",".join(kinds))
	for i: int in range(list.size() - 1):
		check(int(list[i]["sev"]) >= int(list[i + 1]["sev"]), "severity never rises down the list")


func test_alerts_cover_heat_flood_failure_damage_and_bit() -> void:
	var s: Sim = _sim()
	room(s, "bridge").set_temp_c(85.0)
	run_seconds(s, 0.5)
	room(s, "drill").set_temp_c(100.0)
	room(s, "coolant").sys_damage = 1.0
	var weapons: Room = room(s, "weapons")
	weapons.water_ml = weapons.capacity_ml / 2
	s.push({"type": "begin_segment", "segment": "t", "depth_m": 20.0, "lateral_m": 0.0})
	s.step()
	s.drill.bit_wear = 0.9
	var kinds: PackedStringArray = PackedStringArray()
	for a: Dictionary in AlertsStrip.compute(s):
		kinds.append(str(a["kind"]))
	for want: String in ["heat", "failed", "damaged", "flood", "bit"]:
		check(kinds.has(want), "alert kind %s present (got %s)" % [want, ",".join(kinds)])


func test_dossier_redactions() -> void:
	var s: Sim = _sim()
	var text: String = "Stamped [[kola_well:Kola SG-3]] and [odd] words."
	var hidden: String = Dossier.to_bbcode(text, s.run)
	check(hidden.contains("[bgcolor="), "unknown words are blacked out")
	check(hidden.contains("[lb]odd]"), "plain brackets are escaped")
	check(not hidden.contains("[["), "no raw redaction markup survives")
	var s2: Sim = _sim(["kola_well"])
	var shown: String = Dossier.to_bbcode(text, s2.run)
	check(not shown.contains("bgcolor"), "known words are not blacked out")
	check(shown.contains("Kola SG-3"), "known words show through")
	check_eq(Dossier.plain_text(text, s.run), "Stamped [REDACTED] and [odd] words.", "plain text for buttons, unknown")
	check_eq(Dossier.plain_text(text, s2.run), "Stamped Kola SG-3 and [odd] words.", "plain text for buttons, known")


func test_dossier_follows_the_encounter() -> void:
	var s: Sim = _sim()
	var d := Dossier.new()
	d.bind(s)
	check(not d.visible, "hidden with no event")
	s.encounter.start_event(s, "kola_tapes")
	s.step()
	d.bind(s)
	check(d.visible, "shown while an event is open")
	check_eq(d._buttons.size(), 3, "three options")
	for b: Button in d._buttons:
		check(not b.disabled, "every kola option is open")
	d.choose(1)
	s.step()
	check_eq(str(s.command_log[s.command_log.size() - 1]["type"]), "choose", "a click pushes choose")
	check_eq(int(s.command_log[s.command_log.size() - 1]["option"]), 1, "with the option index")
	d.bind(s)
	check_eq(d._buttons.size(), 1, "a page without options has only Continue")
	d.choose(0)
	s.step()
	check(not s.encounter.is_busy(), "Continue ends the event")
	d.bind(s)
	check(not d.visible, "and the overlay hides")
	d.free()


func test_dossier_greys_options_with_a_reason() -> void:
	var s: Sim = _sim()
	s.encounter.start_event(s, "byrd_signal")
	s.step()
	var d := Dossier.new()
	d.bind(s)
	check_eq(d._buttons.size(), 3, "three options")
	check(d._buttons[1].disabled, "triangulate is greyed with the helm at 1 bar")
	check(not d._buttons[0].disabled and not d._buttons[2].disabled, "the others are open")
	check_eq(d.reason_text("needs helm at 2 bars"), "REQUIRES: HELM AT 2 BARS", "the reason reads cleanly")
	check(d.reason_text("needs codex \"kola_well\"").contains("KOLA"), "a codex reason names the entry")
	s.push({"type": "power", "room": "bridge", "bars": 2})
	s.step()
	check_eq(s.encounter.option_block(s, 1), "", "the helm at 2 bars opens it")
	check(d.signature() != "", "signature exists")
	d.bind(s)
	check(not d._buttons[1].disabled, "and the button opens after a rebuild")
	d.free()


func test_store_view_lines_and_commands() -> void:
	var s: Sim = _sim()
	s.encounter.open_store(s, "crust_trader")
	s.step()
	var v := StoreView.new()
	v.bind(s)
	check(v.visible, "the store form shows")
	var stock: Array = s.encounter.current_store()["stock"]
	check_eq(v._buy_buttons.size(), stock.size(), "one buy button per stock line")
	check(not v._buy_buttons[0].disabled, "coolant is affordable with 15 gems")
	check(v._buy_buttons[5].disabled, "the lance is not")
	var gems: int = s.run.get_res("gems")
	v.buy(0)
	s.step()
	check_eq(s.run.get_res("gems"), gems - 6, "buying pushes a real buy command")
	v.bind(s)
	v.leave()
	s.step()
	check(not s.encounter.is_busy(), "Leave closes the store")
	v.bind(s)
	check(not v.visible, "and the form hides")
	v.free()


func test_store_info_text() -> void:
	var s: Sim = _sim()
	s.encounter.open_store(s, "crust_trader")
	var stock: Array = s.encounter.current_store()["stock"]
	check_eq(StoreView.info_text(s, stock[0]), "ON HAND %d" % s.run.get_res("coolant"), "supply lines show stock on hand")
	check(StoreView.info_text(s, stock[7]).contains("HELM"), "refits name the system")
	check(StoreView.info_text(s, stock[6]).length() > 0, "the hire line names the candidate or says none")


func test_power_panel_commands() -> void:
	var s: Sim = _sim()
	var p := PowerPanel.new()
	p.bind(s)
	var rooms: Array[int] = PowerPanel.powered_rooms(s.ship)
	check_eq(rooms.size(), 5, "five powered systems on the light drill")
	check_eq(PowerPanel.target_bars(2, 0), 1, "a click below the lit bars sets that many")
	check_eq(PowerPanel.target_bars(2, 1), 1, "clicking the last lit bar drops one")
	check_eq(PowerPanel.target_bars(1, 3), 4, "clicking above raises")
	# Row 3 is the drill room (helm, bracing, weapons, drill, coolant).
	var r: Rect2 = PowerPanel.bar_rect(3, 0, 4)
	check_eq(p.hit(r.get_center()), Vector2i(3, 0), "a bar rect hits its own bar")
	check_eq(p.hit(Vector2(5, 5)), Vector2i(-1, -1), "the title strip hits nothing")
	p.set_bars(2, 3)
	s.step()
	check_eq(str(s.command_log[s.command_log.size() - 1]["type"]), "power", "pushes a power command")
	check_eq(room(s, "weapons").sys_power, 1, "asked for three, the reactor has one bar left")
	p.change_bars(2, -1)
	s.step()
	check_eq(room(s, "weapons").sys_power, 0, "one bar fewer")
	p.set_bars(1, 0)
	s.step()
	p.set_bars(2, 3)
	s.step()
	check_eq(room(s, "weapons").sys_power, 3, "with bracing off, three bars fit")
	p.free()


func test_crew_cards_select() -> void:
	var s: Sim = _sim()
	var c := CrewCards.new()
	c.bind(s)
	check_eq(c.selected_id, "vasquez", "the first crew member starts selected")
	var got: Array[String] = []
	c.crew_selected.connect(func(id: String) -> void: got.append(id))
	c.select_index(1)
	check_eq(c.selected_id, "okafor", "select_index picks the second")
	check_eq(got.size(), 1, "and announces it")
	check_eq(c.index_at(CrewCards.card_rect(2).get_center()), 2, "a card rect hits its own card")
	c.select_index(9)
	check_eq(c.selected_id, "okafor", "an out of range index changes nothing")
	check_eq(CrewCards.job_text(""), "IDLE", "no job reads IDLE")
	check_eq(CrewCards.job_text("extinguish"), "EXTINGUISH", "jobs are named")
	c.free()


func test_scanner_reads_the_drill() -> void:
	var s: Sim = _sim()
	var sc := ScannerPanel.new()
	sc.bind(s)
	check(not sc.is_live(), "no signal while idle")
	s.push({"type": "begin_segment", "segment": "scan", "depth_m": 40.0, "lateral_m": 0.0})
	run_seconds(s, 2.0)
	check(sc.is_live(), "signal while drilling")
	sc._refresh_image()
	check_eq(sc._img.get_width(), s.drill.cols, "the image is as wide as the grid")
	check(sc._tex != null, "a texture exists")
	check_lt(absf(sc.angle_toward(Vector2(sc._crown_x_px(), 200.0))), 0.01, "straight below the crown is zero degrees")
	check_gt(sc.angle_toward(Vector2(sc._crown_x_px() + 100.0, 200.0)), 10.0, "to the right is positive")
	var water: Color = ScannerPanel.cell_color(ScannerPanel.K_WATER, 0.6, 3, 4)
	var rock: Color = ScannerPanel.cell_color(ScannerPanel.K_ROCK, 1.0, 3, 4)
	check(water.b > water.g and rock.g > rock.b, "water is blue, rock is green")
	sc.steer_by_mouse = true
	sc._steer_to(Vector2(sc._crown_x_px() + 60.0, 200.0))
	s.step()
	check_eq(str(s.command_log[s.command_log.size() - 1]["type"]), "steer", "a click on the screen steers")
	sc.free()


func test_top_bar_text() -> void:
	check_eq(TopBar.clock_text(252.0), "T+04:12", "the clock")
	check_eq(TopBar.phase_label("drill"), "DRILLING", "phase labels")
	check_eq(TopBar._spaced(1204), "1 204", "depth gets thousands spaces")
	var s: Sim = _sim()
	var t := TopBar.new()
	t.bind(s)
	t.paused = true
	t.snap()
	t.free()


func test_gallery_states_build() -> void:
	var g: Control = (load("res://view/ui_gallery.gd") as GDScript).new() as Control
	g.set("db", db())
	for state_name: String in ["hud_calm", "hud_crisis", "hud_drill", "dossier_page", "dossier_known", "dossier_greyed", "store"]:
		var s: Sim = g.call("make_state", state_name) as Sim
		check(s != null, "state %s builds" % state_name)
		if s == null:
			continue
		match state_name:
			"hud_crisis":
				check_gt(float(AlertsStrip.compute(s).size()), 4.0, "the crisis has several alerts")
				check(s.drill.active, "the crisis happens while drilling")
			"hud_drill":
				check(s.drill.active and s.run.phase == "drill", "the drill state is mid segment")
			"dossier_page", "dossier_known", "dossier_greyed":
				check(not s.encounter.event_id.is_empty(), "an event is open in %s" % state_name)
			"store":
				check(s.run.phase == "store", "the store is open")
	g.free()


func test_ui_files_have_no_em_dash() -> void:
	var dash: String = String.chr(0x2014)
	for dir: String in ["res://view/ui", "res://view/hud", "res://view/overlay"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var text: String = FileAccess.get_file_as_string(dir.path_join(f))
			check(not text.contains(dash), "%s/%s contains an em dash" % [dir, f])
	check(not FileAccess.get_file_as_string("res://view/ui_gallery.gd").contains(dash), "gallery has no em dash")
