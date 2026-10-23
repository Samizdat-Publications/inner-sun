class_name ScannerPanel
extends Control
## The seismic scanner: a green CRT showing the rock ahead of the drill (30 m below the crown, the
## whole 32 m width of the segment). Materials are shades: rock by hardness, hard rock as bright
## hatching, ore and gems as twinkling glints, water pockets dark blue, voids black. The ship's
## heading is a line from the crown, the steered target heading dashed; the next node's depth is a
## line across the screen. A sweep scans down the screen. Outside the drill phase it reads NO SIGNAL.
## Click or drag on the screen to steer toward that point (pushes {"type": "steer", "angle": deg}, up
## to the helm's cap: 45 degrees, hold depth at 90 after the helm upgrade); set `steer_by_mouse = false` if main.gd steers with the
## keys only. With the blast armed (`blast` is the BlastCard) a click fires at that point instead.
## Fault rock is pale brown hatching; the extras (heading ray, HOLD DEPTH, AT THE WALL, the blast ring)
## live in ScannerExtras.
## Range (D060): rock, ore glints, water, gas, faults and structures show only within
## DrillSim.scanner_range_m (about 10 m of the drill head, 16 m once the helm is upgraded); outside
## it the glass is dim static behind a range ring with a small "RANGE 10 M" label. A click outside
## the range still steers (only the direction counts); a blast or miner click there is refused on
## its card with the usual out-of-range words. Steering is capped at DrillSim.max_heading_deg.
##
## Mount (main.gd, on the HUD CanvasLayer, 1920x1080 design space):
##   var scanner: ScannerPanel = ScannerPanel.build(layer, sim)
##   scanner.bind(new_sim)

const SIZE: Vector2 = Vector2(400, 420)
const SCREEN: Rect2 = Rect2(20, 44, 360, 300)
const LOOK_AHEAD_M: float = 30.0
const UPDATE_S: float = 0.1
const MAX_GLINTS: int = 90
const SWEEP_HZ: float = 0.45
const STEER_STEP_DEG: float = 1.0
const BIT_WEAR_OFFER: float = 0.5  ## The new-bit button shows once the bit is worn past this.
const BIT_BUTTON: Rect2 = Rect2(184, 386, 196, 28)
const OUT_OF_RANGE: Color = Color(0.0, 0.026, 0.018)  ## The glass beyond the scanner's range.

var sim: Sim = null
var steer_by_mouse: bool = true
var keys_enabled: bool = true  ## B fits a new bit; main turns this off while an overlay is open.
var blast: BlastCard = null  ## Set by RunScreen: a click fires a blast while it is armed.
var miner: MinerCard = null  ## Set by RunScreen: a click sends the miner while it is armed.

var _t: float = 0.0
var _pacer: RedrawPacer = RedrawPacer.new()  ## Redraws at most 60 times a second.
var _since: float = 99.0
var _serial: int = -1
var _img: Image = null
var _tex: ImageTexture = null
var _rows_shown: int = 0
var _frac: float = 0.0
var _kind: PackedInt32Array = PackedInt32Array()
var _glints: Array[Vector3] = []  ## x, y in image cells (cell units), z = twinkle phase.
var _glint_cols: PackedColorArray = PackedColorArray()  ## One colour per glint (the material's own).
var _tints: PackedColorArray = PackedColorArray()  ## Per material code: its scanner colour (ore, gems, gas).
## The whole segment's CRT colors, built a row at a time as rows come into view and patched where
## cells are cut, so a refresh is one native blit instead of thousands of per-cell calls.
var _full: Image = null
var _built: PackedByteArray = PackedByteArray()  ## Per grid row: 1 once its colors are in _full.
var _seen: PackedByteArray = PackedByteArray()  ## The grid as _full shows it.
var _last: PackedInt32Array = PackedInt32Array()  ## DrillSim.chunk_changes as last seen.
var _row_glints: Array[PackedInt32Array] = []  ## Per grid row: columns that were ore or gem.
var _last_steer: float = 1000.0  ## The last angle sent in this drag (a new press always sends).
var _pend_angle: float = 0.0  ## A steer order waiting for the next sim step, shown at once.
var _pend_tick: int = -1  ## The sim tick it was queued on; -1 for none.
var _dragging: bool = false
var _hover: Vector2 = Vector2(-1000.0, -1000.0)
var _range_m: float = 10.0  ## The scanner's range at the last refresh (meters from the drill head).

# Cell kinds.
const K_VOID: int = 0
const K_ROCK: int = 1
const K_HARD: int = 2
const K_ORE: int = 3
const K_GEM: int = 4
const K_WATER: int = 5
const K_GAS: int = 6
const K_FAULT: int = 7
const K_LOOT: int = 8  ## Crates and tape cases in a buried structure.


