class_name RockView
extends Node2D
## Draws a drilling segment's rock grid (DrillSim.grid) in segment space: this node's origin is the
## segment's top-left corner and it never moves; the camera and the ship move over it.
## The grid is painted at 8 px per cell into one mosaic (albedo, normal and material id images) that a
## single canvas item draws, scaled up to the view's pixels per meter:
##  - colors come from the material's data color hint, with value noise, strata banding, a depth tint
##    and darker rims where solid meets air; boundaries between materials and between rock and air are
##    ragged (the lookup is warped by noise), so the rock does not read as a grid of squares;
##  - the normal map comes from a smooth height field (bilinear solid/air) plus noise bumps, so shaft
##    walls and pockets catch the hull floodlights;
##  - gem and ore cells get a second, additive and unshaded glint layer (one sprite per 16 x 16 chunk)
##    that blooms;
##  - air cells are transparent over a dim back wall, so the shaft is not pure black.
## Repainting is incremental and budgeted. The view keeps its own copy of the grid; when a chunk's
## change counter moves it diffs that chunk against the copy and marks the changed cells plus one cell
## around them dirty (a pixel reads only cells within one cell of its own: the bilinear height, the
## warped material lookup and the air fallback). Dirty cells are painted in small strips (one cell
## row, at most UNIT_CELLS wide), nearest the ship first, and a strip starts only if its estimated
## cost still fits this frame's budget; the rest waits for the next frame. The mosaic textures are
## uploaded at most once every UPLOAD_EVERY frames. A new segment's first build spreads over a few
## dozen frames. Rock is on light mask 2: only the hull floodlights and the crown glow
## (range_item_cull_mask 2) reach it, never the ship's interior lamps.
## Reads sim state only; paints with its own integer hash, so the picture is the same every run.

const CELLS: int = 16
const CELL_PX: int = 8
const CHUNK_PX: int = CELLS * CELL_PX
const TILE: int = 256
const LIGHT_MASK: int = 2
## Painting budget per frame (microseconds). A strip is started only if its estimate still fits.
const BUDGET_USEC: int = 3500
## Widest paint strip in cells (one cell row tall): about 1.5 ms of painting at most.
const UNIT_CELLS: int = 16
## Frames between mosaic texture uploads (each upload sends the whole mosaic, about 6 MB).
const UPLOAD_EVERY: int = 3
## Starting estimate of the paint cost per pixel (microseconds); refined as strips are painted.
const START_US_PER_PX: float = 1.6
const WALL_CHUNK_PX: int = 512  ## Back wall and apron sprites, so each meets only nearby lights.
## Occluders are built only if rock shadows are on. They are off: the shadow of a solid polygon also
## covers its own rock face, which would black out the very walls the floodlights should reveal.
const ROCK_SHADOWS: bool = false
const AMBIENT: Color = Color(0.30, 0.30, 0.34)
## Albedo gain for rock sprites (HDR modulate): the ambient is so dark that plain rock colors read black.
const ROCK_GAIN: float = 2.1

## The whole rock as ONE canvas item (a mosaic of the painted chunks). Measured in captures: Godot lit
## a rock item only with the lights that sit inside its rectangle, so separate chunk sprites came out
## as chunk-shaped patches of light and dark. One item spanning the segment holds every light.
class RockNode extends Node2D:
	var tex: CanvasTexture
	var size_px: Vector2 = Vector2(640.0, 640.0)

	func _draw() -> void:
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size_px), false)


static var _tile: PackedFloat32Array = PackedFloat32Array()
static var _flat_normal: PackedByteArray = PackedByteArray()
## Per pixel column (or row) inside a strip: left cell index (+1 for the pad), smoothstep weight and
## its derivative. Strips start on cell boundaries, so one table serves every strip.
static var _ci: PackedInt32Array = PackedInt32Array()
static var _ft: PackedFloat32Array = PackedFloat32Array()
static var _dft: PackedFloat32Array = PackedFloat32Array()

var drill: DrillSim
var ppm: float = 80.0
var serial: int = -1

