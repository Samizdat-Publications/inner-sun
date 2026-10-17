class_name ScannerPanel
extends Control
## The seismic scanner: a green CRT showing the rock ahead of the drill (30 m below the crown, the
## whole 32 m width of the segment). Materials are shades: rock by hardness, hard rock as bright
## hatching, ore and gems as twinkling glints, water pockets dark blue, voids black. The ship's
## heading is a line from the crown, the steered target heading dashed; the next node's depth is a
## line across the screen. A sweep scans down the screen. Outside the drill phase it reads NO SIGNAL.
## Click or drag on the screen to steer toward that point (pushes {"type": "steer", "angle": deg}, over
## the full range up to hold depth at 90 degrees); set `steer_by_mouse = false` if main.gd steers with the
## keys only. With the blast armed (`blast` is the BlastCard) a click fires at that point instead.
## Fault rock is pale brown hatching; the extras (heading ray, HOLD DEPTH, AT THE WALL, the blast ring)
## live in ScannerExtras.
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

var sim: Sim = null
var steer_by_mouse: bool = true
var keys_enabled: bool = true  ## B fits a new bit; main turns this off while an overlay is open.
var blast: BlastCard = null  ## Set by RunScreen: a click fires a blast while it is armed.

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
	_glints.clear()
	_glint_cols.clear()
	for ar: int in range(r0, r1):
		for c: int in _row_glints[ar]:
			var code: int = d.grid[ar * d.cols + c]
			var k: int = _kind[code]
			if (k == K_ORE or k == K_GEM) and _glints.size() < MAX_GLINTS:
				_glints.append(Vector3(float(c), float(ar - top), float((c * 7 + ar * 13) % 17) / 17.0 * TAU))
				_glint_cols.append(_tints[code].lerp(Color(1, 1, 1), 0.55))
	_tex.update(_img)


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
		blast.aim(point_m(mb.position))
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
	var limit: float = sim.db.tune("drill.max_heading_deg")
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
		_draw_no_signal()
	else:
		_draw_rock()
	_draw_glass()
	_draw_readout()


func _draw_no_signal() -> void:
	var step: int = int(_t * 14.0)
	for i: int in range(46):
		var h: int = ((step * 2654435761 + i * 40503) & 0xffff)
		var y: float = SCREEN.position.y + float(h % int(SCREEN.size.y))
		var x: float = SCREEN.position.x + float((h >> 3) % 200)
		var w: float = 20.0 + float((h >> 5) % 100)
		draw_line(Vector2(x, y), Vector2(minf(x + w, SCREEN.end.x - 1.0), y), Color(UiTheme.CRT, 0.05 + 0.07 * float(h % 3)), 1.0)
	var blink: float = 0.55 + 0.45 * UiTheme.pulse(_t, 0.7)
	UiTheme.glow_text(self, Vector2(SCREEN.position.x, SCREEN.get_center().y + 10.0), "NO SIGNAL", 36, Color(UiTheme.CRT, blink), null, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.size.x)