static func build(parent: Control, p_sim: Sim) -> ScannerPanel:
	var p := ScannerPanel.new()
	p.position = Vector2(1520, 90)
	p.size = SIZE
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_serial = -1
	_since = 99.0
	_img = null
	_tex = null
	_last_steer = 1000.0
	_pend_tick = -1
	queue_redraw()


## True while the screen shows rock (the drill phase with a segment under way).
func is_live() -> bool:
	return sim != null and sim.drill.active and sim.run.phase == "drill"


func _process(delta: float) -> void:
	_t += delta
	_since += delta
	if is_live() and (_since >= UPDATE_S or _serial != sim.drill.grid_serial):
		_since = 0.0
		_refresh_image()
	if _pacer.due():
		queue_redraw()


# Image ----------------------------------------------------------------------------------------

func _classify() -> void:
	var d: DrillSim = sim.drill
	_kind = PackedInt32Array()
	_kind.resize(DrillSim.MAX_CODES)
	_tints = PackedColorArray()
	_tints.resize(DrillSim.MAX_CODES)
	for code: int in range(DrillSim.MAX_CODES):
		var m: Dictionary = d.material(code)
		if m.is_empty():
			_kind[code] = K_ROCK
		elif code == 0 or str(m.get("id", "")) == "air" or d.interior_of[code] == 1:
			_kind[code] = K_VOID  # A structure's old air reads as a void too.
		elif d.loot_of[code] == 1:
			_kind[code] = K_LOOT
		elif d.unstable_of[code] == 1:
			_kind[code] = K_FAULT
		elif d.water_of[code] == 1:
			_kind[code] = K_WATER
		elif d.gas_of[code] == 1:
			_kind[code] = K_GAS
		elif d.yield_res_of[code] >= 0:
			_kind[code] = K_GEM if RunState.RESOURCES[d.yield_res_of[code]] == "gems" else K_ORE
		elif d.hardness_of[code] >= 3.0:
			_kind[code] = K_HARD
		else:
			_kind[code] = K_ROCK
		_tints[code] = scan_tint(Color.html(str(m.get("color", "#80c090"))), _kind[code]) if not m.is_empty() else Color.WHITE


func _refresh_image() -> void:
	var d: DrillSim = sim.drill
	if _serial != d.grid_serial or _img == null:
		_serial = d.grid_serial
		_classify()
		_rows_shown = maxi(1, roundi(LOOK_AHEAD_M / d.cell_m))
		_img = Image.create(d.cols, _rows_shown + 1, false, Image.FORMAT_RGBA8)
		_tex = ImageTexture.create_from_image(_img)
		_full = Image.create(d.cols, d.rows, false, Image.FORMAT_RGBA8)
		_built = PackedByteArray()
		_built.resize(d.rows)
		_seen = d.grid.duplicate()
		_last = d.chunk_changes.duplicate()
		_row_glints.clear()
		_row_glints.resize(d.rows)
	var ch: PackedInt32Array = d.chunk_changes
	for i: int in range(ch.size()):
		if ch[i] != _last[i]:
			_last[i] = ch[i]
			_apply_cuts(d, i)
	var crown: float = d.ship_pos.y + d.ship_size.y
	var top: int = int(floor(crown / d.cell_m))
	_frac = clampf((crown - float(top) * d.cell_m) / d.cell_m, 0.0, 1.0)
	var n: int = _rows_shown + 1
	var r0: int = maxi(top, 0)
	var r1: int = mini(top + n, d.rows)
	for ar: int in range(r0, r1):
		if _built[ar] == 0:
			_build_row(d, ar)
	if top < 0 or top + n > d.rows:
		_img.fill(Color(0.0, 0.03, 0.02))
	if r1 > r0:
		_img.blit_rect(_full, Rect2i(0, r0, d.cols, r1 - r0), Vector2i(0, r0 - top))
	_range_m = d.scanner_range_m(sim)
	var head: Vector2 = DrillMiner.head(d)
	_mask_range(d, top, head)
	_glints.clear()
	_glint_cols.clear()
	for ar: int in range(r0, r1):
		for c: int in _row_glints[ar]:
			var code: int = d.grid[ar * d.cols + c]
			var k: int = _kind[code]
			if (k == K_ORE or k == K_GEM) and _glints.size() < MAX_GLINTS and ScannerExtras.cell_in_range(c, ar, d.cell_m, head, _range_m):
				_glints.append(Vector3(float(c), float(ar - top), float((c * 7 + ar * 13) % 17) / 17.0 * TAU))
				_glint_cols.append(_tints[code].lerp(Color(1, 1, 1), 0.55))
	_tex.update(_img)


