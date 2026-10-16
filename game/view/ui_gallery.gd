extends Control
## Dev tool: every HUD panel and overlay in the states that matter, on a stand-in backdrop.
##   godot --path game res://view/ui_gallery.tscn -- --gallery=<out dir>   (python tools/gallery.py)
## With --gallery=<dir> it saves one 1920x1080 PNG per state and quits. Without it, the gallery stays
## open and steps the sim live: Left and Right switch state, and every panel works with the mouse.
## The states are set up with test helpers (direct pokes at the sim). This is not the game.

const STATES: Array[String] = ["hud_calm", "hud_crisis", "hud_combat", "hud_drill", "dossier_page", "dossier_known", "dossier_greyed", "store",
		"map_start", "map_mid", "death_dead", "death_won", "codex"]
const SETTLE_S: float = 0.9

var db: DataDB
var sim: Sim = null
var top: TopBar
var power: PowerPanel
var crew: CrewCards
var alerts: AlertsStrip
var scanner: ScannerPanel
var weapons: WeaponCards
var enemy: EnemyPanel
var dossier: Dossier
var store: StoreView
var map: MapView
var death: DeathScreen
var codex: CodexView
var profile: Profile = Profile.new()
var _layer: Control
var _state_i: int = 0
var _live: bool = false


func _ready() -> void:
	var args: Args = Args.from_cmdline()
	db = DataDB.load_all()
	for p: String in db.lint():
		push_error("data: " + p)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make_theme()
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	sim = make_state(STATES[0])
	top = TopBar.build(_layer, sim)
	power = PowerPanel.build(_layer, sim)
	crew = CrewCards.build(_layer, sim)
	alerts = AlertsStrip.build(_layer, sim)
	scanner = ScannerPanel.build(_layer, sim)
	weapons = WeaponCards.build(_layer, sim)
	enemy = EnemyPanel.build(_layer, sim)
	dossier = Dossier.build(_layer, sim)
	store = StoreView.build(_layer, sim)
	map = MapView.build(_layer, sim)
	map.auto_open = false
	death = DeathScreen.build(_layer, sim, profile)
	codex = CodexView.build(_layer, sim, profile)
	if args.has("gallery") and DisplayServer.get_name() != "headless":
		_capture_all(args.get_str("gallery", "harness/out/gallery"))
	elif DisplayServer.get_name() != "headless":
		_live = true


func _physics_process(_delta: float) -> void:
	if _live and sim != null:
		sim.step()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if not _live or k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_RIGHT:
		show_state((_state_i + 1) % STATES.size())
	elif k.physical_keycode == KEY_LEFT:
		show_state((_state_i + STATES.size() - 1) % STATES.size())


func show_state(i: int) -> void:
	_state_i = i
	sim = make_state(STATES[i])
	top.bind(sim)
	power.bind(sim)
	crew.bind(sim)
	alerts.bind(sim)
	scanner.bind(sim)
	weapons.bind(sim)
	enemy.bind(sim)
	dossier.bind(sim)
	store.bind(sim)
	profile = make_profile(STATES[i])
	map.bind(sim)
	death.bind(sim, profile)
	codex.bind(sim, profile)
	if STATES[i].begins_with("map_"):
		map.open()
	elif STATES[i] == "codex":
		codex.open()
	if STATES[i] == "hud_combat":
		weapons.arm(1)
	top.snap()
	power.snap()
	crew.snap()


