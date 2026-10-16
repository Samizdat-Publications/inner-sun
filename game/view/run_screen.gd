class_name RunScreen
extends CanvasLayer
## The run screen's UI on one CanvasLayer: the HUD panels (top bar, power, crew cards, alerts, seismic
## scanner) and the overlays (node map, dossier, store, codex, death screen), all reading one Sim.
## Every player action inside them is a command (sim.push). Main builds this once and rebinds it for a
## new run. Layout (1920 x 1080 design space): the world view is the free area WORLD_RECT.

signal new_run_requested

const WORLD_RECT: Rect2 = Rect2(300.0, 84.0, 1240.0, 900.0)  ## Between the panels (see view_m1.md).

var sim: Sim
var profile: Profile
var top: TopBar
var power: PowerPanel
var cards: CrewCards
var alerts: AlertsStrip
var scanner: ScannerPanel
var dossier: Dossier
var store: StoreView
var map: MapView
var codex: CodexView
var death: DeathScreen
var _root: Control
var _layer: Control


func build(p_sim: Sim, p_profile: Profile) -> void:
	sim = p_sim
	profile = p_profile
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.make_theme()
	add_child(_root)
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_layer)
	top = TopBar.build(_layer, sim)
	power = PowerPanel.build(_layer, sim)
	cards = CrewCards.build(_layer, sim)
	alerts = AlertsStrip.build(_layer, sim)
	scanner = ScannerPanel.build(_layer, sim)
	# Overlays last, in stacking order: map, dossier and store, codex, death (on top).
	map = MapView.build(_layer, sim)
	dossier = Dossier.build(_layer, sim)
	store = StoreView.build(_layer, sim)
	codex = CodexView.build(_layer, sim, profile)
	death = DeathScreen.build(_layer, sim, profile)
	death.new_run_requested.connect(func() -> void: new_run_requested.emit())
	top.current_row_getter = func() -> float: return _ship_row()
	_bind_rows()


func bind(p_sim: Sim, p_profile: Profile) -> void:
	sim = p_sim
	profile = p_profile
	top.bind(sim)
	power.bind(sim)
	cards.bind(sim)
	alerts.bind(sim)
	scanner.bind(sim)
	map.bind(sim)
	dossier.bind(sim)
	store.bind(sim)
	codex.bind(sim, profile)
	death.bind(sim, profile)
	_bind_rows()


func set_paused(p: bool) -> void:
	top.paused = p


## True while a modal overlay takes the player's attention (keys and world clicks go to it).
func overlay_open() -> bool:
	return map.is_open() or dossier.is_open() or store.is_open() or codex.is_open() or death.is_open()


## The crew member the player has selected (the first live one if none).
func selected_crew() -> CrewMember:
	var c: CrewMember = sim.ship.crew_by_id(cards.selected_id)
	if c != null and c.alive:
		return c
	for m: CrewMember in sim.ship.crew:
		if m.alive:
			return m
	return null


func _process(_delta: float) -> void:
	if sim == null:
		return
	power.keys_enabled = not overlay_open()


func _ship_row() -> float:
	if sim == null or sim.run.mode != "run" or sim.run.map.is_empty():
		return -1.0
	return sim.run.ship_row_f(sim)


func _bind_rows() -> void:
	if sim != null and sim.run.mode == "run" and not sim.run.map.is_empty():
		top.row_count = sim.run.map.size()