var _scale: float = 5.0
var _slot: PackedByteArray = PackedByteArray()  # painted tile slot per material code
var _kind: PackedByteArray = PackedByteArray()  # 0 rock, 1 ore, 2 gem, 3 water
var _seen: PackedByteArray = PackedByteArray()  # the view's copy of the grid
var _last: PackedInt32Array = PackedInt32Array()
var _mcols: int = 0  # mosaic size in cells (whole chunks, so it can be wider and taller than the grid)
var _mrows: int = 0
var _cdirty: PackedByteArray = PackedByteArray()  # per mosaic cell: 1 = repaint
var _row_dirty: PackedInt32Array = PackedInt32Array()  # dirty cells per mosaic row
var _dirty_total: int = 0
var _gdirty: PackedByteArray = PackedByteArray()  # per chunk: glint (and occluder) repaint
var _gdirty_total: int = 0
var _us_per_px: float = START_US_PER_PX
var _since_upload: int = 0
var _pc: PackedByteArray = PackedByteArray()  # strip scratch: padded codes, solidity, value jitter
var _ps: PackedFloat32Array = PackedFloat32Array()
var _pv: PackedFloat32Array = PackedFloat32Array()
var _rock: RockNode
var _img_a: Image
var _img_n: Image
var _tex_a: ImageTexture
var _tex_n: ImageTexture
var _img_id: Image
var _tex_id: ImageTexture
var _mosaic_dirty: bool = false
var _glints: Array[Sprite2D] = []
var _occluders: Array[LightOccluder2D] = []
var _gtex: Array[ImageTexture] = []
var _time: float = 0.0
var strips_painted: int = 0  ## Paint strips done so far (tests and diagnostics).


func setup(p_drill: DrillSim, p_ppm: float) -> void:
	drill = p_drill
	ppm = p_ppm
	serial = drill.grid_serial
	_scale = ppm * drill.cell_m / float(CELL_PX)
	if _tile.is_empty():
		_make_tile()
	_make_palette()
	_seen = drill.grid.duplicate()
	_last = drill.chunk_changes.duplicate()
	_build_backdrop()
	var n: int = drill.chunk_cols * drill.chunk_rows
	_mcols = drill.chunk_cols * CELLS
	_mrows = drill.chunk_rows * CELLS
	_cdirty.resize(_mcols * _mrows)
	_row_dirty.resize(_mrows)
	_gdirty.resize(n)
	_pc.resize((UNIT_CELLS + 2) * 3)
	_ps.resize((UNIT_CELLS + 2) * 3)
	_pv.resize((UNIT_CELLS + 2) * 3)
	var mw: int = _mcols * CELL_PX
	var mh: int = _mrows * CELL_PX
	_img_a = Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	_img_n = Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	_img_n.fill(Color8(128, 128, 255, 255))
	_tex_a = ImageTexture.create_from_image(_img_a)
	_tex_n = ImageTexture.create_from_image(_img_n)
	_img_id = Image.create(mw, mh, false, Image.FORMAT_R8)
	_tex_id = ImageTexture.create_from_image(_img_id)
	var ct := CanvasTexture.new()
	ct.diffuse_texture = _tex_a
	ct.normal_texture = _tex_n
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rock = RockNode.new()
	_rock.tex = ct
	_rock.size_px = Vector2(float(mw), float(mh)) * _scale
	_rock.light_mask = LIGHT_MASK
	_rock.material = RockTiles.material_for(_rock.size_px, _tex_id, ppm)
	_rock.z_index = -20
	_rock.self_modulate = Color(ROCK_GAIN, ROCK_GAIN, ROCK_GAIN, 1.0)
	add_child(_rock)
	for i: int in range(n):
		_glints.append(null)
		_gtex.append(null)
		_occluders.append(null)
		_gdirty[i] = 1
	_gdirty_total = n
	_mark_rect(0, 0, _mcols - 1, _mrows - 1)


## Paint work still waiting: dirty cells, glint chunks and a pending upload (captures wait for zero).
func pending() -> int:
	return _dirty_total + _gdirty_total + (1 if _mosaic_dirty else 0)


