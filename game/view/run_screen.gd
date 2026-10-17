class_name RunScreen
extends CanvasLayer
## The run screen's UI on one CanvasLayer: the HUD panels (top bar, power, crew cards, alerts, seismic
## scanner) and the overlays (node map, dossier, store, codex, death screen), all reading one Sim.
## Every player action inside them is a command (sim.push). Main builds this once and rebinds it for a
## new run. Layout (1920 x 1080 design space): the world view is the free area WORLD_RECT.

signal new_run_requested

const WORLD_RECT: Rect2 = Rect2(340.0, 90.0, 1180.0, 938.0)  ## Between the panels, above the alert strip.
const NOTICE_W: float = 780.0
const REQ_TOAST_S: float = 8.0  ## How long the "requisitions loaded" toast stays up once the first dive shows.

var sim: Sim
var profile: Profile
var top: TopBar
var power: PowerPanel
var cards: CrewCards
var alerts: AlertsStrip
var scanner: ScannerPanel
var weapons: WeaponCards
var blast: BlastCard  ## The charge launcher's card while drilling.
var miner: MinerCard  ## The away miner's order card, right of the blast card.
var callouts: DigCallouts  ## Rockfall chip and the dig verbs' short messages.
var enemy: EnemyPanel
var dossier: Dossier
var store: StoreView
var map: MapView
var codex: CodexView
var death: DeathScreen
var requisitions: RequisitionsView  ## The death screen's own (above it); here for the tests and main.
var help: HelpView
var tally: DigTally  ## The dig tally and the arrival toast; owns the DigLog.
var structure_banner: StructureBanner  ## The break-in plaque for a buried structure.
var hints: HintDirector  ## One-time TOPSIDE hints that teach a verb (off in bot, capture and replay runs).
var _banner: Label
var _notice: Label  ## The line at the top of the world when the drill is stopped and why.
var _req_toast: Label  ## "TOPSIDE REQUISITIONS LOADED" with what each owned requisition put aboard.
var _req_left: float = 0.0  ## Seconds of the toast left (counts only while no overlay is open).
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
	weapons = WeaponCards.build(_layer, sim)
	blast = BlastCard.build(_layer, sim)
	scanner.blast = blast
	miner = MinerCard.build(_layer, sim, blast)
	miner.crew_id_getter = func() -> String: return cards.selected_id
	scanner.miner = miner
	enemy = EnemyPanel.build(_layer, sim)
	# Overlays last, in stacking order: map, dossier and store, codex, death (on top).
	map = MapView.build(_layer, sim)
	dossier = Dossier.build(_layer, sim)
	store = StoreView.build(_layer, sim)
	codex = CodexView.build(_layer, sim, profile)
	help = HelpView.build(_layer)
	death = DeathScreen.build(_layer, sim, profile)
	requisitions = death.requisitions
	death.new_run_requested.connect(func() -> void: new_run_requested.emit())
	tally = DigTally.build(_layer, sim)
	callouts = DigCallouts.build(_layer, sim)
	structure_banner = StructureBanner.build(_layer, sim)
	structure_banner.hide_when = func() -> bool: return overlay_open()
	hints = HintDirector.build(_layer, self)
	tally.hide_tally = func() -> bool: return overlay_open() or (sim.combat.active and sim.enemy != null)
	tally.hide_toast = func() -> bool: return death.is_open() or store.is_open() or dossier.is_open() or codex.is_open() or help.is_open()
	top.current_row_getter = func() -> float: return _ship_row()
	top.help_requested.connect(help.toggle)
	_build_banner()
	_bind_rows()
	_arm_req_toast()


func bind(p_sim: Sim, p_profile: Profile) -> void:
	sim = p_sim
	profile = p_profile
	top.bind(sim)
	power.bind(sim)
	cards.bind(sim)
	alerts.bind(sim)
	scanner.bind(sim)
	weapons.bind(sim)
	blast.bind(sim)
	miner.bind(sim)
	enemy.bind(sim)
	map.bind(sim)
	dossier.bind(sim)
	store.bind(sim)
	codex.bind(sim, profile)
	death.bind(sim, profile)
	requisitions = death.requisitions
	tally.bind(sim)
	callouts.bind(sim)
	structure_banner.bind(sim)
	hints.bind(sim, profile)
	_bind_rows()
	_arm_req_toast()


func _arm_req_toast() -> void:
	_req_toast.text = requisitions_text(sim)
	_req_left = REQ_TOAST_S if not _req_toast.text.is_empty() else 0.0
	_req_toast.visible = false


## The toast's text for a fresh run: one line per owned requisition ("Spare bits: +1 bits"), "" when
## the run has none (or is not a full run).
static func requisitions_text(s: Sim) -> String:
	if s == null or s.run.mode != "run":
		return ""
	var ids: PackedStringArray = Requisitions.owned_from(s.options)
	var table: Dictionary = s.db.table("requisitions")
	var lines := PackedStringArray()
	for id: String in ids:
		if table.has(id):
			var def: Dictionary = table[id]
			lines.append("%s: %s" % [str(def.get("name", id)), Requisitions.effect_line(def, s.db)])
	if lines.is_empty():
		return ""
	return "TOPSIDE REQUISITIONS LOADED\n" + "\n".join(lines)


