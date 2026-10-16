class_name Main
extends Node2D
## Entry point. Builds the world view (the cutaway, the rock while drilling, the camera) and the run
## screen UI, and drives the simulation at the fixed 60 Hz physics tick (the sim never reads frame
## time, so a slow frame means slow motion, never a different result). Pause stops stepping; orders
## given while paused apply on the next step.
## Modes (arguments after `--`):
##   (none)                      normal play: a new run from the profile (user://, or --profile-dir)
##   --mode=run [--bot=<name>]   a whole run, optionally bot-driven (captures, demos)
##   --scenario=<id>             one situation (tests, captures, the M0 drills)
##   --replay=<record.json>      watch a saved run play back exactly (input off; Space pauses)
##   --fight=<ship id>           with --scenario: start a fight at once, weapons and bracing powered
##                               and aimed (to look at combat; dev only); --arm=<slot> shows aiming
## Also: --seed=<n> --bot=<name> --duration=<s> --run-ticks=<n> --loop --debug-hud
##   --shots=<a,b> --out=<dir> | --capture=<dir> --stills=<n> --sheets=<m> | --perf=<file> | --selftest
## Every bot-driven run ends by printing `FINAL tick=<n> hash=<h>` so tools can compare runs.
## Normal play saves the profile and a replayable record of every run (game/meta), finished or not.

const PPM: float = 80.0
const CUTAWAY_ZOOM: float = 1.15
const COMBAT_TOP_PX: float = 90.0  ## The enemy panel at the top of the world area.
const COMBAT_BOTTOM_PX: float = 124.0  ## The weapon cards at the bottom of the world area.
const STEER_DEG: float = 30.0
const HUMAN_CAP_S: float = 6.0 * 3600.0  ## A human run never hits the stuck cap.
const FIGHT_BANNER: String = "HOSTILE CONTACT. Paused. Power weapons (E) and bracing (W), arm a gun (F1, F2) and click an enemy room. Space to fight."

var args: Args
var db: DataDB
var run: Driver
var profile: Profile
var run_mode: bool = false
var view: ShipView
var hud: Hud  ## The M0 debug readout, only with --debug-hud.
var screen: RunScreen
var audio: AudioDirector
var cam: Camera2D
var rock_view: RockView
var combat_view: CombatView
var paused: bool = false
var drill_zoom: float = 0.74  ## The mouse wheel sets it while drilling; kept for the run (DigCamera).
var bot_driven: bool = false
var replaying: bool = false
var run_ticks: int = -1
var test_args: Args = null  ## Tests only: used instead of the command line.
var build_headless: bool = false  ## Tests only: build the world and the UI even without a display.
var _held: Dictionary = {}
var _steer_sent: float = 0.0
var _finished: bool = false
var _in_fight: bool = false
var _fight_banner: bool = false
var _saved: bool = false


func _ready() -> void:
	args = test_args if test_args != null else Args.from_cmdline()
	db = DataDB.load_all()
	var problems: PackedStringArray = db.lint()
	for p: String in problems:
		push_error("data: " + p)
	if args.has("selftest"):
		await _selftest(problems)
		return
	if args.has("print-window-settings"):
		# Diagnostic (works headless, also in the exported build): does normal play get keyboard focus?
		print("WINDOW no_focus=%s template=%s" % [str(ProjectSettings.get_setting_with_override("display/window/size/no_focus")), str(OS.has_feature("template"))])
		get_tree().quit(0)
		return
	bot_driven = args.has("shots") or args.has("capture") or args.has("perf") or args.has("run-ticks")
	replaying = args.has("replay")
	run_mode = not replaying and (args.get_str("mode", "") == "run" or (not args.has("scenario") and not bot_driven))
	if run_mode:
		profile = Profile.load_from(Profile.dir_from_args(args))
	if not _start_run():
		return
	run_ticks = args.get_int("run-ticks", -1)
	if DisplayServer.get_name() == "headless" and not build_headless:
		return
	_build_world()
	if args.has("shots") or args.has("capture"):
		var director := CaptureDirector.new()
		director.setup(self, args)
		add_child(director)
	if args.has("perf"):
		var perf := PerfRecorder.new()
		perf.setup(self, args)
		add_child(perf)


