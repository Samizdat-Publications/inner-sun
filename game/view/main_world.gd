class_name MainWorld
extends RefCounted
## Builds Main's world and run screen (environment, ship view, combat view, camera, UI and the view
## layers), moved out of Main to keep that file short. Everything is stored on the Main `m`.

static func build(m: Main) -> void:
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
	m.add_child(env)
	var dark := CanvasModulate.new()
	dark.color = RockView.AMBIENT
	m.add_child(dark)
	m.view = ShipView.new()
	m.view.setup(m.run.sim, m.run.sim.player, Main.PPM)
	m.add_child(m.view)
	m.combat_view = CombatView.new()
	m.combat_view.setup(m.run.sim, m.view, Main.PPM, func() -> bool: return m.rock_view != null)
	m.add_child(m.combat_view)
	m.cam = Camera2D.new()
	m.cam.zoom = Vector2(Main.CUTAWAY_ZOOM, Main.CUTAWAY_ZOOM)
	m.cam.position = m._framed(m.view.center_px(), Main.CUTAWAY_ZOOM)
	m.add_child(m.cam)
	m.cam.make_current()
	m.screen = RunScreen.new()
	m.add_child(m.screen)
	m.screen.build(m.run.sim, m.profile)
	m.screen.new_run_requested.connect(m._start_run)
	m.douse = DouseLayer.new()
	m.douse.setup(m.run.sim, m.view, Main.PPM)
	m.view.add_child(m.douse)
	m.fx = DigFx.new()
	m.fx.setup(m.run.sim, m.screen.blast, Main.PPM)
	m.add_child(m.fx)
	m.structures = StructureLayer.new()
	m.structures.setup(m.run.sim, Main.PPM)
	m.add_child(m.structures)
	m.miner_layer = MinerLayer.new()
	m.miner_layer.setup(m.run.sim, m.screen.miner, Main.PPM)
	m.add_child(m.miner_layer)
	m.look_structure = m.args.get_str("look", "") == "structure"
	if m.args.has("aim"):
		var aim: PackedStringArray = m.args.get_str("aim", "").split(",")
		if aim.size() == 2:
			m.fx.aim_override = Vector2(float(aim[0]), float(aim[1]))
			m.miner_layer.aim_override = m.fx.aim_override
	var pickups := PickupLayer.new()
	pickups.setup(m.screen.tally.digs, Main.PPM)
	m.add_child(pickups)
	if m.run_mode and m._is_human() and m.profile != null and m.profile.runs == 0:
		m.screen.help.open()  # A fresh profile sees the help page first (never in bot captures).
	m._arm_hints()
	if m.args.has("arm-miner"):
		m.screen.miner.dev_arm = true  # Dev only: look at the miner's aim ring.
	if m.args.has("arm"):
		m.screen.weapons.armed = m.args.get_int("arm", -1)  # Dev only: look at the aiming highlights.
		m.screen.blast.armed = m.args.get_int("arm", -1) == BlastCard.launcher_slot(m.run.sim)  # ... and the blast ring.
	if m.args.has("debug-m.hud"):
		m.hud = Hud.new()
		m.add_child(m.hud)
		m.hud.bind(m.run)
	m.audio = AudioDirector.new()
	m.add_child(m.audio)
	m.audio.setup(func() -> Sim: return m.run.sim if m.run != null else null)