func set_paused(p: bool, label: String = "PAUSED") -> void:
	top.paused = p
	top.pause_text = label


## The banner over the world area (the fight pause); an empty text hides it.
func set_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = not text.is_empty()


## The notice low over the world area (AlertsStrip.drill_stop); an empty text hides it.
func set_notice(text: String) -> void:
	if _notice.text != text:
		_notice.text = text
	_notice.visible = not text.is_empty()


## True while a human has the map or the help page open: the world holds still (main.gd).
func holds_world() -> bool:
	return sim != null and (map.is_open() or help.is_open())


func hold_label() -> String:
	return "PAUSED: HELP" if help.is_open() else "PAUSED: MAP"


## Whether the sim steps this physics frame. A human's paused or held world still takes one step
## per frame while commands wait, so an order given on the map or the help page applies at once.
## Bots and replays are never held (`human` false). Pure: the tests call it.
static func should_step(s: Sim, paused: bool, human: bool, held: bool) -> bool:
	if paused:
		return false
	if human and held and not s.has_pending():
		return false
	return true


## True while a modal overlay takes the player's attention (keys and world clicks go to it).
func overlay_open() -> bool:
	return map.is_open() or dossier.is_open() or store.is_open() or codex.is_open() or help.is_open() or death.is_open()


## The crew member the player has selected (the first live one if none).
func selected_crew() -> CrewMember:
	var c: CrewMember = sim.ship.crew_by_id(cards.selected_id)
	if c != null and c.alive:
		return c
	for m: CrewMember in sim.ship.crew:
		if m.alive:
			return m
	return null


func _process(delta: float) -> void:
	if sim == null:
		return
	# Power is the one order that stays open under the map and a dossier (options can need power).
	power.keys_enabled = not (store.is_open() or codex.is_open() or help.is_open() or death.is_open())
	weapons.keys_enabled = not overlay_open()
	blast.keys_enabled = not overlay_open()
	miner.keys_enabled = not overlay_open()
	scanner.keys_enabled = not overlay_open()
	_update_req_toast(delta)


func _update_req_toast(delta: float) -> void:
	var show: bool = _req_left > 0.0 and not overlay_open() and sim.drill.active
	_req_toast.visible = show
	if show:
		_req_left -= delta
		_req_toast.modulate.a = clampf(_req_left / 1.0, 0.0, 1.0)


func _ship_row() -> float:
	if sim == null or sim.run.mode != "run" or sim.run.map.is_empty():
		return -1.0
	return sim.run.ship_row_f(sim)


func _bind_rows() -> void:
	if sim != null and sim.run.mode == "run" and not sim.run.map.is_empty():
		top.row_count = sim.run.map.size()


func _build_banner() -> void:
	_banner = Label.new()
	_banner.position = Vector2(WORLD_RECT.position.x + 90.0, WORLD_RECT.position.y + 250.0)
	_banner.custom_minimum_size = Vector2(WORLD_RECT.size.x - 180.0, 0)
	_banner.size = Vector2(WORLD_RECT.size.x - 180.0, 0)
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.add_theme_color_override("font_color", UiTheme.TEXT)
	_banner.add_theme_stylebox_override("normal", UiTheme.box(Color(0.30, 0.06, 0.05, 0.92), UiTheme.ALARM, 3, 2, 18))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_layer.add_child(_banner)
	_notice = Label.new()
	# Top of the world, over the shaft and the top deck: never over the crown and the rock it steers
	# for (critic 007 found the old spot low over the world covered the drill head).
	_notice.position = Vector2(WORLD_RECT.get_center().x - NOTICE_W * 0.5, WORLD_RECT.position.y + 52.0)
	_notice.custom_minimum_size = Vector2(NOTICE_W, 0)
	_notice.size = Vector2(NOTICE_W, 0)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size", 23)
	_notice.add_theme_color_override("font_color", UiTheme.TEXT)
	_notice.add_theme_stylebox_override("normal", UiTheme.box(Color(0.32, 0.06, 0.04, 0.94), UiTheme.ALARM, 4, 2, 18))
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	_layer.add_child(_notice)
	_req_toast = Label.new()
	_req_toast.position = Vector2(WORLD_RECT.get_center().x - NOTICE_W * 0.5, WORLD_RECT.end.y - 230.0)
	_req_toast.custom_minimum_size = Vector2(NOTICE_W, 0)
	_req_toast.size = Vector2(NOTICE_W, 0)
	_req_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_req_toast.add_theme_font_size_override("font_size", 20)
	_req_toast.add_theme_color_override("font_color", UiTheme.AMBER)
	_req_toast.add_theme_stylebox_override("normal", UiTheme.box(Color(UiTheme.STEEL_DEEP, 0.92), UiTheme.BRASS, 3, 2, 16))
	_req_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_req_toast.visible = false
	_layer.add_child(_req_toast)