func _process(delta: float) -> void:
	_time += delta
	if drill == null:
		return
	var t0: int = Time.get_ticks_usec()
	var ch: PackedInt32Array = drill.chunk_changes
	for i: int in range(ch.size()):
		if ch[i] != _last[i]:
			_last[i] = ch[i]
			_note_change(i)
	_work(t0, BUDGET_USEC)
	_since_upload += 1
	if _mosaic_dirty and _since_upload >= UPLOAD_EVERY:
		_upload()
	for i: int in range(_glints.size()):
		var g: Sprite2D = _glints[i]
		if g != null:
			var tw: float = 0.78 + 0.22 * sin(_time * 3.1 + float(i) * 1.9) + 0.08 * sin(_time * 7.3 + float(i))
			g.self_modulate = Color(tw, tw, tw, 1.0)
	PerfRecorder.span(PerfRecorder.SPAN_ROCK, Time.get_ticks_usec() - t0)


## Paint everything still dirty now, ignoring the budget, and upload (tests and tools).
func paint_all_now() -> void:
	while _dirty_total > 0 or _gdirty_total > 0:
		_work(Time.get_ticks_usec(), 1 << 40)
	if _mosaic_dirty:
		_upload()


func _upload() -> void:
	var tu: int = Time.get_ticks_usec()
	_mosaic_dirty = false
	_since_upload = 0
	_tex_a.update(_img_a)
	_tex_n.update(_img_n)
	_tex_id.update(_img_id)
	PerfRecorder.span(PerfRecorder.SPAN_ROCK_UPLOAD, Time.get_ticks_usec() - tu)


## Paint strips (nearest the ship first), then glint chunks, while the next one's estimate fits the
## budget. The first strip of a frame always runs, so the work always moves.
func _work(t0: int, budget_usec: int) -> void:
	var first: bool = true
	while _dirty_total > 0:
		var r: int = _next_row()
		var c0: int = 0
		while _cdirty[r * _mcols + c0] == 0:
			c0 += 1
		var c1: int = c0 + 1
		while c1 < _mcols and c1 - c0 < UNIT_CELLS and _cdirty[r * _mcols + c1] != 0:
			c1 += 1
		var px: int = (c1 - c0) * CELL_PX * CELL_PX
		var now: int = Time.get_ticks_usec()
		if not first and now - t0 + roundi(float(px) * _us_per_px) > budget_usec:
			return
		first = false
		for c: int in range(c0, c1):
			_cdirty[r * _mcols + c] = 0
		_row_dirty[r] -= c1 - c0
		_dirty_total -= c1 - c0
		_paint_run(c0, c1, r)
		var took: int = Time.get_ticks_usec() - now
		_us_per_px = lerpf(_us_per_px, float(took) / float(px), 0.25)
	while _gdirty_total > 0:
		if not first and Time.get_ticks_usec() - t0 > budget_usec * 3 / 4:
			return
		first = false
		var idx: int = _gdirty.find(1)
		_gdirty[idx] = 0
		_gdirty_total -= 1
		var cx: int = idx % drill.chunk_cols
		var cy: int = idx / drill.chunk_cols
		_paint_glint(idx, cx, cy)
		if ROCK_SHADOWS:
			_build_occluder(idx, cx, cy)


## The dirty mosaic row nearest the ship's middle row.
func _next_row() -> int:
	var focus: int = clampi(floori((drill.ship_pos.y + drill.ship_size.y * 0.5) / drill.cell_m), 0, _mrows - 1)
	for d: int in range(_mrows):
		var a: int = focus + d
		if a < _mrows and _row_dirty[a] > 0:
			return a
		var b: int = focus - d - 1
		if b >= 0 and _row_dirty[b] > 0:
			return b
	return 0


## Diff one chunk against the view's grid copy and mark what the changed cells can affect.
func _note_change(ci: int) -> void:
	var ccols: int = drill.chunk_cols
	var cx: int = ci % ccols
	var cy: int = ci / ccols
	var cols: int = drill.cols
	var rows: int = drill.rows
	var grid: PackedByteArray = drill.grid
	for r: int in range(cy * CELLS, mini((cy + 1) * CELLS, rows)):
		for c: int in range(cx * CELLS, mini((cx + 1) * CELLS, cols)):
			var k: int = r * cols + c
			var now_code: int = grid[k]
			var was: int = _seen[k]
			if now_code == was:
				continue
			_seen[k] = now_code
			# The last column and row are repeated past the grid's edge (clamped lookups), so a change
			# there reaches to the mosaic's edge.
			var c_hi: int = _mcols - 1 if c == cols - 1 else c + 1
			var r_hi: int = _mrows - 1 if r == rows - 1 else r + 1
			_mark_rect(c - 1, r - 1, c_hi, r_hi)
			var kw: int = _kind[was]
			var kn: int = _kind[now_code]
			if ROCK_SHADOWS or kw == 1 or kw == 2 or kn == 1 or kn == 2:
				if _gdirty[ci] == 0:
					_gdirty[ci] = 1
					_gdirty_total += 1


