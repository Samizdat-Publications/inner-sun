class_name UiSelfTest
extends TestCase
## Real input against the real run screen. Main's `--selftest` (which `tools/check.py` runs headless,
## inside a live scene tree) calls UiSelfTest.run(): it builds Main without a display
## (Main.build_headless), pushes InputEventKey and InputEventMouseButton through Viewport.push_input
## at the on-screen positions of the controls, and checks which commands reach the sim and that the
## world holds while the map or help is open. The test runner (tests/runner.gd) cannot do this: its
## tests run before the scene tree starts, so nothing there receives input.
## It is not a test_*.gd file on purpose; test_controls.gd covers the pure parts.

var _host: Node = null
var _main: Main = null


## Run every scenario; returns "" when all passed, else the failures.
static func run(host: Node) -> String:
	var t := UiSelfTest.new()
	t._host = host
	await t._all()
	return "; ".join(t.failures) if not t.failures.is_empty() else ""


func _all() -> void:
	await _scenario_help_and_map()
	await _scenario_power()
	await _scenario_crew_and_scanner()
	await _scenario_dossier()
	await _scenario_fight()
	await _scenario_dig_verbs()


# Helpers -----------------------------------------------------------------------------------------

func _tree() -> SceneTree:
	return _host.get_tree()


func _boot() -> Main:
	var scene: PackedScene = load("res://view/main.tscn")
	_main = scene.instantiate() as Main
	_main.test_args = Args.parse(PackedStringArray(["--seed=5", "--profile-dir=user://selftest_profile"]))
	_main.build_headless = true
	_tree().root.add_child.call_deferred(_main)  # The host is still inside its own _ready.
	await _tree().process_frame
	_main.set_physics_process(false)  # _frames steps it by hand: the count of steps is exact.
	await _tree().process_frame
	# Headless has no real pointer: tell the viewport the mouse is inside, or it drops mouse events.
	_tree().root.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	return _main


func _drop() -> void:
	_main.queue_free()
	await _tree().process_frame
	_main = null


## n frames: each is one Main physics step (by hand) and one real process frame.
func _frames(n: int) -> void:
	for i: int in range(n):
		_main._physics_process(1.0 / 60.0)
		await _tree().process_frame


