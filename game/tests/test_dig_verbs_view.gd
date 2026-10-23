extends TestCase
## The view of the M1c dig verbs: the steering keys, the scanner's heading line and hatching, the blast
## card, the alerts, the douse buttons, the rockfall messages, the power panel's job lines, the death
## text and the help page's size. Real input against the live scene is in ui_selftest.gd. Nothing here
## draws; the look is judged on the captured stills.


func _sim(bracing_bars: int = 0, weapon_bars: int = 0, mode: String = "run") -> Sim:
	var s := Sim.new(db(), 11, "light_drill", {"mode": mode})
	s.push({"type": "power", "room": "bracing", "bars": bracing_bars})
	s.push({"type": "power", "room": "weapons", "bars": weapon_bars})
	run_seconds(s, 1.0)
	s.push({"type": "begin_segment", "segment": "v", "depth_m": 36.0, "lateral_m": 0.0})
	s.step()
	return s


func _code(s: Sim, id: String) -> int:
	for c: int in range(s.drill.materials.size()):
		if str(s.drill.materials[c].get("id", "")) == id:
			return c
	return -1


# Steering keys ---------------------------------------------------------------------------------

func test_steer_keys_step_by_fifteen_and_clamp() -> void:
	var sc := SteerControl.new()
	check_eq(sc.press(KEY_D, false, 0.0, 90.0), 15.0, "D steps +15")
	check_eq(sc.press(KEY_A, false, 15.0, 90.0), 0.0, "A steps -15")
	check_eq(sc.press(KEY_LEFT, false, -80.0, 90.0), -90.0, "the arrows work and stop at the limit")
	check_eq(sc.press(KEY_S, false, 60.0, 90.0), 0.0, "S points straight down")
	check_eq(sc.press(KEY_DOWN, false, -30.0, 90.0), 0.0, "Down does too")
	check_eq(sc.press(KEY_D, true, 0.0, 90.0), 90.0, "Shift plus D holds depth to the right")
	check_eq(sc.press(KEY_A, true, 0.0, 90.0), -90.0, "Shift plus A to the left")
	check(is_nan(sc.press(KEY_Q, false, 0.0, 90.0)), "other keys mean nothing here")
	check_eq(SteerControl.step_target(80.0, 1, 45.0), 45.0, "the limit follows the sim's tuning")


func test_steer_keys_repeat_while_held() -> void:
	var sc := SteerControl.new()
	var cur: float = sc.press(KEY_D, false, 0.0, 90.0)
	check(is_nan(sc.repeat(0.1, cur, 90.0)), "no repeat before the first pause")
	check(is_nan(sc.repeat(0.1, cur, 90.0)), "still waiting")
	var again: float = sc.repeat(0.1, cur, 90.0)
	check_eq(again, 30.0, "after the pause a held D steps again")
	check(is_nan(sc.repeat(0.05, again, 90.0)), "then every REPEAT_S, not every frame")
	check_eq(sc.repeat(0.1, again, 90.0), 45.0, "about 8 steps a second")
	var fresh := SteerControl.new()
	var steps: int = 0
	var t: float = fresh.press(KEY_D, false, -90.0, 90.0)
	for i: int in range(60):
		var n: float = fresh.repeat(1.0 / 60.0, t, 90.0)
		if not is_nan(n):
			steps += 1
			t = n
	check(steps >= 5 and steps <= 9, "one second of holding gives about 8 steps a second after the pause (%d)" % steps)
	t = 90.0
	check(is_nan(sc.repeat(1.0, t, 90.0)), "no step past the limit")
	sc.release(KEY_D)
	check(is_nan(sc.repeat(1.0, 0.0, 90.0)), "releasing the key stops the repeat")
	sc.press(KEY_D, false, 0.0, 90.0)
	sc.press(KEY_A, false, 0.0, 90.0)
	check_eq(sc.held_dir(), 0, "opposite keys cancel")
	sc.press(KEY_D, true, 0.0, 90.0)
	sc.clear()
	check_eq(sc.held_dir(), 0, "clear forgets the held keys")


# Scanner ---------------------------------------------------------------------------------------