func _capture_all(out_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i: int in range(STATES.size()):
		show_state(i)
		await get_tree().create_timer(SETTLE_S).timeout
		await RenderingServer.frame_post_draw
		death.skip_typing()
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = out_dir.path_join(STATES[i] + ".png")
		var err: Error = img.save_png(path)
		print("GALLERY %s %s %dx%d %s" % [STATES[i], path, img.get_width(), img.get_height(), "ok" if err == OK else "FAILED"])
	print("GALLERY done")
	get_tree().quit()


# The states -------------------------------------------------------------------------------------

func _new_sim(known: Array = []) -> Sim:
	return Sim.new(db, 7, "light_drill", {"mode": "run", "known_codex": known})


const CODEX_KNOWN: Array = ["kola_well", "byrd_1947", "green_gallery", "topside_voice"]


## A fresh run (map and all) the way the game starts one.
func _run_sim(known: Array = []) -> Sim:
	return Sim.new(db, 11, "light_drill", {"mode": "run", "known_codex": known})


## Play the real run with the run bot until `count` more nodes have been visited and the ship idles.
func _play_nodes(s: Sim, count: int) -> void:
	var bot: Bot = Bot.make("run")
	var goal: int = _visited(s) + count
	var guard: int = 0
	while guard < 60 * 60 * 20 and not s.run.is_over():
		guard += 1
		if s.run.phase == "combat" and s.combat.active:
			s.combat.enemy_hull = 0  # Gallery shortcut: fights are won at once (the states are about the UI, not combat).
		bot.act(s)
		s.step()
		if _visited(s) >= goal and s.run.phase == "idle":
			return


func _visited(s: Sim) -> int:
	var n: int = 0
	for v: int in s.run.visited:
		n += v
	return n


## The profile a state shows (the codex state has some entries on file).
func make_profile(state_name: String) -> Profile:
	var p := Profile.new()
	if state_name == "codex":
		p.known_codex = PackedStringArray(CODEX_KNOWN)
	return p


func _run(s: Sim, seconds: float) -> void:
	for i: int in range(roundi(seconds * Sim.TICK_HZ)):
		s.step()


## A sim put in the named state (test helpers, not game rules).
func make_state(state_name: String) -> Sim:
	var s: Sim = _new_sim()
	match state_name:
		"map_start":
			s = _run_sim()
		"map_mid":
			s = _run_sim()
			_play_nodes(s, 4)
			s.run.move_pursuer(s, 2.2)
			_run(s, 0.2)
		"death_dead":
			s = _run_sim()
			_play_nodes(s, 3)
			s.run.add(s, "hull", -s.run.get_res("hull"))
			_run(s, 0.2)
		"death_won":
			s = _run_sim()
			_play_nodes(s, 5)
			s.run.end_run(s, "won", "gate")
			_run(s, 0.2)
		"codex":
			s = _run_sim(CODEX_KNOWN)
			_run(s, 0.1)
		"hud_calm":
			_run(s, 8.0)
		"hud_crisis":
			_crisis(s)
		"hud_combat":
			s.combat.start_fight(s, "rival_light", false)
			s.push({"type": "power", "room": "weapons", "bars": 2})
			_run(s, 3.0)
			s.push({"type": "target", "weapon": 0, "room": s.enemy.ship.rooms[1].id})
			_run(s, 1.0)
			s.ship.crew[0].hp = 58.0
		"hud_drill":
			s.push({"type": "begin_segment", "segment": "gallery", "depth_m": 70.0, "lateral_m": 8.0})
			s.push({"type": "steer", "angle": 16.0})
			_run(s, 14.0)
			s.push({"type": "steer", "angle": -12.0})
			_run(s, 0.5)
		"dossier_page":
			s.encounter.start_event(s, "kola_tapes")
			_run(s, 0.1)
		"dossier_known":
			s = _new_sim(["kola_well"])
			s.encounter.start_event(s, "kola_tapes")
			_run(s, 0.1)
		"dossier_greyed":
			s.push({"type": "power", "room": "bridge", "bars": 1})
			s.encounter.start_event(s, "byrd_signal")
			_run(s, 0.1)
		"store":
			s.run.add(s, "gems", 60 - s.run.get_res("gems"))
			s.run.add(s, "hull", -4)
			s.encounter.open_store(s, "crust_trader")
			_run(s, 0.1)
	return s


func _room(s: Sim, id: String) -> Room:
	return s.ship.rooms[s.ship.room_index(id)]


func _crisis(s: Sim) -> void:
	s.push({"type": "begin_segment", "segment": "gallery2", "depth_m": 70.0, "lateral_m": -6.0})
	_run(s, 6.0)
	var rd: Room = _room(s, "drill")
	var rw: Room = _room(s, "weapons")
	var rb: Room = _room(s, "bridge")
	var rc: Room = _room(s, "coolant")
	s.push({"type": "ignite", "room": "drill", "level": 0.7})
	s.push({"type": "breach", "room": "weapons", "size_m2": 0.25})
	rd.set_temp_c(102.0)
	rb.set_temp_c(76.0)
	rw.water_ml = roundi(float(rw.capacity_ml) * 0.35)
	s.systems.damage_room(s, s.player, rc.index, 1.6)
	s.drill.bit_wear = 0.86
	s.ship.crew[1].hp = 31.0
	s.ship.crew[2].hp = 0.0
	s.ship.crew[2].alive = false
	s.ship.crew[2].cause_of_death = "fire"
	_run(s, 1.5)
	s.run.add(s, "hull", -(s.run.get_res("hull") - 8))
	s.run.add(s, "coolant", -(s.run.get_res("coolant") - 2))


func _draw() -> void:
	# A stand-in for the world view: strata, a shaft and a tower block, so the panels read in context.
	var wr: Rect2 = RunScreen.WORLD_RECT
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.052, 0.058), true)
	for i: int in range(18):
		var y: float = wr.position.y + float(i) * 54.0
		var a: float = 0.05 + 0.03 * float(i % 3)
		draw_rect(Rect2(wr.position.x, y, wr.size.x, 20.0 + float((i * 7) % 24)), Color(0.35, 0.3, 0.25, a), true)
	var cx: float = wr.get_center().x
	draw_rect(Rect2(cx - 150.0, wr.position.y, 300, wr.size.y), Color(0.02, 0.02, 0.025), true)
	draw_rect(Rect2(cx - 130.0, 300, 260, 480), Color(0.16, 0.19, 0.22), true)
	draw_rect(Rect2(cx - 130.0, 300, 260, 480), UiTheme.BRASS_DARK, false, 3.0)
	for r: int in range(3):
		for c: int in range(2):
			draw_rect(Rect2(cx - 114.0 + c * 124, 320 + r * 150, 112, 130), Color(0.10, 0.12, 0.14), true)
			draw_rect(Rect2(cx - 114.0 + c * 124, 320 + r * 150, 112, 130), Color(UiTheme.AMBER, 0.25), false, 2.0)