## Mark mosaic cells [c0..c1] x [r0..r1] (inclusive, clamped) for repainting.
func _mark_rect(c0: int, r0: int, c1: int, r1: int) -> void:
	var ca: int = maxi(c0, 0)
	var cb: int = mini(c1, _mcols - 1)
	for r: int in range(maxi(r0, 0), mini(r1, _mrows - 1) + 1):
		var row: int = r * _mcols
		var added: int = 0
		for c: int in range(ca, cb + 1):
			if _cdirty[row + c] == 0:
				_cdirty[row + c] = 1
				added += 1
		_row_dirty[r] += added
		_dirty_total += added


# Painting ----------------------------------------------------------------------------------------

## A radial light texture built synchronously (a GradientTexture2D is sized later, and Godot culls a
## light against big items by the size it saw first, so large rock chunks lost the light). Full
## strength to `inner` (fraction of the radius), mid_a at mid_r, zero at the edge. `extent` is how much
## of the texture the falloff fills: Godot culls big items against the light's texture rectangle and
## drops them when it misses, so the rectangle is made larger than the visible pool (scale the light
## by 1 / extent). In measured captures a 1x rectangle left hard chunk-shaped edges.
static func light_texture(size: int, inner: float, mid_r: float, mid_a: float, extent: float = 0.4) -> ImageTexture:
	var bytes := PackedByteArray()
	bytes.resize(size * size * 4)
	var half: float = float(size) * 0.5
	for y: int in range(size):
		for x: int in range(size):
			var d: float = Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half).length() / (half * extent)
			var f: float = 0.0
			if d <= inner:
				f = 1.0
			elif d <= mid_r:
				f = lerpf(1.0, mid_a, (d - inner) / maxf(0.0001, mid_r - inner))
			elif d < 1.0:
				f = lerpf(mid_a, 0.0, (d - mid_r) / maxf(0.0001, 1.0 - mid_r))
			var v: int = roundi(f * 255.0)
			var o: int = (y * size + x) * 4
			bytes[o] = v
			bytes[o + 1] = v
			bytes[o + 2] = v
			bytes[o + 3] = v
	return ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes))


