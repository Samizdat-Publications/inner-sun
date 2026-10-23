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
##   --look=structure            (dev) the drilling camera frames the segment's buried structure
##   --hints-reset               (dev) forget which onboarding hints the profile has seen
##   --hint=<name>               (dev) show one onboarding hint about 2 s in (stills; not recorded)
## Every bot-driven run ends by printing `FINAL tick=<n> hash=<h>` so tools can compare runs.
## Normal play saves the profile and a replayable record of every run (game/meta), finished or not.

const PPM: float = 80.0
const CUTAWAY_ZOOM: float = 1.15
const COMBAT_TOP_PX: float = 90.0  ## The enemy panel at the top of the world area.
const COMBAT_BOTTOM_PX: float = 124.0  ## The weapon cards at the bottom of the world area.
const HUMAN_CAP_S: float = 6.0 * 3600.0  ## A human run never hits the stuck cap.
const NOTICE_GRACE_S: float = 1.5  ## The drill-stop notice shows only once the stop has lasted this long.
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
var depth_layers: DepthLayers  ## Far wall, silhouettes and dust, rebuilt with the rock.
var combat_view: CombatView
var paused: bool = false
var pause_layer: PauseLayer  ## The veil and the big PAUSED line over the world area.
var pause_demo: bool = false  ## Captures only (--pause-at=<s>): pause at that second and show the frozen world.
var _pause_at_tick: int = -1
var _pause_done: bool = false
var drill_zoom: float = 0.74  ## The mouse wheel sets it while drilling; kept for the run (DigCamera).
var bot_driven: bool = false
var replaying: bool = false
var run_ticks: int = -1
var test_args: Args = null  ## Tests only: used instead of the command line.
var build_headless: bool = false  ## Tests only: build the world and the UI even without a display.
var fx: DigFx  ## The dig verbs' effects in the world (blast aim and explosion, rockfall, side cutting).
var douse: DouseLayer  ## DOUSE buttons on burning rooms.
var structures: StructureLayer  ## The buried structure's room, glow, lamp and crate pops.
var miner_layer: MinerLayer  ## The away miner: aim, figure, headlamp.
var look_structure: bool = false  ## Dev only (--look=structure): the camera frames the buried structure.
var _steer: SteerControl = SteerControl.new()
var _finished: bool = false
var _in_fight: bool = false
var _fight_banner: bool = false
var _stop_s: float = 0.0  ## How long the drill-stop notice has been due (real seconds).
## Playtest input diary (view only, never part of the sim or the replay): raw left clicks and F presses
## as they arrive, with the UI control under the mouse, so a click a control swallowed shows up in the
## run record ("ui" in the summary). Stewart's build 5c run had no douse at all although he tried.
var _diary: Array[Dictionary] = []
const DIARY_MAX: int = 300
var _saved: bool = false


func _ready() -> void:
	args = test_args if test_args != null else Args.from_cmdline()
	db = DataDB.load_all()
	var problems: PackedStringArray = db.lint()
	for p: String in problems:
		push_error("data: " + p)
	if args.has("selftest"):
		await MainSelftest.run(self, problems)
		return
	if args.has("print-window-settings"):
		# Diagnostic (works headless, also in the exported build): does normal play get keyboard focus?
		print("WINDOW no_focus=%s template=%s" % [str(ProjectSettings.get_setting_with_override("display/window/size/no_focus")), str(OS.has_feature("template"))])
		get_tree().quit(0)
		return
	bot_driven = args.has("shots") or args.has("capture") or args.has("perf") or args.has("run-ticks")
	replaying = args.has("replay")
	pause_demo = args.has("pause-at")
	_pause_at_tick = roundi(args.get_float("pause-at", 0.0) * Sim.TICK_HZ) if pause_demo else -1
	run_mode = not replaying and (args.get_str("mode", "") == "run" or (not args.has("scenario") and not bot_driven))
	if run_mode:
		profile = Profile.load_from(Profile.dir_from_args(args))
		if args.has("hints-reset"):
			profile.hints_seen.clear()
	if not _start_run():
		return
	run_ticks = args.get_int("run-ticks", -1)
	if DisplayServer.get_name() == "headless" and not build_headless:
		return
	MainWorld.build(self)
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
		fx.bind(run.sim, screen.blast)
		structures.bind(run.sim)
		miner_layer.bind(run.sim, screen.miner)
		douse.bind(run.sim)
		_arm_hints()
		if hud != null:
			hud.bind(run)
	return true


## The onboarding hints (HintDirector) are for a person playing a full run: never in a bot, capture or
## replay run. The dev flag --hint=<name> forces one regardless (stills).
func _arm_hints() -> void:
	screen.hints.enabled = run_mode and _is_human() and profile != null
	screen.hints.force = args.get_str("hint", "")
	screen.hints.douse_rect = _douse_button_rect