func _start_run() -> bool:
	drill_zoom = DigCamera.default_zoom(RunScreen.WORLD_RECT.size.x, PPM)
	_saved = false
	_in_fight = false
	_fight_banner = false
	if replaying:
		var rec: Dictionary = RunRecord.load_record(args.get_str("replay", ""))
		if rec.is_empty():
			push_error("cannot read the run record %s" % args.get_str("replay", ""))
			get_tree().quit(1)
			return false
		run = ReplayDriver.from_record(db, rec)
	elif run_mode:
		var run_seed: int = args.get_int("seed", int(Time.get_unix_time_from_system()) % 1000000)
		var cap_s: float = args.get_float("duration", HUMAN_CAP_S) if bot_driven else HUMAN_CAP_S
		run = FullRun.start(db, run_seed, args.get_str("bot", ""), profile.run_options(), "light_drill", cap_s)
	else:
		var scenario: String = args.get_str("scenario", "fire_drill")
		if not db.scenarios.has(scenario):
			push_error("unknown scenario \"%s\"" % scenario)
			get_tree().quit(1)
			return false
		run = ScenarioRun.from_scenario(db, scenario, args.get_int("seed", 1234), args.get_str("bot", ""))
		if args.has("duration"):
			run.duration_ticks = roundi(args.get_float("duration") * Sim.TICK_HZ)
	if args.has("fight") and not run_mode:
		_fight_demo(args.get_str("fight", "rival_light"))
	if view != null:
		_clear_rock()
		view.rebind(run.sim, run.sim.player)
		combat_view.rebind(run.sim)
		screen.bind(run.sim, profile)
		if hud != null:
			hud.bind(run)
	return true


## Dev only: a fight against `enemy_id` from tick 0, with power on the weapons and bracing, and both
## weapons aimed at the enemy's first rooms, so a capture shows rounds, blocks and bars at once.
func _fight_demo(enemy_id: String) -> void:
	var sim: Sim = run.sim
	sim.combat.start_fight(sim, enemy_id, false)
	if sim.enemy == null:
		return
	sim.push({"type": "power", "room": "drill", "bars": 0})
	sim.push({"type": "power", "room": "weapons", "bars": 3})
	sim.push({"type": "power", "room": "bracing", "bars": 2})
	for slot: int in range(sim.combat.player_side.size()):
		var rooms: Array[Room] = sim.enemy.ship.rooms
		sim.push({"type": "target", "weapon": slot, "room": rooms[mini(slot + 1, rooms.size() - 1)].id})


func _clear_rock() -> void:
	if rock_view != null:
		rock_view.queue_free()
		rock_view = null
	view.set_drilling(null)
	view.position = Vector2.ZERO
	cam.zoom = Vector2(CUTAWAY_ZOOM, CUTAWAY_ZOOM)
	cam.position = _framed(view.center_px(), CUTAWAY_ZOOM)
	_steer_sent = 0.0


## The camera position that puts world point `p` at the centre of the free area between the panels.
func _framed(p: Vector2, zoom: float) -> Vector2:
	var area_center: Vector2 = RunScreen.WORLD_RECT.get_center()
	return p + (Vector2(960.0, 540.0) - area_center) / zoom


func _drill_cam_target(d: DrillSim) -> Vector2:
	var crown_x: float = (d.ship_pos.x + d.ship_size.x * 0.5) * PPM
	var crown_y: float = (d.ship_pos.y + d.ship_size.y) * PPM
	var c: Vector2 = DigCamera.center_for(crown_x, crown_y, d.ship_size.y * PPM, RunScreen.WORLD_RECT.size.y, drill_zoom)
	return _framed(c, drill_zoom)


func _process(delta: float) -> void:
	PerfRecorder.frame_start()
	if run == null or view == null:
		return
	var d: DrillSim = run.sim.drill
	# A new segment builds its rock; after arrival the rock stays around the ship until the next one.
	if d.active and (rock_view == null or rock_view.serial != d.grid_serial):
		_begin_drill_view(d)
	_ease_camera(d, delta)
	combat_view.armed = screen.weapons.armed
	view.selected_crew_id = screen.cards.selected_id
	combat_view.cam_zoom = cam.zoom.x
	var held: bool = _world_held()
	screen.set_paused(paused or held, screen.hold_label() if held and not paused else "PAUSED")
	if not paused:
		_fight_banner = false
	screen.set_banner(FIGHT_BANNER if _fight_banner and paused else "")
	var stop_notice: String = str(AlertsStrip.drill_stop(run.sim).get("notice", ""))
	screen.set_notice("" if (_fight_banner and paused) or screen.overlay_open() else stop_notice)


## The camera eases to its framing: the drill rock while there is one, the cutaway otherwise, and in a
## fight both towers with the rock between them.
func _ease_camera(d: DrillSim, delta: float) -> void:
	var k: float = 1.0 - exp(-5.0 * delta)
	var base_zoom: float = drill_zoom if rock_view != null else CUTAWAY_ZOOM
	var zoom: float = base_zoom
	var pos: Vector2 = _drill_cam_target(d) if rock_view != null else _framed(view.center_px(), base_zoom)
	if combat_view.active():
		var b: Rect2 = combat_view.bounds_px()
		zoom = minf(base_zoom, minf(_combat_area().size.x / b.size.x, _combat_area().size.y / b.size.y))
		pos = b.get_center() + (Vector2(960.0, 540.0) - _combat_area().get_center()) / zoom
	var z: float = lerpf(cam.zoom.x, zoom, k)
	cam.zoom = Vector2(z, z)
	cam.position = cam.position.lerp(pos, k)