func test_scanner_geometry() -> void:
	var rect := Rect2(20, 44, 360, 300)
	var ppm := Vector2(11.25, 10.0)
	var o := Vector2(200, 48)
	var down: Vector2 = ScannerExtras.heading_end(o, 0.0, ppm, rect)
	check(absf(down.x - o.x) < 0.01 and absf(down.y - rect.end.y) < 0.01, "heading 0 runs straight to the bottom edge")
	var level: Vector2 = ScannerExtras.heading_end(o, 90.0, ppm, rect)
	check(absf(level.y - o.y) < 0.5 and absf(level.x - rect.end.x) < 0.01, "heading 90 is a level line to the side edge")
	var left: Vector2 = ScannerExtras.heading_end(o, -90.0, ppm, rect)
	check(absf(left.x - rect.position.x) < 0.01, "and -90 runs to the other side")
	var mid: Vector2 = ScannerExtras.heading_end(o, 45.0, ppm, rect)
	check(rect.grow(0.5).has_point(mid) and mid.x > o.x and mid.y > o.y, "45 degrees ends on the screen edge")
	var m: Vector2 = ScannerExtras.screen_to_m(Vector2(200, 144), rect, 32.0, 6.0, 30.0)
	check(absf(m.x - 16.0) < 0.01 and absf(m.y - 16.0) < 0.01, "screen to meters: the middle column, 10 m below the crown")
	var back: Vector2 = ScannerExtras.m_to_screen(m, rect, 32.0, 6.0, 30.0)
	check(back.distance_to(Vector2(200, 144)) < 0.01, "and back")
	check(ScannerExtras.holding(85.0, 0.0) and ScannerExtras.holding(0.0, -90.0), "past 80 degrees is holding depth")
	check(not ScannerExtras.holding(45.0, 60.0), "a steep course is not")
	# A ring centred above the screen shows only where it crosses the glass.
	var runs: Array[PackedVector2Array] = ScannerExtras.ellipse_runs(Vector2(200, -60), 150.0, 140.0, rect)
	check(not runs.is_empty(), "the ring comes into view")
	for run: PackedVector2Array in runs:
		for p: Vector2 in run:
			check(rect.has_point(p), "every ring point is inside the screen")


func test_scanner_level_click_holds_depth_and_fault_rock_is_hatched() -> void:
	var s: Sim = _sim()
	var sc: ScannerPanel = ScannerPanel.build(Control.new(), s)
	var cx: float = sc._crown_x_px()
	check_eq(sc.angle_toward(Vector2(cx + 100.0, ScannerPanel.SCREEN.position.y + 2.0)), 90.0, "a click level with the crown steers to 90")
	check_eq(sc.angle_toward(Vector2(cx - 100.0, ScannerPanel.SCREEN.position.y + 2.0)), -90.0, "and -90 on the left")
	var low: float = sc.angle_toward(Vector2(cx + 100.0, ScannerPanel.SCREEN.position.y + 100.0))
	check(low > 30.0 and low < 80.0, "a click below the crown steers part way (%f)" % low)
	sc.queue_steer(90.0)
	check_eq(sc.target_heading(), 90.0, "the course can be 90 now")
	check_eq(s.drill.target_heading_deg, 0.0, "the sim has not stepped yet")
	s.step()
	check_eq(s.drill.target_heading_deg, 90.0, "and the sim takes it")
	sc._classify()
	check_eq(sc._kind[_code(s, "fault_rock")], ScannerPanel.K_FAULT, "fault rock has its own scanner kind")
	var hatch: Color = ScannerPanel.cell_color(ScannerPanel.K_FAULT, 0.7, 3, 0)
	check(hatch.r > hatch.b and hatch.r > 0.6, "the hatching is pale brown")
	check(ScannerPanel.cell_color(ScannerPanel.K_FAULT, 0.7, 1, 0) != hatch, "between the hatch lines the ground is darker")
	check(ScannerPanel.cell_color(ScannerPanel.K_ROCK, 0.7, 3, 0).g > ScannerPanel.cell_color(ScannerPanel.K_ROCK, 0.7, 3, 0).r, "plain rock stays green")
	sc.get_parent().free()


