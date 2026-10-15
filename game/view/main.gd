extends Node2D
## Entry point. Builds the lit cutaway in code and drives the simulation at the fixed 60 Hz physics
## tick (the sim never reads frame time, so a slow frame means slow motion, never a different result).
## Arguments after `--` choose the scenario and any capture, perf or test mode:
##   --scenario=<id> --seed=<n> --bot=<name> --duration=<s> --run-ticks=<n> --loop
##   --shots=<a,b> --out=<dir>   |   --capture=<dir> --stills=<n> --sheets=<m>
##   --perf=<file> --perf-seconds=<s>   |   --selftest
## Every bot-driven run ends by printing `FINAL tick=<n> hash=<h>` so tools can compare runs.

const PPM: float = 80.0
const DRILL_ZOOM: float = 1.0
const CUTAWAY_ZOOM: float = 1.1
const ROCK_BELOW_M: float = 4.0  ## Rock visible below the crown while drilling.
const SHIP_SHIFT_PX: float = 150.0  ## The ship sits right of centre, clear of the readout.
const STEER_DEG: float = 30.0

var args: Args
var db: DataDB
var run: ScenarioRun
var view: ShipView
var hud: Hud
var cam: Camera2D
var rock_view: RockView
var _held: Dictionary = {}
var _steer_sent: float = 0.0
var bot_driven: bool = false
var run_ticks: int = -1
var _finished: bool = false


func _ready() -> void:
	args = Args.from_cmdline()
	db = DataDB.load_all()
	var problems: PackedStringArray = db.lint()
	for p: String in problems:
		push_error("data: " + p)
	if args.has("selftest"):
		_selftest(problems)
		return
	if not _start_run():
		return
	run_ticks = args.get_int("run-ticks", -1)
	bot_driven = args.has("shots") or args.has("capture") or args.has("perf") or args.has("run-ticks")
	if DisplayServer.get_name() == "headless":
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
	var scenario: String = args.get_str("scenario", "fire_drill")
	if not db.scenarios.has(scenario):
		push_error("unknown scenario \"%s\"" % scenario)
		get_tree().quit(1)
		return false
	run = ScenarioRun.from_scenario(db, scenario, args.get_int("seed", 1234), args.get_str("bot", ""))
	if args.has("duration"):
		run.duration_ticks = roundi(args.get_float("duration") * Sim.TICK_HZ)
	if view != null:
		_clear_rock()
		view.rebind(run)
		hud.bind(run)
	return true


func _clear_rock() -> void:
	if rock_view != null:
		rock_view.queue_free()
		rock_view = null
	view.set_drilling(null)
	cam.zoom = Vector2(CUTAWAY_ZOOM, CUTAWAY_ZOOM)
	cam.position = view.center_px()
	_steer_sent = 0.0


func _drill_cam_target(d: DrillSim) -> Vector2:
	var bottom: float = (d.ship_pos.y + d.ship_size.y) * PPM
	return Vector2((d.ship_pos.x + d.ship_size.x * 0.5) * PPM - SHIP_SHIFT_PX, bottom + ROCK_BELOW_M * PPM - 540.0 / DRILL_ZOOM)


func _process(delta: float) -> void:
	if run == null or view == null:
		return
	var d: DrillSim = run.sim.drill
	if d.active and (rock_view == null or rock_view.serial != d.grid_serial):
		_begin_drill_view(d)
	if rock_view != null:
		cam.position = cam.position.lerp(_drill_cam_target(d), 1.0 - exp(-5.0 * delta))


## A drilling segment began: build its rock, hand the ship to the sim's position and frame it.
func _begin_drill_view(d: DrillSim) -> void:
	if rock_view != null:
		rock_view.queue_free()
	rock_view = RockView.new()
	rock_view.setup(d, PPM)
	add_child(rock_view)
	view.set_drilling(d)
	view.position = d.ship_pos * PPM
	cam.zoom = Vector2(DRILL_ZOOM, DRILL_ZOOM)
	cam.position = _drill_cam_target(d)


func _physics_process(_delta: float) -> void:
	if run == null or _finished:
		return
	if run.done():
		if args.has("loop"):
			_start_run()
		elif run_ticks > 0:
			finish()
		return
	run.step()
	if run_ticks > 0 and run.sim.tick >= run_ticks:
		finish()


## End a bot-driven run: print the final state hash and quit.
func finish(code: int = 0) -> void:
	if _finished:
		return
	_finished = true
	print("FINAL tick=%d hash=%s" % [run.sim.tick, run.sim.state_hash()])
	get_tree().quit(code)


func _unhandled_input(event: InputEvent) -> void:
	if bot_driven or run == null or view == null:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if not key.echo:
			_drill_key(key)
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# The player's click goes through the same command chain the bots use.
	var p: Vector2 = view.get_local_mouse_position() / PPM
	var room: int = run.sim.ship.room_at(p + Vector2(0, 0.06), -1)
	if room >= 0 and not run.sim.ship.crew.is_empty():
		var c: CrewMember = run.sim.ship.crew[0]
		run.sim.push({"type": "assign", "crew": c.id, "room": run.sim.ship.rooms[room].id})


## A and D (or the arrows) steer the drill to -30, 0 or +30 degrees, W and S add or remove a bar of
## drill power. Both go through the same command chain the bots use.
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
			run.sim.push({"type": "steer", "angle": _steer_sent})
	elif key.pressed and (code == KEY_W or code == KEY_S):
		var ri: int = run.sim.ship.room_with_system("drill")
		if ri >= 0:
			var room: Room = run.sim.ship.rooms[ri]
			var bars: int = clampi(room.sys_power + (1 if code == KEY_W else -1), 0, room.sys_max)
			run.sim.push({"type": "power", "room": room.id, "bars": bars})


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
	view.setup(run, PPM)
	add_child(view)
	cam = Camera2D.new()
	cam.position = view.center_px()
	cam.zoom = Vector2(CUTAWAY_ZOOM, CUTAWAY_ZOOM)
	add_child(cam)
	cam.make_current()
	hud = Hud.new()
	add_child(hud)
	hud.bind(run)


func _selftest(problems: PackedStringArray) -> void:
	var why: String = "" if problems.is_empty() else "data lint: " + problems[0]
	if why.is_empty():
		var r := ScenarioRun.from_scenario(db, "fire_drill", 1)
		for i: int in range(600):
			r.step()
		if r.sim.state_hash().length() != 16 or r.sim.events.is_empty():
			why = "the fire drill did not run"
	print("SELFTEST ok" if why.is_empty() else "SELFTEST FAIL: " + why)
	get_tree().quit(0 if why.is_empty() else 1)