func _key(code: Key, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		e.shift_pressed = shift
		_tree().root.push_input(e)


func _click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	_tree().root.push_input(mv, true)
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = down
		_tree().root.push_input(e, true)


## The last order of a kind that is queued and not yet stepped.
func _queued(s: Sim, kind: String) -> Dictionary:
	for i: int in range(s._pending.size() - 1, -1, -1):
		if str(s._pending[i].get("type", "")) == kind:
			return s._pending[i]
	return {}


func _power_row(m: Main, system: String) -> int:
	for row: int in range(m.screen.power._rows.size()):
		if m.run.sim.ship.rooms[m.screen.power._rows[row]].system == system:
			return row
	return -1


## Past the help page and into the first drill segment.
func _into_drill(m: Main) -> void:
	m.screen.help.close_help()
	m.screen.map.choose(m.run.sim.run.links_from_current()[0])
	await _frames(3)


# Scenarios ---------------------------------------------------------------------------------------

func _scenario_help_and_map() -> void:
	var m: Main = await _boot()
	var s: Sim = m.run.sim
	check(m.screen.help.is_open(), "a fresh profile opens the help page")
	await _frames(20)
	check_eq(s.tick, 0, "the world holds under the help page")
	_key(KEY_ESCAPE)
	check(not m.screen.help.is_open(), "Esc closes the help page")
	check(m.screen.map.is_open(), "the map is open in idle")
	var t0: int = s.tick
	await _frames(30)
	check_eq(s.tick, t0, "a human's world holds while the map is open")
	check_eq(m.screen.top.pause_text, "PAUSED: MAP", "the pause slot says why")
	var id: String = s.run.links_from_current()[0]
	_click(m.screen.map._pos(s.run.node(id)))
	check_eq(str(_queued(s, "choose_node").get("node", "")), id, "a map click queues choose_node for that node")
	await _frames(1)
	check_eq(s.run.phase, "drill", "the order applied while the map held the world")
	check(s.tick <= t0 + 2, "by stepping once, not running")
	await _frames(10)
	check_gt(float(s.tick), float(t0 + 8), "the world runs once the map is shut")
	var t1: int = s.tick
	_key(KEY_H)
	check(m.screen.help.is_open(), "H opens help")
	await _frames(20)
	check_eq(s.tick, t1, "the world holds while help is open")
	_key(KEY_H)
	check(not m.screen.help.is_open(), "H closes it")
	_click(m.screen.top.position + TopBar.HELP_CHIP.get_center())
	check(m.screen.help.is_open(), "the HELP chip opens it")
	check(RunScreen.should_step(s, false, false, true), "a bot or replay is never held")
	await _drop()


func _scenario_power() -> void:
	var m: Main = await _boot()
	await _into_drill(m)
	var s: Sim = m.run.sim
	var pp: PowerPanel = m.screen.power
	var row: int = _power_row(m, "drill")
	var room: Room = s.ship.rooms[pp._rows[row]]
	s.push({"type": "power", "room": room.id, "bars": 2})
	await _frames(1)
	check_eq(room.sys_power, 2, "the drill is at 2 bars")
	m.paused = true
	_key(PowerPanel.KEYS[row], true)
	_key(PowerPanel.KEYS[row], true)
	check_eq(s._pending.size(), 2, "two Shift presses queue two orders even while paused")
	check_eq(int(s._pending[0]["bars"]), 1, "the first asks for one bar")
	check_eq(int(s._pending[1]["bars"]), 0, "the second stacks to none")
	check_eq(pp.pending_bars(room.index), 0, "the panel shows the stacked wish before any step")
	_key(PowerPanel.KEYS[row])
	check_eq(int(_queued(s, "power")["bars"]), 1, "a plain press adds one to the pending wish")
	s._pending.clear()
	var bar: Rect2 = PowerPanel.bar_rect(row, 2, room.sys_max)
	_click(pp.position + bar.get_center())
	check_eq(int(_queued(s, "power").get("bars", -1)), 3, "a click on bar 3 asks for 3 bars")
	m.paused = false
	await _frames(2)
	check_eq(room.sys_power, 3, "the order applies on the next step")
	check_eq(pp.pending_bars(room.index), -1, "the pending wish clears after the step")
	await _drop()


func _scenario_crew_and_scanner() -> void:
	var m: Main = await _boot()
	await _into_drill(m)
	var s: Sim = m.run.sim
	_key(KEY_2)
	check_eq(m.screen.cards.selected_id, s.ship.crew[1].id, "key 2 selects the second crew member")
	var target: Room = s.ship.rooms[s.ship.room_with_system("helm")]
	var local: Vector2 = (target.rect.get_center() + Vector2(0.0, 0.3)) * Main.PPM
	_click(m.view.get_global_transform_with_canvas() * local)
	check_eq(str(_queued(s, "assign").get("crew", "")), s.ship.crew[1].id, "a room click sends the selected crew")
	check_eq(str(_queued(s, "assign").get("room", "")), target.id, "to the clicked room")
	s._pending.clear()
	var sc: ScannerPanel = m.screen.scanner
	check(sc.is_live(), "the scanner is live while drilling")
	_click(sc.position + Vector2(300.0, 200.0))
	var cmd: Dictionary = _queued(s, "steer")
	check(not cmd.is_empty(), "a click on the scanner screen queues a steer order")
	check_gt(float(cmd.get("angle", 0.0)), 5.0, "toward the clicked side")
	await _frames(2)
	check_gt(s.drill.target_heading_deg, 5.0, "the course holds, TGT shows the new value")
	# The same click again (after the course went back to 0) must send again, and a click while
	# paused shows its course at once (the sim only applies it on the next step).
	sc.queue_steer(0.0)
	await _frames(2)
	m.paused = true
	_click(sc.position + Vector2(300.0, 200.0))
	check(not _queued(s, "steer").is_empty(), "the same click again still sends")
	check_gt(sc.target_heading(), 5.0, "TGT shows a queued course while paused")
	check_lt(s.drill.target_heading_deg, 1.0, "though the sim has not applied it")
	m.paused = false
	await _frames(2)
	check_gt(s.drill.target_heading_deg, 5.0, "and it applies on unpause")
	var bits: int = s.run.get_res("bits")
	_key(KEY_B)
	check(not _queued(s, "change_bit").is_empty(), "B queues change_bit")
	await _frames(2)
	check_eq(s.run.get_res("bits"), bits - 1, "a bit is spent")
	await _drop()


func _scenario_dig_verbs() -> void:
	var m: Main = await _boot()
	await _into_drill(m)
	var s: Sim = m.run.sim
	var sc: ScannerPanel = m.screen.scanner
	_key(KEY_D)
	check_eq(sc.target_heading(), 15.0, "D steps the heading 15 degrees")
	_key(KEY_D)
	check_eq(sc.target_heading(), 30.0, "and again")
	_key(KEY_A)
	check_eq(sc.target_heading(), 15.0, "A steps back")
	_key(KEY_D, true)
	var cap: float = s.drill.max_heading_deg(s)  # D060: 45 until the helm upgrade, then 90 (hold depth).
	check_eq(sc.target_heading(), cap, "Shift plus D turns to the helm's cap")
	_key(KEY_A, true)
	check_eq(sc.target_heading(), -cap, "Shift plus A turns to the cap the other way")
	_key(KEY_S)
	check_eq(sc.target_heading(), 0.0, "S points straight down")
	await _frames(2)
	# The blast: power the launcher, F2 arms, a click on the rock fires, the card disarms.
	s.push({"type": "power", "room": "weapons", "bars": 1})
	await _frames(2)
	check(not m.screen.blast.armed, "not armed at first")
	_key(KEY_F2)
	check(m.screen.blast.armed, "F2 arms the charge launcher while drilling")
	_key(KEY_ESCAPE)
	check(not m.screen.blast.armed, "Esc disarms it")
	_key(KEY_F2)
	var d: DrillSim = s.drill
	var pt := Vector2(d.ship_pos.x + d.ship_size.x * 0.5 + 2.5, d.ship_pos.y + d.ship_size.y + 2.0)
	var at: Vector2 = m.rock_view.get_global_transform_with_canvas() * (pt * Main.PPM)
	check(RunScreen.WORLD_RECT.has_point(at), "the rock point is in the world area (%s)" % str(at))
	s._pending.clear()
	_click(at)
	var cmd: Dictionary = _queued(s, "blast")
	check(not cmd.is_empty(), "a click on the rock queues a blast")
	check(absf(float(cmd.get("x_m", -9.0)) - pt.x) < 0.2 and absf(float(cmd.get("y_m", -9.0)) - pt.y) < 0.2, "at the clicked point")
	check(not m.screen.blast.armed, "firing disarms")
	await _frames(3)
	check(m.screen.blast.visible, "the card is on screen while drilling")
	# The away miner: G arms it, Esc disarms, a click on the rock sends the selected crew member.
	check(not m.screen.miner.armed, "the miner order is not armed at first")
	_key(KEY_G)
	check(m.screen.miner.armed, "G arms the miner order")
	_key(KEY_ESCAPE)
	check(not m.screen.miner.armed, "Esc disarms it")
	_key(KEY_G)
	var mpt := Vector2(d.ship_pos.x + d.ship_size.x * 0.5 + 4.0, d.ship_pos.y + d.ship_size.y + 2.0)
	var mat: Vector2 = m.rock_view.get_global_transform_with_canvas() * (mpt * Main.PPM)
	s._pending.clear()
	_click(mat)
	var mcmd: Dictionary = _queued(s, "send_miner")
	check(not mcmd.is_empty(), "a click on the rock queues a send_miner")
	check_eq(str(mcmd.get("crew", "")), m.screen.cards.selected_id, "for the selected crew member")
	check(not m.screen.miner.armed, "sending disarms")
	s._pending.clear()
	# Douse: F puts out the worst fire; so does a click on its button.
	s.push({"type": "ignite", "room": "drill", "level": 0.5})
	await _frames(3)
	check_eq(DouseLayer.worst(s), "drill", "the drill room burns")
	s._pending.clear()
	_key(KEY_F)
	check_eq(str(_queued(s, "douse").get("room", "")), "drill", "F douses the worst fire")
	s._pending.clear()
	var k: float = 1.0 / m.get_viewport().get_canvas_transform().get_scale().x
	var btn: Rect2 = DouseLayer.button_rect(m.view.room_rect_px(s.ship.rooms[s.ship.room_index("drill")]), k)
	_click(m.douse.get_global_transform_with_canvas() * btn.get_center())
	check_eq(str(_queued(s, "douse").get("room", "")), "drill", "a click on the DOUSE button does too")
	check(_queued(s, "assign").is_empty(), "and is not also a crew order")
	# A top-deck fire (Stewart's build 5c run: the bracing room burned and douse did nothing).
	s.push({"type": "ignite", "room": "bracing", "level": 0.9})
	await _frames(3)
	check_eq(DouseLayer.worst(s), "bracing", "the bracing room burns worst")
	s._pending.clear()
	_key(KEY_F)
	check_eq(str(_queued(s, "douse").get("room", "")), "bracing", "F douses the top-deck fire")
	s._pending.clear()
	var k2: float = 1.0 / m.get_viewport().get_canvas_transform().get_scale().x
	var btn2: Rect2 = DouseLayer.button_rect(m.view.room_rect_px(s.ship.rooms[s.ship.room_index("bracing")]), k2)
	var at2: Vector2 = m.douse.get_global_transform_with_canvas() * btn2.get_center()
	_click(at2)
	check_eq(str(_queued(s, "douse").get("room", "")), "bracing", "a click on the top-deck DOUSE button at %s does too" % str(at2))
	await _drop()


func _scenario_dossier() -> void:
	var m: Main = await _boot()
	await _into_drill(m)
	var s: Sim = m.run.sim
	var pp: PowerPanel = m.screen.power
	var helm: int = _power_row(m, "helm")
	var hr: Room = s.ship.rooms[pp._rows[helm]]
	s.push({"type": "power", "room": hr.id, "bars": 0})
	await _frames(1)
	s.run.set_phase(s, "idle")
	s.encounter.start_event(s, "byrd_signal")
	await _frames(2)
	var d: Dossier = m.screen.dossier
	check(d.is_open(), "the dossier is open")
	check(d._buttons[1].disabled, "the helm option is greyed with the helm off")
	_key(PowerPanel.KEYS[helm])
	_key(PowerPanel.KEYS[helm])
	check_eq(int(_queued(s, "power").get("bars", -1)), 2, "power keys work under a dossier")
	await _frames(3)
	check_eq(hr.sys_power, 2, "and apply")
	check(not d._buttons[1].disabled, "the option lights as soon as the bars are in")
	var bar: Rect2 = PowerPanel.bar_rect(helm, 0, hr.sys_max)
	_click(pp.position + bar.get_center())
	check(not _queued(s, "power").is_empty(), "a power-panel click reaches the panel through the dossier")
	s._pending.clear()
	_key(KEY_2)
	check_eq(int(_queued(s, "choose").get("option", -1)), 1, "a digit picks the option")
	await _drop()


func _scenario_fight() -> void:
	var m: Main = await _boot()
	await _into_drill(m)
	var s: Sim = m.run.sim
	s.combat.start_fight(s, "rival_light", false)
	await _frames(2)
	check(m.paused, "a fight pauses a human's game")
	check(m.screen._banner.visible, "the banner says what to do")
	_key(KEY_SPACE)
	await _frames(1)
	check(not m.paused, "Space starts the fight")
	check(not m.screen._banner.visible, "the banner goes away")
	_key(KEY_SPACE)
	await _frames(1)
	await _aim_every_room(m)
	await _drop()


## Aim each weapon at each enemy room by a real F-key and a real click, including a room another
## weapon already targets (M1b: the second weapon must aim there too).
func _aim_every_room(m: Main) -> void:
	var s: Sim = m.run.sim
	var n: int = s.combat.player_side.size()
	_tree().root.size = Vector2i(1920, 1080)  # the real window shape (headless defaults to a square)
	await _frames(1)
	for i: int in range(4):
		m._ease_camera(s.drill, 10.0)  # the camera settles on the framing of both rigs
	for ri: int in range(s.enemy.ship.rooms.size()):
		for slot: int in range(mini(n, 2)):
			var other: int = 1 - slot
			if other < n:
				s.push({"type": "target", "weapon": other, "room": s.enemy.ship.rooms[ri].id})
			_key(KEY_F1 + slot)
			await _frames(1)
			check_eq(m.screen.weapons.armed, slot, "F%d arms slot %d" % [slot + 1, slot])
			var local: Vector2 = s.enemy.ship.rooms[ri].rect.get_center() * m.PPM + m.combat_view._origin_px()
			s._pending.clear()
			var at: Vector2 = m.combat_view.get_global_transform_with_canvas() * local
			_click(at)
			check_eq(str(_queued(s, "target").get("room", "")), s.enemy.ship.rooms[ri].id, "slot %d aims at enemy room %d (clicked %s)" % [slot, ri, str(at)])
			check_eq(int(_queued(s, "target").get("weapon", -1)), slot, "the order names slot %d" % slot)
			await _frames(1)