func _draw_rock() -> void:
	var d: DrillSim = sim.drill
	draw_texture_rect_region(_tex, SCREEN, Rect2(0.0, _frac, float(d.cols), float(_rows_shown)), Color(1, 1, 1, 1))
	var px_x: float = SCREEN.size.x / (float(d.cols))
	var px_y: float = SCREEN.size.y / float(_rows_shown)
	# Glints.
	for gi: int in range(_glints.size()):
		var g: Vector3 = _glints[gi]
		var gp := Vector2(SCREEN.position.x + (g.x + 0.5) * px_x, SCREEN.position.y + (g.y - _frac + 0.5) * px_y)
		if not SCREEN.has_point(gp):
			continue
		var tw: float = 0.5 + 0.5 * sin(_t * 3.2 + g.z)
		var s: float = 2.0 + 5.0 * tw
		var base_c: Color = _glint_cols[gi] if gi < _glint_cols.size() else Color(0.85, 1.0, 0.9)
		var gc: Color = Color(base_c.r, base_c.g, base_c.b, 0.35 + 0.55 * tw)
		draw_line(gp - Vector2(s, 0), gp + Vector2(s, 0), gc, 1.0)
		draw_line(gp - Vector2(0, s), gp + Vector2(0, s), gc, 1.0)
	# Depth ticks every 5 m below the crown.
	var m_px: float = SCREEN.size.y / LOOK_AHEAD_M
	for m: int in range(5, int(LOOK_AHEAD_M) + 1, 5):
		var y: float = SCREEN.position.y + float(m) * m_px
		draw_line(Vector2(SCREEN.position.x, y), Vector2(SCREEN.position.x + 8.0, y), Color(UiTheme.CRT, 0.7), 1.0)
		UiTheme.text(self, Vector2(SCREEN.position.x + 11.0, y + 5.0), "%d" % m, 14, Color(UiTheme.CRT, 0.9))
	# The ship's footprint and heading.
	var cx: float = _crown_x_px()
	var half: float = d.ship_size.x * 0.5 / (float(d.cols) * d.cell_m) * SCREEN.size.x
	draw_line(Vector2(cx - half, SCREEN.position.y + 2.0), Vector2(cx + half, SCREEN.position.y + 2.0), UiTheme.CRT, 3.0)
	draw_line(Vector2(cx - half, SCREEN.position.y), Vector2(cx - half, SCREEN.position.y + 10.0), UiTheme.CRT, 2.0)
	draw_line(Vector2(cx + half, SCREEN.position.y), Vector2(cx + half, SCREEN.position.y + 10.0), UiTheme.CRT, 2.0)
	var tgt_deg: float = target_heading()
	var ppm_xy := Vector2(SCREEN.size.x / (float(d.cols) * d.cell_m), m_px)
	var origin := Vector2(cx, SCREEN.position.y + 4.0)
	if absf(tgt_deg - d.heading_deg) > 0.5:
		draw_dashed_line(origin, ScannerExtras.heading_end(origin, tgt_deg, ppm_xy, SCREEN), Color(UiTheme.AMBER, 0.95), 2.0, 6.0)
	draw_line(origin, ScannerExtras.heading_end(origin, d.heading_deg, ppm_xy, SCREEN), Color(0.9, 1.0, 0.9), 2.5)
	if blast != null and blast.armed:
		ScannerExtras.draw_blast(self, sim, SCREEN, look_m(), _hover, _t)
	ScannerExtras.draw_notes(self, sim, SCREEN, _t, tgt_deg, ScannerExtras.blast_word(sim, blast != null and blast.armed))
	# The next node: a line across the screen with a diamond where it sits.
	var crown: float = d.ship_pos.y + d.ship_size.y
	var remain: float = d.target_y - crown
	if remain >= 0.0 and remain <= LOOK_AHEAD_M:
		var ny: float = SCREEN.position.y + remain * m_px
		draw_dashed_line(Vector2(SCREEN.position.x, ny), Vector2(SCREEN.end.x, ny), UiTheme.AMBER, 2.0, 8.0)
		var tx: float = SCREEN.position.x + d.target_x / (float(d.cols) * d.cell_m) * SCREEN.size.x
		draw_colored_polygon(PackedVector2Array([Vector2(tx, ny - 9), Vector2(tx + 9, ny), Vector2(tx, ny + 9), Vector2(tx - 9, ny)]), UiTheme.AMBER)
		UiTheme.text(self, Vector2(SCREEN.end.x - 86.0, ny - 8.0), "NODE", 15, UiTheme.AMBER, null, HORIZONTAL_ALIGNMENT_RIGHT, 80.0)
	ScannerExtras.draw_structure(self, sim, SCREEN, look_m(), _t)
	_draw_legend()
	# The sweep.
	var sy: float = SCREEN.position.y + fposmod(_t * SWEEP_HZ, 1.0) * SCREEN.size.y
	for i: int in range(14):
		var y2: float = sy - float(i) * 3.0
		if y2 < SCREEN.position.y:
			break
		draw_rect(Rect2(SCREEN.position.x, y2, SCREEN.size.x, 3.0), Color(UiTheme.CRT, 0.16 * (1.0 - float(i) / 14.0)), true)
	draw_line(Vector2(SCREEN.position.x, sy), Vector2(SCREEN.end.x, sy), Color(0.8, 1.0, 0.85, 0.7), 1.5)