static func _hash(x: int, y: int, s: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + s * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


## A seamless 256 x 256 noise tile: value noise at 16, 4 and 1 pixel scales.
static func _make_tile() -> void:
	_tile.resize(TILE * TILE)
	var steps: Array[int] = [16, 4, 1]
	var amps: Array[float] = [0.5, 0.32, 0.18]
	for y: int in range(TILE):
		for x: int in range(TILE):
			var v: float = 0.0
			for o: int in range(3):
				var st: int = steps[o]
				var n: int = TILE / st
				var gx: int = x / st
				var gy: int = y / st
				var fx: float = float(x % st) / float(st)
				var fy: float = float(y % st) / float(st)
				fx = fx * fx * (3.0 - 2.0 * fx)
				fy = fy * fy * (3.0 - 2.0 * fy)
				var x1: int = (gx + 1) % n
				var y1: int = (gy + 1) % n
				var a: float = lerpf(_hash(gx, gy, o), _hash(x1, gy, o), fx)
				var b: float = lerpf(_hash(gx, y1, o), _hash(x1, y1, o), fx)
				v += lerpf(a, b, fy) * amps[o]
			_tile[y * TILE + x] = v
	_flat_normal.resize(CHUNK_PX * CHUNK_PX * 4)
	for i: int in range(CHUNK_PX * CHUNK_PX):
		_flat_normal[i * 4] = 128
		_flat_normal[i * 4 + 1] = 128
		_flat_normal[i * 4 + 2] = 255
		_flat_normal[i * 4 + 3] = 255
	var strip_px: int = UNIT_CELLS * CELL_PX
	_ci.resize(strip_px)
	_ft.resize(strip_px)
	_dft.resize(strip_px)
	for p: int in range(strip_px):
		var u: float = (float(p) + 0.5) / float(CELL_PX) - 0.5
		var i0: int = floori(u)
		var f: float = u - float(i0)
		_ci[p] = i0 + 1
		_ft[p] = f * f * (3.0 - 2.0 * f)
		_dft[p] = 6.0 * f * (1.0 - f)


func _make_palette() -> void:
	_slot.resize(256)
	_kind.resize(256)
	for code: int in range(256):
		var m: Dictionary = drill.material(code)
		_slot[code] = RockTiles.slot_of(str(m.get("id", "")))
		var kind: int = 0
		if code < drill.water_of.size() and drill.water_of[code] == 1:
			kind = 3
		elif code < drill.yield_res_of.size() and drill.yield_res_of[code] >= 0:
			kind = 2 if RunState.RESOURCES[drill.yield_res_of[code]] == "gems" else 1
		_kind[code] = kind


func _code_at(col: int, row: int) -> int:
	if row < 0:
		return 0
	var c: int = clampi(col, 0, drill.cols - 1)
	var r: int = mini(row, drill.rows - 1)
	return drill.grid[r * drill.cols + c]



## Paint mosaic cells [c0, c1) of row r (one strip, 8 px tall) and blit it into the mosaic images.
## Every pixel depends only on its global position and the cells within one cell of its own, so a
## strip comes out exactly as the same pixels of a whole-segment paint would.
func _paint_run(c0: int, c1: int, r: int) -> void:
	var w: int = c1 - c0
	var pw: int = w + 2
	var wpx: int = w * CELL_PX
	var pc: PackedByteArray = _pc
	var ps: PackedFloat32Array = _ps
	var pv: PackedFloat32Array = _pv
	for j: int in range(3):
		for i: int in range(pw):
			var code: int = _code_at(c0 - 1 + i, r - 1 + j)
			pc[j * pw + i] = code
			ps[j * pw + i] = 0.0 if code == 0 else 1.0
			pv[j * pw + i] = 0.88 + 0.24 * _hash(c0 - 1 + i, r - 1 + j, 9)
	var ci: PackedInt32Array = _ci
	var ft: PackedFloat32Array = _ft
	var dft: PackedFloat32Array = _dft
	var kinds: PackedByteArray = _kind
	var slots: PackedByteArray = _slot
	var n_px: int = wpx * CELL_PX
	var alb := PackedByteArray()
	alb.resize(n_px * 4)
	var nrm: PackedByteArray = _flat_normal.slice(0, n_px * 4)
	var idb := PackedByteArray()
	idb.resize(n_px)
	var tile: PackedFloat32Array = _tile
	var total_px: float = float(drill.rows * CELL_PX)
	var cells_n: int = pw * 3
	for y: int in range(CELL_PX):
		var pj: int = ci[y]
		var ty: float = ft[y]
		var dty: float = dft[y]
		var Y: int = r * CELL_PX + y
		var ydepth: float = clampf(float(Y) / total_px, 0.0, 1.0)
		var row_n: int = (Y & 255) << 8
		for x: int in range(wpx):
			var pi: int = ci[x]
			var k00: int = pj * pw + pi
			var s00: float = ps[k00]
			var s10: float = ps[k00 + 1]
			var s01: float = ps[k00 + pw]
			var s11: float = ps[k00 + pw + 1]
			var sum: float = s00 + s10 + s01 + s11
			if sum == 0.0:
				continue  # All air around: h = 0, so v <= 0.15 and the cover is zero.
			var tx: float = ft[x]
			var h: float = 1.0
			if sum != 4.0:
				var top: float = s00 + (s10 - s00) * tx
				var bot: float = s01 + (s11 - s01) * tx
				h = top + (bot - top) * ty
			var X: int = c0 * CELL_PX + x
			var na: float = tile[row_n | (X & 255)]
			var v: float = h + (na - 0.5) * 0.4  # Ragged cut edges: the shaft wall is torn, not smooth.
			var cover: float = clampf((v - 0.5) * 10.0 + 0.5, 0.0, 1.0)
			if cover <= 0.004:
				continue
			var nb: float = tile[(((Y + (X >> 2) * 5 + 17) & 255) << 8) | ((X + (Y >> 1) * 3 + 101) & 255)]
			# Material from a noise-warped lookup, so boundaries are ragged.
			var wi: int = clampi(floori((float(x) + (nb - 0.5) * 8.0) / float(CELL_PX)) + 1, 0, pw - 1)
			var wj: int = clampi(floori((float(y) + (na - 0.5) * 8.0) / float(CELL_PX)) + 1, 0, 2)
			var cell: int = wj * pw + wi
			var code: int = pc[cell]
			if code == 0:
				cell = pw + x / CELL_PX + 1
				code = pc[cell]
				if code == 0:
					if cell - 1 >= 0 and pc[cell - 1] != 0:
						cell -= 1
					elif cell + 1 < cells_n and pc[cell + 1] != 0:
						cell += 1
					elif cell - pw >= 0 and pc[cell - pw] != 0:
						cell -= pw
					elif cell + pw < cells_n and pc[cell + pw] != 0:
						cell += pw
					code = pc[cell]
			var kind: int = kinds[code]
			var tex: float = 0.8 + (na - 0.5) * 0.4 + (nb - 0.5) * 0.24
			var band: float = 0.07 * sin(float(Y) * 0.045 + nb * 2.6)
			var shade: float = tex * pv[cell] * (1.0 + band) * (1.0 - 0.28 * ydepth)
			var depth_in: float = clampf((v - 0.5) * 3.2, 0.0, 1.0)
			shade *= 0.32 + 0.68 * depth_in
			# A cut wall is rougher than solid rock: bit rings and gouges, and stronger bumps for the lights.
			var edge: float = 1.0 - depth_in
			shade *= 1.0 + edge * 0.2 * sin(float(Y) * 0.8 + nb * 6.0) + edge * 0.1 * (na - 0.5)
			var bump: float = 1.0 + 2.2 * edge
			if kind == 2:
				bump *= 1.3
			elif kind == 3:
				var sheen: float = smoothstep(0.78, 0.95, 0.5 + 0.5 * sin(float(Y) * 0.4 + na * 5.0))
				shade = shade * 0.8 + sheen * 0.25
				bump *= 0.25
			var p: int = y * wpx + x
			var o: int = p * 4
			var sh8: int = clampi(roundi(shade * 255.0), 0, 255)
			alb[o] = sh8
			alb[o + 1] = sh8
			alb[o + 2] = sh8
			idb[p] = slots[code] * 16
			alb[o + 3] = clampi(roundi(cover * 255.0), 0, 255)
			var dhdx: float = 0.0
			var dhdy: float = 0.0
			if sum != 4.0:
				dhdx = ((s10 - s00) * (1.0 - ty) + (s11 - s01) * ty) * dft[x] * 0.125
				dhdy = ((s01 - s00) * (1.0 - tx) + (s11 - s10) * tx) * dty * 0.125
			var gxn: float = tile[row_n | ((X + 2) & 255)] - tile[row_n | ((X - 2) & 255)]
			var gyn: float = tile[(((Y + 2) & 255) << 8) | (X & 255)] - tile[(((Y - 2) & 255) << 8) | (X & 255)]
			var nx: float = -(dhdx * 3.4 + gxn * 0.32 * bump)
			var ny: float = dhdy * 3.4 + gyn * 0.32 * bump
			var inv: float = 1.0 / sqrt(nx * nx + ny * ny + 1.0)
			nrm[o] = clampi(roundi((nx * inv * 0.5 + 0.5) * 255.0), 0, 255)
			nrm[o + 1] = clampi(roundi((ny * inv * 0.5 + 0.5) * 255.0), 0, 255)
			nrm[o + 2] = clampi(roundi((inv * 0.5 + 0.5) * 255.0), 0, 255)
	var at := Vector2i(c0 * CELL_PX, r * CELL_PX)
	var src := Rect2i(0, 0, wpx, CELL_PX)
	_img_a.blit_rect(Image.create_from_data(wpx, CELL_PX, false, Image.FORMAT_RGBA8, alb), src, at)
	_img_n.blit_rect(Image.create_from_data(wpx, CELL_PX, false, Image.FORMAT_RGBA8, nrm), src, at)
	_img_id.blit_rect(Image.create_from_data(wpx, CELL_PX, false, Image.FORMAT_R8, idb), src, at)
	_mosaic_dirty = true
	strips_painted += 1


## The additive glint layer: sparkles on gem and ore cells, unshaded, brightened so it blooms.
func _paint_glint(idx: int, cx: int, cy: int) -> void:
	var px := PackedByteArray()
	var any: bool = false
	var cols: int = drill.cols
	for lr: int in range(CELLS):
		var r: int = cy * CELLS + lr
		if r >= drill.rows:
			break
		for lc: int in range(CELLS):
			var c: int = cx * CELLS + lc
			if c >= cols:
				break
			var code: int = drill.grid[r * cols + c]
			var kind: int = _kind[code]
			if kind != 1 and kind != 2:
				continue
			if not any:
				px.resize(CHUNK_PX * CHUNK_PX * 4)
				any = true
			var gem: bool = kind == 2
			_ore_fill(px, code, lc, lr, gem)
			if gem:
				_gem_glow(px, c, r, lc, lr)
			else:
				# Ore reads as metal in rock: a few small cool glints, not lava.
				for k: int in range(2):
					var sx: int = lc * CELL_PX + 1 + floori(_hash(c, r, 20 + k) * 6.0)
					var sy: int = lr * CELL_PX + 1 + floori(_hash(c, r, 40 + k) * 6.0)
					var inten: float = 0.3 + 0.3 * _hash(c, r, 60 + k)
					_put(px, sx, sy, 0.82, 0.9, 1.0, inten)
	var g: Sprite2D = _glints[idx]
	if not any:
		if g != null:
			g.visible = false
		return
	var img: Image = Image.create_from_data(CHUNK_PX, CHUNK_PX, false, Image.FORMAT_RGBA8, px)
	if g == null:
		g = Sprite2D.new()
		g.centered = false
		g.scale = Vector2(_scale, _scale)
		g.position = Vector2(float(idx % drill.chunk_cols), float(idx / drill.chunk_cols)) * float(CHUNK_PX) * _scale
		g.z_index = -19
		g.light_mask = 0
		g.material = RockTiles.glint_material()
		# Unshaded items are not touched by the CanvasModulate, so this is the on-screen brightness.
		g.modulate = Color(1.15, 1.15, 1.15, 1.0)
		add_child(g)
		_glints[idx] = g
		_gtex[idx] = ImageTexture.create_from_image(img)
		g.texture = _gtex[idx]
	else:
		_gtex[idx].update(img)
	g.visible = true


## A soft wash of the material's own colour over an ore or gem cell (additive, unshaded), so veins and
## pockets read plainly from across the shaft and not only when a glint twinkles.
func _ore_fill(px: PackedByteArray, code: int, lc: int, lr: int, gem: bool) -> void:
	var col: Color = Color.html(str(drill.material(code).get("color", "#808080")))
	var k: float = 0.5 if gem else 0.62
	for yy: int in range(CELL_PX):
		for xx: int in range(CELL_PX):
			var edge: float = minf(minf(float(xx), float(CELL_PX - 1 - xx)), minf(float(yy), float(CELL_PX - 1 - yy)))
			_put(px, lc * CELL_PX + xx, lr * CELL_PX + yy, col.r, col.g, col.b, k * (0.55 + 0.15 * minf(edge, 3.0)))


## Gem cells glow from the painted emission tile (the same warped world position as the tile).
func _gem_glow(px: PackedByteArray, c: int, r: int, lc: int, lr: int) -> void:
	var em: Image = RockTiles.emission_image()
	var tile_mp: float = RockTiles.TILE_M * float(CELL_PX) / drill.cell_m  # mosaic px per tile
	for yy: int in range(CELL_PX):
		for xx: int in range(CELL_PX):
			var wx: float = (float(c * CELL_PX + xx)) / tile_mp
			var wy: float = (float(r * CELL_PX + yy)) / tile_mp
			var tx: int = clampi(floori((wx - floorf(wx)) * 128.0), 0, 127)
			var ty: int = clampi(floori((wy - floorf(wy)) * 128.0), 0, 127)
			var e: Color = em.get_pixel(tx, ty) if em != null else Color(0.3, 1.0, 0.8, 0.5)
			var k: float = e.a * 0.8
			_put(px, lc * CELL_PX + xx, lr * CELL_PX + yy, e.r, e.g, e.b, k)


static func _put(px: PackedByteArray, x: int, y: int, r: float, g: float, b: float, a: float) -> void:
	if x < 0 or y < 0 or x >= CHUNK_PX or y >= CHUNK_PX:
		return
	var o: int = (y * CHUNK_PX + x) * 4
	px[o] = mini(255, px[o] + roundi(r * a * 255.0))
	px[o + 1] = mini(255, px[o + 1] + roundi(g * a * 255.0))
	px[o + 2] = mini(255, px[o + 2] + roundi(b * a * 255.0))
	px[o + 3] = 255


## One occluder per chunk from merged horizontal runs of solid cells (only with ROCK_SHADOWS).
func _build_occluder(idx: int, cx: int, cy: int) -> void:
	var old: LightOccluder2D = _occluders[idx]
	if old != null:
		old.queue_free()
		_occluders[idx] = null
	var cell_px: float = drill.cell_m * ppm
	var polys: Array[PackedVector2Array] = []
	for lr: int in range(CELLS):
		var r: int = cy * CELLS + lr
		if r >= drill.rows:
			break
		var run_start: int = -1
		for lc: int in range(CELLS + 1):
			var c: int = cx * CELLS + lc
			var solid: bool = lc < CELLS and c < drill.cols and drill.grid[r * drill.cols + c] != 0
			if solid and run_start < 0:
				run_start = lc
			elif not solid and run_start >= 0:
				var x0: float = float(cx * CELLS + run_start) * cell_px
				var x1: float = float(cx * CELLS + lc) * cell_px
				var y0: float = float(r) * cell_px
				polys.append(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y0 + cell_px), Vector2(x0, y0 + cell_px)]))
				run_start = -1
	if polys.is_empty():
		return
	var holder := LightOccluder2D.new()
	holder.occluder_light_mask = 4
	# One occluder resource holds one polygon, so extra runs become children.
	for k: int in range(polys.size()):
		var poly := OccluderPolygon2D.new()
		poly.polygon = polys[k]
		poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
		if k == 0:
			holder.occluder = poly
		else:
			var extra := LightOccluder2D.new()
			extra.occluder = poly
			extra.occluder_light_mask = 4
			holder.add_child(extra)
	add_child(holder)
	_occluders[idx] = holder