## A drilling segment began: build its rock, hand the ship to the sim's position and frame it.
func _begin_drill_view(d: DrillSim) -> void:
	if rock_view != null:
		rock_view.queue_free()
	rock_view = RockView.new()
	rock_view.setup(d, PPM)
	add_child(rock_view)
	move_child(rock_view, 0)
	view.set_drilling(d)
	view.position = d.ship_pos * PPM
	cam.zoom = Vector2(drill_zoom, drill_zoom)
	cam.position = _drill_cam_target(d)


func _physics_process(_delta: float) -> void:
	if run == null or _finished:
		return
	if run.done() or (run_mode and run.sim.run.is_over()):
		_on_run_over()
		if args.has("loop"):
			_start_run()
		elif run_ticks > 0:
			finish()
		return
	if not RunScreen.should_step(run.sim, paused, _is_human(), _world_held()):
		return
	var t0: int = Time.get_ticks_usec()
	run.step()
	PerfRecorder.span(PerfRecorder.SPAN_SIM, Time.get_ticks_usec() - t0)
	_watch_fight()
	if run_ticks > 0 and run.sim.tick >= run_ticks:
		finish()


## A person is playing: not a bot, a capture or a replay. Only a human's world pauses and holds.
func _is_human() -> bool:
	return not bot_driven and not replaying


## True while a human has the node map or the help page open: time stops (orders still apply).
func _world_held() -> bool:
	return _is_human() and screen != null and screen.holds_world()


## When a fight begins a human's game pauses, so the weapons and bracing can be powered and aimed
## before the first round (the banner says what to do). Bots and replays never pause.
func _watch_fight() -> void:
	var fighting: bool = run.sim.combat.active and run.sim.enemy != null
	if fighting and not _in_fight and _is_human() and screen != null:
		paused = true
		_fight_banner = true
	_in_fight = fighting