## Blank every image cell beyond the scanner's range (two fills per row: left and right of the circle).
func _mask_range(d: DrillSim, top: int, head: Vector2) -> void:
	for j: int in range(_rows_shown + 1):
		var span: Vector2i = ScannerExtras.row_span(top + j, d.cell_m, d.cols, head, _range_m)
		if span.y <= span.x:
			_img.fill_rect(Rect2i(0, j, d.cols, 1), OUT_OF_RANGE)
			continue
		if span.x > 0:
			_img.fill_rect(Rect2i(0, j, span.x, 1), OUT_OF_RANGE)
		if span.y < d.cols:
			_img.fill_rect(Rect2i(span.y, j, d.cols - span.y, 1), OUT_OF_RANGE)


## True when a segment point (meters) is within the scanner's range of the drill head.
func in_range(p_m: Vector2) -> bool:
	return sim != null and DrillMiner.head(sim.drill).distance_to(p_m) <= sim.drill.scanner_range_m(sim)


## Paint one grid row's colors into _full and note its ore and gem columns.
func _build_row(d: DrillSim, ar: int) -> void:
	var g := PackedInt32Array()
	for c: int in range(d.cols):
		var code: int = d.grid[ar * d.cols + c]
		_seen[ar * d.cols + c] = code
		var k: int = _kind[code]
		_full.set_pixel(c, ar, cell_color(k, d.hardness_of[code], c, ar, _tints[code]))
		if k == K_ORE or k == K_GEM:
			g.append(c)
	_row_glints[ar] = g
	_built[ar] = 1


## A chunk's change counter moved: repaint its cut cells in rows already built.
func _apply_cuts(d: DrillSim, ci: int) -> void:
	var cx: int = ci % d.chunk_cols
	var cy: int = ci / d.chunk_cols
	var n: int = DrillSim.CHUNK_CELLS
	for r: int in range(cy * n, mini((cy + 1) * n, d.rows)):
		for c: int in range(cx * n, mini((cx + 1) * n, d.cols)):
			var k: int = r * d.cols + c
			var code: int = d.grid[k]
			if code == _seen[k]:
				continue
			_seen[k] = code
			if _built[r] == 1:
				_full.set_pixel(c, r, cell_color(_kind[code], d.hardness_of[code], c, r, _tints[code]))


## The CRT color of one cell. Pure: the cell kind, the material's hardness and the absolute cell.
static func cell_color(k: int, hardness: float, c: int, r: int, tint: Color = Color(0.78, 1.0, 0.62)) -> Color:
	var n: float = float(((c * 73856093) ^ (r * 19349663)) & 255) / 255.0
	match k:
		K_VOID:
			return Color(0.0, 0.035, 0.02)
		K_FAULT:
			return ScannerExtras.fault_color(c, r)
		K_LOOT:
			return Color(1.0, 0.74 + 0.08 * n, 0.2)
		K_WATER:
			return Color(0.05, 0.16 + 0.05 * n, 0.50 + 0.1 * n)
		K_ORE:
			return tint
		K_GEM:
			return tint
		K_GAS:
			return Color(tint.r, tint.g, tint.b).lerp(Color(1, 1, 0.5), 0.15 * n)
		K_HARD:
			if (c + r) % 3 == 0:
				return Color(0.66, 1.0, 0.72)
			return Color(0.10, 0.46 + 0.1 * n, 0.20)
	var lum: float = 0.20 + 0.12 * hardness + 0.05 * n
	return Color(0.03 + 0.05 * lum, lum, 0.08 + 0.1 * lum)


## The scanner colour of an ore, gem or gas cell from the material's colour hint: kept in its hue,
## lifted so even coal reads on the dark screen. Rock and water keep their own looks.
static func scan_tint(col: Color, k: int) -> Color:
	if k != K_ORE and k != K_GEM and k != K_GAS:
		return Color.WHITE
	var lum: float = col.r * 0.3 + col.g * 0.59 + col.b * 0.11
	var lift: float = clampf((0.62 - lum) * 1.1, 0.0, 0.6)
	var out: Color = col.lerp(Color(1, 1, 1), lift)
	return Color(out.r, out.g, out.b, 1.0)


# Steering -------------------------------------------------------------------------------------

func _crown_x_px() -> float:
	var d: DrillSim = sim.drill
	var width_m: float = float(d.cols) * d.cell_m
	return SCREEN.position.x + (d.ship_pos.x + d.ship_size.x * 0.5) / width_m * SCREEN.size.x