func test_scanner_click_fires_a_blast_while_armed() -> void:
	var s: Sim = _sim(0, 1)
	var sc: ScannerPanel = ScannerPanel.build(Control.new(), s)
	var card: BlastCard = BlastCard.build(Control.new(), s)
	sc.blast = card
	card.toggle()
	check(card.armed, "the card arms with the launcher powered")
	var d: DrillSim = s.drill
	var want := Vector2(d.ship_pos.x + d.ship_size.x * 0.5 + 2.0, d.ship_pos.y + d.ship_size.y + 4.0)
	sc._rows_shown = 60
	var screen_pt: Vector2 = ScannerExtras.m_to_screen(want, ScannerPanel.SCREEN, float(d.cols) * d.cell_m, d.ship_pos.y + d.ship_size.y, sc.look_m())
	var got: Vector2 = sc.point_m(screen_pt)
	check(got.distance_to(want) < 0.01, "the scanner maps a click back to the same rock point")
	check(card.aim(got), "the click fires")
	check(not card.armed, "firing disarms")
	var cmd: Dictionary = s._pending[s._pending.size() - 1]
	check_eq(str(cmd["type"]), "blast", "one blast command")
	check(absf(float(cmd["x_m"]) - want.x) < 0.02 and absf(float(cmd["y_m"]) - want.y) < 0.02, "at the clicked point")
	sc.get_parent().free()
	card.get_parent().free()


# Blast card ------------------------------------------------------------------------------------

func test_blast_card_says_why_and_arms() -> void:
	var s: Sim = _sim(0, 0)
	check_eq(BlastCard.launcher_slot(s), 1, "the charge launcher is the second weapon (F2)")
	check(BlastCard.shown_for(s), "the card shows while drilling")
	check_eq(BlastCard.status(s)["text"], "POWER WEAPONS (E)", "unpowered weapons say which key")
	check_eq(BlastCard.title_for(s), "BLAST: 4 CHARGES", "the charges are in the title")
	s.run.add(s, "charges", -3)
	check_eq(BlastCard.title_for(s), "BLAST: 1 CHARGE", "singular for one")
	s.run.add(s, "charges", -1)
	check_eq(BlastCard.reason_text(s, "no charges"), "NO CHARGES", "no charges")
	s.run.add(s, "charges", 2)
	var card: BlastCard = BlastCard.build(Control.new(), s)
	card.toggle()
	check(not card.armed, "a refusal does not arm the card")
	s.push({"type": "power", "room": "weapons", "bars": 1})
	s.step()
	check(bool(BlastCard.status(s)["ready"]), "powered with charges, it is ready")
	card.toggle()
	check(card.armed, "ready arms")
	card.toggle()
	check(not card.armed, "toggling again disarms")
	card.toggle()
	var far := Vector2(0.5, 0.5)
	var pending: int = s._pending.size()
	check(not card.aim(far), "a point out of range is refused here")
	check_eq(s._pending.size(), pending, "and pushes nothing")
	check(card.armed, "the card stays armed to try again")
	var p := Vector2(s.drill.ship_pos.x + 2.0, s.drill.ship_pos.y + s.drill.ship_size.y + 3.0)
	check(card.aim(p), "a point in range fires")
	s.step()
	check_eq(BlastCard.status(s)["text"], "CHARGE IN FLIGHT", "while the charge flies the card says so")
	run_seconds(s, 1.0)
	check(str(BlastCard.status(s)["text"]).begins_with("RELOADING"), "then it reloads")
	check(ScannerExtras.blast_word(s, false).begins_with("BLAST"), "the scanner shows the blast word")
	check_eq(ScannerExtras.blast_word(s, true), "BLAST ARMED", "armed says so")
	card.get_parent().free()


func test_blast_card_is_hidden_in_a_fight_and_without_a_segment() -> void:
	var s := Sim.new(db(), 11, "light_drill", {"mode": "run"})
	check(not BlastCard.shown_for(s), "no card without a segment")
	s.push({"type": "begin_segment", "segment": "v", "depth_m": 36.0, "lateral_m": 0.0})
	s.step()
	check(BlastCard.shown_for(s), "the card shows once drilling")
	s.combat.start_fight(s, "rival_light", false)
	check(not BlastCard.shown_for(s), "the fight console takes over in a fight")


# Alerts ----------------------------------------------------------------------------------------