# Backdrop ----------------------------------------------------------------------------------------

## The dim back wall behind the shaft, and solid rock beyond the grid's sides and bottom.
func _build_backdrop() -> void:
	var tex: Texture2D = RockTiles.canvas_tile("shaft")
	var w: float = float(drill.cols) * drill.cell_m * ppm
	var h: float = float(drill.rows) * drill.cell_m * ppm
	var pad: float = 16.0 * ppm
	_wall(tex, Rect2(-pad, -pad, w + pad * 2.0, h + pad * 2.0), Color(1.9, 1.7, 1.55), -30)
	var apron: Texture2D = RockTiles.canvas_tile("dense")
	var tint := Color(1.1, 1.05, 1.0)
	_wall(apron, Rect2(-pad, -pad, pad, h + pad * 2.0), tint, -21)
	_wall(apron, Rect2(w, -pad, pad, h + pad * 2.0), tint, -21)
	_wall(apron, Rect2(0.0, h, w, pad), tint, -21)


## A tiled wall in chunks. One huge sprite would overlap every light in the scene and Godot gives a
## canvas item only about 15 lights, so the floodlights past that were dropped (the rock beside the
## fight stayed black). Small chunks only meet the lights near them.
func _wall(tex: Texture2D, rect: Rect2, tint: Color, z: int) -> void:
	var k: float = RockTiles.TILE_M * ppm / float(RockTiles.TILE_PX)
	var step: float = float(WALL_CHUNK_PX)
	var y: float = rect.position.y
	while y < rect.end.y:
		var h: float = minf(step, rect.end.y - y)
		var x: float = rect.position.x
		while x < rect.end.x:
			var w: float = minf(step, rect.end.x - x)
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.scale = Vector2(k, k)
			s.region_enabled = true
			var tile_w: float = float(RockTiles.TILE_PX) * k
			s.region_rect = Rect2(Vector2(fposmod(x, tile_w), fposmod(y, tile_w)) / k, Vector2(w, h) / k)
			s.position = Vector2(x, y)
			s.self_modulate = tint
			s.light_mask = LIGHT_MASK
			s.modulate = Color.WHITE
			s.z_index = z
			add_child(s)
			x += step
		y += step