## A tiny legend along the foot of the screen: a swatch for every ore, gem, gas and water material
## the rock table has, in the colours the screen uses. Drawn from the material table, so new ores show.
func _draw_legend() -> void:
	var d: DrillSim = sim.drill
	var groups: Array = [["ORE", K_ORE], ["GEM", K_GEM], ["GAS", K_GAS], ["WATER", K_WATER], ["FAULT", K_FAULT], ["LOOT", K_LOOT]]
	var x: float = SCREEN.position.x + 6.0
	var y: float = SCREEN.end.y - 17.0
	draw_rect(Rect2(SCREEN.position.x, y, SCREEN.size.x, 17.0), Color(0.0, 0.03, 0.02, 0.82), true)
	for g: Array in groups:
		var kind: int = int(g[1])
		var swatches: Array[Color] = []
		for code: int in range(1, d.materials.size()):
			if _kind[code] == kind:
				var sw: Color = _swatch(kind, code)
				if not swatches.has(sw):  # Timber and rubble are both fault rock on the glass: one swatch.
					swatches.append(sw)
		if swatches.is_empty():
			continue
		UiTheme.text(self, Vector2(x, y + 13.0), str(g[0]), 12, Color(UiTheme.CRT, 0.9))
		x += UiTheme.text_width(str(g[0]), 12) + 4.0
		for col: Color in swatches:
			draw_rect(Rect2(x, y + 4.0, 8.0, 9.0), col, true)
			draw_rect(Rect2(x, y + 4.0, 8.0, 9.0), Color(0, 0, 0, 0.6), false, 1.0)
			x += 10.0
		x += 8.0


## The legend colour of a material of this kind.
func _swatch(kind: int, code: int) -> Color:
	if kind == K_WATER:
		return cell_color(K_WATER, 0.6, 3, 4)
	if kind == K_FAULT:
		return ScannerExtras.FAULT_HATCH
	if kind == K_LOOT:
		return cell_color(K_LOOT, 0.4, 3, 4)
	return _tints[code]


## Scanlines, vignette and a glass reflection over the screen, clipped to it by construction.
func _draw_glass() -> void:
	var y: float = SCREEN.position.y
	while y < SCREEN.end.y:
		draw_line(Vector2(SCREEN.position.x, y), Vector2(SCREEN.end.x, y), Color(0, 0, 0, 0.20), 1.0)
		y += 3.0
	for i: int in range(7):
		var a: float = 0.14 * (1.0 - float(i) / 7.0)
		draw_rect(SCREEN.grow(-float(i) * 2.0), Color(0, 0, 0, a), false, 2.0)
	draw_rect(SCREEN, Color(UiTheme.CRT, 0.5), false, 1.0)


func _draw_readout() -> void:
	var d: DrillSim = sim.drill
	var y: float = SCREEN.end.y + 32.0
	if not is_live():
		UiTheme.bold_text(self, Vector2(22, y), "STANDBY", 20, UiTheme.TEXT)
		UiTheme.text(self, Vector2(22, y + 28.0), "DRILL IDLE", 18, UiTheme.TEXT_DIM)
		return
	var crown: float = d.ship_pos.y + d.ship_size.y
	var remain: float = maxf(0.0, d.target_y - crown)
	UiTheme.bold_text(self, Vector2(22, y), "HDG %+d  TGT %+d" % [roundi(d.heading_deg), roundi(target_heading())], 20, UiTheme.CRT)
	UiTheme.bold_text(self, Vector2(size.x - 22.0 - 190.0, y), "NODE IN %d M" % roundi(remain), 20, UiTheme.AMBER, null, HORIZONTAL_ALIGNMENT_RIGHT, 190.0)
	var wear: int = roundi(d.bit_wear * 100.0)
	var bit_col: Color = UiTheme.ALARM if d.bit_broken else (UiTheme.AMBER if wear >= 70 else UiTheme.CRT)
	UiTheme.text(self, Vector2(22, y + 28.0), "SPEED %.1f M/S" % d.speed_m_s, 18, UiTheme.TEXT)
	var bit_text: String = "BIT BROKEN" if d.bit_broken else "BIT WEAR %d%%" % wear
	if d.bit_change_left_s > 0.0:
		bit_text = "FITTING BIT %.0f S" % d.bit_change_left_s
		bit_col = UiTheme.AMBER
	if bit_offer():
		_draw_bit_button(sim.run.get_res("bits"))
		return
	UiTheme.text(self, Vector2(size.x - 22.0 - 210.0, y + 28.0), bit_text, 18, bit_col, null, HORIZONTAL_ALIGNMENT_RIGHT, 210.0)


func _draw_bit_button(bits: int) -> void:
	var r: Rect2 = BIT_BUTTON
	var can: bool = bits > 0
	var p: float = UiTheme.pulse(_t, 1.6)
	draw_rect(r, Color(0.22, 0.15, 0.05).lerp(Color(0.32, 0.21, 0.06), p) if can else UiTheme.STEEL_DEEP, true)
	draw_rect(r, UiTheme.AMBER if can else UiTheme.ALARM, false, 2.0)
	var label: String = "[B] NEW BIT (%d left)" % bits if can else "NO BITS LEFT"
	UiTheme.bold_text(self, Vector2(r.position.x, r.position.y + 21.0), label, 17, UiTheme.BRASS_LIGHT if can else UiTheme.ALARM, null, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