## The steer angle (degrees from straight down) toward a panel-space point.
func angle_toward(p: Vector2) -> float:
	var dx: float = p.x - _crown_x_px()
	var dy: float = p.y - SCREEN.position.y
	if dy <= 8.0:
		return 90.0 * signf(dx)  # Level with the crown or above it: hold depth.
	return rad_to_deg(atan2(dx, dy))


## Fit a new bit (the B key and the button): one command, refused by the sim with a reason when
## there are no bits or one is being fitted.
func change_bit() -> void:
	if is_live():
		sim.push({"type": "change_bit"})


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not keys_enabled or not is_live():
		return
	if k.physical_keycode == KEY_B:
		change_bit()
		get_viewport().set_input_as_handled()


## The new-bit button shows while the bit is worn past half (or broken), and not while one is fitted.
func bit_offer() -> bool:
	return is_live() and sim.drill.bit_change_left_s <= 0.0 and (sim.drill.bit_broken or sim.drill.bit_wear > BIT_WEAR_OFFER)


func _gui_input(event: InputEvent) -> void:
	if not is_live():
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and bit_offer() and BIT_BUTTON.has_point(mb.position):
		change_bit()
		accept_event()
		return
	var mm0: InputEventMouseMotion = event as InputEventMouseMotion
	if mm0 != null:
		_hover = mm0.position
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and blast != null and blast.armed and SCREEN.has_point(mb.position):
		if not in_range(point_m(mb.position)):
			blast.say("OUT OF RANGE (%d M)" % roundi(sim.drill.scanner_range_m(sim)))  # Beyond the scanner: it cannot aim there.
		else:
			blast.aim(point_m(mb.position))
		accept_event()
		return
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and miner != null and miner.armed and SCREEN.has_point(mb.position):
		if not in_range(point_m(mb.position)):
			miner.say(MinerCard.reason_text("range", sim.drill.scanner_range_m(sim)))
		else:
			miner.aim(point_m(mb.position))
		accept_event()
		return
	if not steer_by_mouse:
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed and SCREEN.has_point(mb.position)
		if _dragging:
			_last_steer = 1000.0  # A new press always sends, even to the angle the last one used.
			_steer_to(mb.position)
			accept_event()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _dragging and SCREEN.has_point(mm.position):
		_steer_to(mm.position)
		accept_event()


func _steer_to(p: Vector2) -> void:
	var a: float = snappedf(angle_toward(p), STEER_STEP_DEG)
	if absf(a - _last_steer) < 0.5:
		return
	_last_steer = a
	queue_steer(a)


## The segment point (meters) under a panel point on the screen, for a blast click.
func point_m(p: Vector2) -> Vector2:
	var d: DrillSim = sim.drill
	return ScannerExtras.screen_to_m(p, SCREEN, float(d.cols) * d.cell_m, d.ship_pos.y + d.ship_size.y, look_m())


## The depth the screen shows, in meters.
func look_m() -> float:
	if sim == null or _rows_shown <= 0:
		return LOOK_AHEAD_M
	return float(_rows_shown) * sim.drill.cell_m


## Queue a steer order (the click and main's A and D keys use this) and remember it, so TGT and the
## dashed line show the new course even while the world is paused and the sim has not stepped.
func queue_steer(angle: float) -> void:
	var limit: float = sim.drill.max_heading_deg(sim)
	_pend_angle = clampf(angle, -limit, limit)
	_pend_tick = sim.tick
	sim.push({"type": "steer", "angle": angle})


## The course the drill is steering to: the queued order until the sim steps past it.
func target_heading() -> float:
	if _pend_tick == sim.tick:
		return _pend_angle
	return sim.drill.target_heading_deg


# Drawing --------------------------------------------------------------------------------------

func _draw() -> void:
	UiTheme.draw_panel(self, Rect2(Vector2.ZERO, size), "SEISMIC SCANNER")
	var bezel: Rect2 = SCREEN.grow(6.0)
	draw_rect(bezel, Color(0.03, 0.035, 0.04), true)
	draw_rect(bezel, UiTheme.BRASS_DARK, false, 2.0)
	draw_rect(SCREEN, Color(0.0, 0.04, 0.025), true)
	if sim == null:
		return
	if not is_live() or _tex == null:
		ScannerDraw.draw_no_signal(self)
	else:
		ScannerDraw.draw_rock(self)
	if sim.run.scanner_blind:
		ScannerDraw.draw_snow(self)
	ScannerDraw.draw_glass(self)
	ScannerDraw.draw_readout(self)