func _texts(list: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for a: Dictionary in list:
		out.append(str(a["text"]))
	return out


func test_at_the_wall_alert() -> void:
	var s: Sim = _sim()
	check(not _texts(AlertsStrip.compute(s)).has("AT THE WALL: steer down (S)"), "no wall alert in open rock")
	s.drill.at_wall = true
	var stop: Dictionary = AlertsStrip.drill_stop(s)
	check_eq(str(stop.get("alert", "")), "AT THE WALL: steer down (S)", "the chip tells the player what to do")
	check(str(stop.get("notice", "")).contains("Press S"), "and the loud line names the key")
	check(_texts(AlertsStrip.compute(s)).has("AT THE WALL: steer down (S)"), "it is in the strip")


func test_fault_rock_ahead_alert_names_the_bracing_key() -> void:
	var s: Sim = _sim(0)
	var d: DrillSim = s.drill
	d.survey["faults"] = true
	check_eq(AlertsStrip.fault_ahead_m(s, 6.0), -1.0, "clear rock ahead")
	var code: int = _code(s, "fault_rock")
	var crown_row: int = int(ceil((d.ship_pos.y + d.ship_size.y) / d.cell_m))
	var col: int = int((d.ship_pos.x + d.ship_size.x * 0.5) / d.cell_m)
	for r: int in range(crown_row + 8, crown_row + 14):
		d.grid[r * d.cols + col] = code
	var m: float = AlertsStrip.fault_ahead_m(s, 6.0)
	check(m >= 3.0 and m <= 5.0, "fault rock about 4 m ahead is seen (%f)" % m)
	check(_texts(AlertsStrip.compute(s)).has("FAULT ROCK AHEAD: power bracing (W)"), "the alert names the bracing key")
	s.push({"type": "power", "room": "bracing", "bars": 2})
	run_seconds(s, 8.0)
	if s.systems.bracing_layers(s.player) > 0:
		check(not _texts(AlertsStrip.compute(s)).has("FAULT ROCK AHEAD: power bracing (W)"), "bracing up, no alert")
	d.survey["faults"] = false
	check_eq(AlertsStrip.fault_ahead_m(s, 6.0), -1.0, "a segment without faults never warns")


# Douse -----------------------------------------------------------------------------------------

func test_douse_buttons_follow_the_fires() -> void:
	var s: Sim = _sim(0, 0, "scenario")
	check(DouseLayer.burning(s).is_empty(), "no fire, no buttons")
	check_eq(DouseLayer.worst(s), "", "no worst fire")
	s.push({"type": "ignite", "room": "weapons", "level": 0.3})
	s.push({"type": "ignite", "room": "drill", "level": 0.6})
	s.step()
	var ids: Array[String] = DouseLayer.burning(s)
	check_eq(ids.size(), 2, "a button for each burning room")
	check_eq(DouseLayer.worst(s), "drill", "the worst fire is first")
	check_eq(ids[0], "drill", "worst first")
	var rp := Rect2(0, 0, 320, 240)
	var r: Rect2 = DouseLayer.button_rect(rp, 1.0)
	check(rp.encloses(r), "the button sits inside its room")
	var r2: Rect2 = DouseLayer.button_rect(rp, 2.0)
	check(absf(r2.size.x - 2.0 * r.size.x) < 0.01, "zoomed out the button grows to keep its size on screen")


func test_douse_reasons_are_said_in_words() -> void:
	var s: Sim = _sim(0, 0, "scenario")
	check_eq(DouseLayer.reason_text(s, ""), "", "nothing to say when it works")
	check_eq(DouseLayer.reason_text(s, "no coolant"), "NO COOLANT", "no coolant")
	check_eq(DouseLayer.reason_text(s, "venting"), "VENTING", "venting")
	check(DouseLayer.reason_text(s, "power coolant").begins_with("POWER COOLANT ("), "the coolant key is named")
	check(DouseLayer.reason_text(s, "not now").begins_with("COOLING DOWN"), "the cooldown")


# Callouts --------------------------------------------------------------------------------------

func test_callouts_for_rockfall_blast_and_douse() -> void:
	var s: Sim = _sim(0, 0, "scenario")
	var held: Dictionary = DigCallouts.message_for(s, {"kind": "rockfall", "absorbed": true, "room": "", "hull": 0})
	check_eq(str(held["text"]), "BRACING HELD", "an absorbed rockfall")
	check_eq(str(held["kind"]), "good", "in good news colours")
	var hit: Dictionary = DigCallouts.message_for(s, {"kind": "rockfall", "absorbed": false, "room": "bridge", "hull": 1})
	check_eq(str(hit["text"]), "ROCKFALL: HULL -1, BRIDGE DAMAGED", "a hit says hull and room")
	check_eq(str(hit["kind"]), "bad", "in alarm colours")
	var nohull: Dictionary = DigCallouts.message_for(s, {"kind": "rockfall", "absorbed": false, "room": "bridge", "hull": 0})
	check_eq(str(nohull["text"]), "ROCKFALL, BRIDGE DAMAGED", "no hull line when none was lost")
	var b: Dictionary = DigCallouts.message_for(s, {"kind": "blast", "cells": 14, "ore": 6, "gems": 0, "drained": false, "burned": true})
	check_eq(str(b["text"]), "BLAST: 14 CELLS, +6 ORE, GAS BURNED OFF", "a blast says what it freed")
	check_eq(str(DigCallouts.message_for(s, {"kind": "doused", "room": "drill"})["text"]), "DOUSED: DRILL ROOM", "a douse names the room")
	check_eq(str(DigCallouts.message_for(s, {"kind": "fire_out", "room": "drill", "by": "douse"})["text"]), "FIRE OUT", "the fire is out")
	check(DigCallouts.message_for(s, {"kind": "fire_out", "room": "drill", "by": "crew"}).is_empty(), "crew put-outs are not announced here")
	var bad: Dictionary = DigCallouts.message_for(s, {"kind": "bad_command", "type": "blast", "why": "no charges"})
	check_eq(str(bad["text"]), "BLAST REFUSED: NO CHARGES", "a refused blast says why")
	var bd: Dictionary = DigCallouts.message_for(s, {"kind": "bad_command", "type": "douse", "room": "drill", "why": "no coolant"})
	check_eq(str(bd["text"]), "DOUSE REFUSED: NO COOLANT", "a refused douse says why")
	check(DigCallouts.message_for(s, {"kind": "bad_command", "type": "power", "why": "x"}).is_empty(), "other refusals are not ours")
	check_eq(DigCallouts.warn_text(s), "", "no rockfall chip without one on its way")
	s.drill.verbs.rockfall_ticks = 72
	check_eq(DigCallouts.warn_text(s), "ROCKFALL IN 1.2 S", "the chip counts down")


# Power panel, death text, help, survey marks, sound ---------------------------------------------

func test_power_panel_has_a_job_line_for_every_system() -> void:
	var s: Sim = _sim()
	var pp: PowerPanel = PowerPanel.build(Control.new(), s)
	for ri: int in pp._rows:
		var sys: String = s.ship.rooms[ri].system
		check(PowerPanel.JOBS.has(sys), "a job line for %s" % sys)
		check(not str(PowerPanel.JOBS[sys]).contains(String.chr(0x2014)), "no em dash in %s" % sys)
	check_eq(str(PowerPanel.JOBS["helm"]), "turn and side cut", "the helm line")
	check_eq(str(PowerPanel.JOBS["bracing"]), "soaks rockfalls and hits", "the bracing line")
	check_eq(str(PowerPanel.JOBS["weapons"]), "guns and blast charges", "the weapons line")
	check_eq(str(PowerPanel.JOBS["drill"]), "speed, heat, noise", "the drill line")
	check_eq(str(PowerPanel.JOBS["coolant"]), "cooling, pumps, douse", "the coolant line")
	var last: Rect2 = PowerPanel.bar_rect(pp._rows.size() - 1, 0, 3)
	check(last.end.y + 26.0 < pp.size.y, "the last row's job line fits inside the panel")
	pp.get_parent().free()


func test_rockfall_death_has_its_own_line() -> void:
	var s: Sim = _sim()
	s.run.end_run(s, "dead", "rockfall")
	var d := DeathScreen.new()
	check(DeathScreen.CAUSE_TEXT.has("rockfall"), "the cause table has rockfall")
	check(DeathScreen.hull_text(s).contains("falling rock"), "hull_text names the rock that fell")
	check(d.cause_text(s).begins_with("Hull breached by falling rock"), "so does the cause line")
	check(not DeathScreen.hull_text(s).contains(String.chr(0x2014)), "no em dash")
	d.free()


func test_help_page_fits_its_frame_and_mentions_the_new_keys() -> void:
	var all: String = "\n".join(HelpView.CONTROLS) + "\n".join(HelpView.SYSTEMS) + "\n".join(HelpView.WHEN)
	for needle: String in ["Shift", "hold depth", "F2", "DOUSE", "BLAST", "fault rock", "wall"]:
		check(all.contains(needle), "the help page mentions " + needle)
	check(not all.contains(String.chr(0x2014)), "no em dash in the help text")
	var h: float = HelpView.content_height(UiTheme.mono())
	# The labels run a little taller than the font metrics say: keep 40 px of air above the close button.
	check(h <= HelpView.FRAME.size.y - 190.0, "the text (%d px) fits the frame with air (%d px)" % [int(h), int(HelpView.FRAME.size.y - 190.0)])


func test_survey_marks_show_faults() -> void:
	var info: Dictionary = SurveyMarks.material_info(db(), "crust")
	var w: PackedStringArray = SurveyMarks.words({"tier": 1, "tier_name": "fair", "ores": [], "gems": [], "gas": false, "water": false, "faults": true}, 3, info, false)
	check(w[w.size() - 1].contains("FAULT ROCK"), "the tooltip lists fault rock under AHEAD")
	var clear: PackedStringArray = SurveyMarks.words({"tier": 1, "tier_name": "fair", "ores": [], "gems": [], "gas": false, "water": false, "faults": false}, 3, info, false)
	check(clear[clear.size() - 1].ends_with("CLEAR"), "no faults, clear")


func test_new_events_have_sounds() -> void:
	for k: String in ["blast_fired", "blast", "rockfall_warn", "rockfall", "doused"]:
		check(SoundTable.EVENTS.has(k), "a sound for " + k)
		var stem: String = str((SoundTable.EVENTS[k] as Dictionary)["sound"])
		check(ResourceLoader.exists(SoundTable.path_of(stem)), "the file " + stem + " exists")


# Effects ---------------------------------------------------------------------------------------

func test_dig_fx_kicks_the_camera_on_blasts_and_rockfalls() -> void:
	var s: Sim = _sim()
	var fx := DigFx.new()
	fx.setup(s, null, 80.0)
	check_eq(fx.shake_offset(), Vector2.ZERO, "no kick at rest")
	s.emit("rockfall", {"absorbed": true, "room": "", "hull": 0})
	fx._process(0.016)
	check_eq(fx.kick, DigFx.KICK_HELD, "a held rockfall is a small kick")
	fx.kick = 0.0
	s.emit("rockfall", {"absorbed": false, "room": "bridge", "hull": 1})
	fx._process(0.016)
	check(fx.kick > DigFx.KICK_HELD + 1.0, "a hit is a bigger kick")
	fx.kick = 0.0
	s.emit("blast", {"x_m": 10.0, "y_m": 12.0, "cells": 10, "yield": {}, "ore": 0, "gems": 0, "drained": false, "burned": false})
	fx._process(0.016)
	check(fx.kick > DigFx.KICK_FALL, "a blast kicks hardest")
	check(fx.shake_offset().length() > 0.5, "the offset is non-zero while kicking")
	for i: int in range(80):
		fx._process(0.05)
	check_eq(fx.shake_offset(), Vector2.ZERO, "the kick dies away")
	s.emit("blast_fired", {"x_m": 10.0, "y_m": 12.0, "from_x_m": 5.0, "from_y_m": 8.0, "fuse_s": 0.6})
	fx._process(0.016)
	check_eq(fx._shots.size(), 1, "a charge in flight is tracked")
	fx._process(0.8)
	check_eq(fx._shots.size(), 0, "and gone after its fuse")
	fx.free()


## M1d: the last redraw when the fires go out is never skipped by the pacer, so no dead DOUSE button
## is left on screen (clicks and F find no fire under FIRE_MIN).
func test_douse_buttons_clear_when_the_fire_goes_out() -> void:
	var pacer := RedrawPacer.new()
	pacer._next = Time.get_ticks_usec() + 60000000  # Not due for a minute.
	check(DouseLayer.needs_redraw(false, true, pacer), "fire just went out: redraw at once, pacer or not")
	check(DouseLayer.needs_redraw(true, false, pacer), "fire just started: redraw at once")
	check(not DouseLayer.needs_redraw(true, true, pacer), "still burning: wait for the pacer")
	check(not DouseLayer.needs_redraw(false, false, pacer), "nothing burning: no redraws")
	pacer._next = 0
	check(DouseLayer.needs_redraw(true, true, pacer), "still burning and due: redraw")