## A run ended (or the window is closing mid-run): fold it into the profile and save its record once.
func _on_run_over() -> void:
	if _saved or not run_mode or profile == null or bot_driven:
		return
	_saved = true
	var summary: Dictionary = run.sim.run.summary(run.sim)
	if not run.sim.run.is_over():
		summary["result"] = "abandoned"
	profile.merge_run(summary, run.sim.run.learned)
	profile.save()
	RunRecord.save(profile.dir, run.sim, summary, Time.get_datetime_string_from_system(false).replace(":", "").replace("-", "").replace("T", "-"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and run != null:
		_on_run_over()


## End a bot-driven run: print the final state hash and quit.
func finish(code: int = 0) -> void:
	if _finished:
		return
	_finished = true
	print("FINAL tick=%d hash=%s" % [run.sim.tick, run.sim.state_hash()])
	get_tree().quit(code)


func _unhandled_input(event: InputEvent) -> void:
	if replaying and run != null:
		var k: InputEventKey = event as InputEventKey
		if k != null and k.pressed and not k.echo and k.keycode == KEY_SPACE:
			paused = not paused
		return
	if bot_driven or run == null or view == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if not key.echo:
			_key(key)
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or screen.overlay_open():
		return
	# The wheel over the world area zooms the drilling camera (the choice lasts for the run).
	var wheel: int = 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else (-1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0)
	if wheel != 0:
		if rock_view != null and RunScreen.WORLD_RECT.has_point(mb.position):
			drill_zoom = DigCamera.stepped(drill_zoom, wheel)
			get_viewport().set_input_as_handled()
		return
	# In a fight, a left click on an enemy room with a weapon armed aims it (a command, like all orders).
	var wc: WeaponCards = screen.weapons
	if mb.button_index == MOUSE_BUTTON_LEFT and wc.armed >= 0 and combat_view.active():
		var er: int = combat_view.enemy_room_at(mb.position)
		if er >= 0:
			run.sim.push({"type": "target", "weapon": wc.armed, "room": run.sim.enemy.ship.rooms[er].id})
			wc.disarm()
			get_viewport().set_input_as_handled()
			return
	# The player's click goes through the same command chain the bots use: left sends the selected
	# crew member to the room, right releases them back to their own judgement.
	var c: CrewMember = screen.selected_crew()
	if c == null:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (view.get_global_transform_with_canvas().affine_inverse() * mb.position) / PPM
		var room: int = run.sim.ship.room_at(p + Vector2(0, 0.06), -1)
		if room >= 0:
			run.sim.push({"type": "assign", "crew": c.id, "room": run.sim.ship.rooms[room].id})
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		run.sim.push({"type": "release", "crew": c.id})


func _key(key: InputEventKey) -> void:
	var code: Key = key.keycode
	if key.pressed and code == KEY_H and screen.help.is_open():
		screen.help.close_help()
		return
	if key.pressed and code == KEY_H and not screen.codex.is_open() and not screen.death.is_open():
		screen.help.open()
		return
	if key.pressed and code == KEY_SPACE and not screen.overlay_open():
		paused = not paused
		return
	if key.pressed and code >= KEY_1 and code <= KEY_3 and not screen.overlay_open():
		screen.cards.select_index(int(code - KEY_1))
		return
	_drill_key(key)


## A and D (or the arrows) steer the drill to -30, 0 or +30 degrees while drilling. Drill power is on
## the power panel. Commands, like the bots use.
func _drill_key(key: InputEventKey) -> void:
	var d: DrillSim = run.sim.drill
	if not d.active:
		return
	var code: Key = key.keycode
	if key.pressed:
		_held[code] = true
	else:
		_held.erase(code)
	var dir: float = 0.0
	if _held.has(KEY_D) or _held.has(KEY_RIGHT):
		dir += 1.0
	if _held.has(KEY_A) or _held.has(KEY_LEFT):
		dir -= 1.0
	if code == KEY_A or code == KEY_D or code == KEY_LEFT or code == KEY_RIGHT:
		if dir * STEER_DEG != _steer_sent:
			_steer_sent = dir * STEER_DEG
			screen.scanner.queue_steer(_steer_sent)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.environment = e
	add_child(env)
	var dark := CanvasModulate.new()
	dark.color = RockView.AMBIENT
	add_child(dark)
	view = ShipView.new()
	view.setup(run.sim, run.sim.player, PPM)
	add_child(view)
	combat_view = CombatView.new()
	combat_view.setup(run.sim, view, PPM, func() -> bool: return rock_view != null)
	add_child(combat_view)
	cam = Camera2D.new()
	cam.zoom = Vector2(CUTAWAY_ZOOM, CUTAWAY_ZOOM)
	cam.position = _framed(view.center_px(), CUTAWAY_ZOOM)
	add_child(cam)
	cam.make_current()
	screen = RunScreen.new()
	add_child(screen)
	screen.build(run.sim, profile)
	screen.new_run_requested.connect(_start_run)
	var pickups := PickupLayer.new()
	pickups.setup(screen.tally.digs, PPM)
	add_child(pickups)
	if run_mode and _is_human() and profile != null and profile.runs == 0:
		screen.help.open()  # A fresh profile sees the help page first (never in bot captures).
	if args.has("arm"):
		screen.weapons.armed = args.get_int("arm", -1)  # Dev only: look at the aiming highlights.
	if args.has("debug-hud"):
		hud = Hud.new()
		add_child(hud)
		hud.bind(run)
	audio = AudioDirector.new()
	add_child(audio)
	audio.setup(func() -> Sim: return run.sim if run != null else null)


func _selftest(problems: PackedStringArray) -> void:
	var why: String = "" if problems.is_empty() else "data lint: " + problems[0]
	if why.is_empty():
		var r := ScenarioRun.from_scenario(db, "fire_drill", 1)
		for i: int in range(600):
			r.step()
		if r.sim.state_hash().length() != 16 or r.sim.events.is_empty():
			why = "the fire drill did not run"
	if why.is_empty():
		var fr: FullRun = FullRun.start(db, 1, "run", {})
		for i: int in range(600):
			fr.step()
		if fr.sim.run.phase == "scenario" or fr.sim.tick != 600:
			why = "a full run did not start"
	if why.is_empty():
		# Real input against the run screen (tests/ is not in the export: skipped there).
		var ui: GDScript = load("res://tests/ui_selftest.gd") as GDScript
		if ui != null:
			var ui_why: Variant = await ui.call("run", self)
			why = str(ui_why)
	print("SELFTEST ok" if why.is_empty() else "SELFTEST FAIL: " + why)
	get_tree().quit(0 if why.is_empty() else 1)


## The free area while the combat panels show: the world rect minus the enemy panel and weapon cards.
static func _combat_area() -> Rect2:
	var w: Rect2 = RunScreen.WORLD_RECT
	return Rect2(w.position.x + 10.0, w.position.y + COMBAT_TOP_PX, w.size.x - 20.0, w.size.y - COMBAT_TOP_PX - COMBAT_BOTTOM_PX)