## The screen rectangle of the worst burning room's DOUSE button (Rect2() when nothing burns).
func _douse_button_rect() -> Rect2:
	var id: String = DouseLayer.worst(run.sim)
	var ri: int = run.sim.ship.room_index(id)
	if ri < 0:
		return Rect2()
	var k: float = 1.0 / maxf(0.2, get_viewport().get_canvas_transform().get_scale().x)
	var local: Rect2 = DouseLayer.button_rect(view.room_rect_px(run.sim.ship.rooms[ri]), k)
	var xf: Transform2D = douse.get_global_transform_with_canvas()
	var a: Vector2 = xf * local.position
	return Rect2(a, xf * local.end - a)


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
	if depth_layers != null:
		depth_layers.queue_free()
		depth_layers = null
	view.set_drilling(null)
	view.position = Vector2.ZERO
	cam.zoom = Vector2(CUTAWAY_ZOOM, CUTAWAY_ZOOM)
	cam.position = _framed(view.center_px(), CUTAWAY_ZOOM)
	_steer.clear()


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
	if depth_layers != null:
		depth_layers.follow(cam.position, cam.zoom.x, view.center_px() + view.position, combat_view.active(), WorldFreeze.dt(world_frozen(), delta))
	if fx != null:
		cam.offset = fx.shake_offset()
	if d.active and not screen.overlay_open():
		var held_step: float = _steer.repeat(delta, screen.scanner.target_heading(), run.sim.db.tune("drill.max_heading_deg"))
		if not is_nan(held_step):
			screen.scanner.queue_steer(held_step)
	combat_view.armed = screen.weapons.armed
	view.selected_crew_id = screen.cards.selected_id
	combat_view.cam_zoom = cam.zoom.x
	var held: bool = _world_held()
	screen.set_paused(paused or held, screen.hold_label() if held and not paused else "PAUSED")
	MainWorld.set_frozen(self, world_frozen())
	if not paused:
		_fight_banner = false
	screen.set_banner(FIGHT_BANNER if _fight_banner and paused else "")
	# The stop notice waits NOTICE_GRACE_S: a drill powered a moment after a segment starts never flashes it.
	var stop: Dictionary = AlertsStrip.drill_stop(run.sim)
	var stop_notice: String = str(stop.get("notice", ""))
	_stop_s = _stop_s + delta if not stop_notice.is_empty() else 0.0
	var show_notice: bool = _stop_s >= NOTICE_GRACE_S and not (_fight_banner and paused) and not screen.overlay_open()
	screen.set_notice(stop_notice if show_notice else "", str(stop.get("kind", "")))


## The camera eases to its framing: the drill rock while there is one, the cutaway otherwise, and in a
## fight both towers with the rock between them.
func _ease_camera(d: DrillSim, delta: float) -> void:
	var k: float = 1.0 - exp(-5.0 * delta)
	var base_zoom: float = drill_zoom if rock_view != null else CUTAWAY_ZOOM
	var zoom: float = base_zoom
	var pos: Vector2 = _drill_cam_target(d) if rock_view != null else _framed(view.center_px(), base_zoom)
	if look_structure and rock_view != null and d.structures.has_structure():
		var sr: Rect2 = d.structures.rect
		zoom = clampf(0.82 * RunScreen.WORLD_RECT.size.x / (sr.size.x * PPM), 0.5, 1.5)
		pos = _framed(sr.get_center() * PPM, zoom)
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
	if depth_layers != null:
		depth_layers.queue_free()
	depth_layers = DepthLayers.new()
	depth_layers.setup(d, PPM)
	add_child(depth_layers)
	view.set_drilling(d)
	view.position = d.ship_pos * PPM
	cam.zoom = Vector2(drill_zoom, drill_zoom)
	cam.position = _drill_cam_target(d)


func _physics_process(_delta: float) -> void:
	if run == null or _finished:
		return
	if _pause_at_tick >= 0 and not _pause_done and run.sim.tick >= _pause_at_tick:
		_pause_done = true
		paused = true
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


## The visible pause: while the sim is paused or a page holds the world, the whole world view stands
## still and dims (WorldFreeze, PauseLayer). Bots are never frozen, except a capture that asks for it
## (--pause-at). Replays freeze too, so a paused replay looks paused. View only; the sim is untouched.
func world_frozen() -> bool:
	return (paused or _world_held()) and (_is_human() or replaying or pause_demo)


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
	if not _diary.is_empty():
		summary["ui"] = _diary.duplicate()
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


## Before any control sees it: note raw left clicks and F presses (what was under the mouse, the tick).
func _input(event: InputEvent) -> void:
	if run == null or bot_driven or replaying or not run_mode or _diary.size() >= DIARY_MAX:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var k: InputEventKey = event as InputEventKey
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var hc: Control = get_viewport().gui_get_hovered_control()
		_diary.append({"t": run.sim.tick, "in": "click", "x": roundi(mb.position.x), "y": roundi(mb.position.y),
				"over": str(hc.get_path()) if hc != null else "", "douse": douse.room_at(mb.position) if douse != null else ""})
	elif k != null and k.pressed and not k.echo and k.physical_keycode == KEY_F:
		_diary.append({"t": run.sim.tick, "in": "F", "worst": DouseLayer.worst(run.sim), "overlay": screen.overlay_open()})


func _unhandled_input(event: InputEvent) -> void:
	MainInput.unhandled(self, event)


## A screen point over the rock as segment meters (what a blast click aims at).
func world_to_m(screen_pos: Vector2) -> Vector2:
	return (rock_view.get_global_transform_with_canvas().affine_inverse() * screen_pos) / PPM


## The free area while the combat panels show: the world rect minus the enemy panel and weapon cards.
static func _combat_area() -> Rect2:
	var w: Rect2 = RunScreen.WORLD_RECT
	return Rect2(w.position.x + 10.0, w.position.y + COMBAT_TOP_PX, w.size.x - 20.0, w.size.y - COMBAT_TOP_PX - COMBAT_BOTTOM_PX)
