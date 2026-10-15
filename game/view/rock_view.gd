class_name RockView
extends Node2D
## Draws a drilling segment's rock grid (DrillSim.grid) in segment space: this node's origin is the
## segment's top-left corner and it never moves; the camera and the ship move over it.
## The grid is cut into 16 x 16 cell chunks. Each chunk is one sprite with a CanvasTexture (albedo and
## normal) painted from the grid at 8 px per cell and scaled up to the view's pixels per meter:
##  - colors come from the material's data color hint, with value noise, strata banding, a depth tint
##    and darker rims where solid meets air; boundaries between materials and between rock and air are
##    ragged (the lookup is warped by noise), so the rock does not read as a grid of squares;
##  - the normal map comes from a smooth height field (bilinear solid/air) plus noise bumps, so shaft
##    walls and pockets catch the hull floodlights;
##  - gem and ore cells get a second, additive and unshaded glint layer that blooms;
##  - air cells are transparent over a dim back wall, so the shaft is not pure black.
## Only chunks whose change counter moved are repainted (plus neighbours when a cell on a border
## changed), a few per frame. Rock is on light mask 2: only the hull floodlights and the crown glow
## (range_item_cull_mask 2) reach it, never the ship's interior lamps.
## Reads sim state only; paints with its own integer hash, so the picture is the same every run.

const CELLS: int = 16
const CELL_PX: int = 8
const CHUNK_PX: int = CELLS * CELL_PX
const PAD: int = CELLS + 2
const TILE: int = 256
const LIGHT_MASK: int = 2
const BUDGET_USEC: int = 9000
## Occluders are built only if rock shadows are on. They are off: the shadow of a solid polygon also
## covers its own rock face, which would black out the very walls the floodlights should reveal.
const ROCK_SHADOWS: bool = false
const AMBIENT: Color = Color(0.30, 0.30, 0.34)
## Albedo gain for rock sprites (HDR modulate): the ambient is so dark that plain rock colors read black.
const ROCK_GAIN: float = 1.9

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

var drill: DrillSim
var ppm: float = 80.0
var serial: int = -1

var _scale: float = 5.0
var _cr: PackedFloat32Array = PackedFloat32Array()
var _cg: PackedFloat32Array = PackedFloat32Array()
var _cb: PackedFloat32Array = PackedFloat32Array()
var _kind: PackedByteArray = PackedByteArray()  # 0 rock, 1 ore, 2 gem, 3 water
var _seen: PackedByteArray = PackedByteArray()
var _last: PackedInt32Array = PackedInt32Array()
var _dirty: Dictionary = {}
var _rock: RockNode
var _img_a: Image
var _img_n: Image
var _tex_a: ImageTexture
var _tex_n: ImageTexture
var _mosaic_dirty: bool = false
var _glints: Array[Sprite2D] = []
var _occluders: Array[LightOccluder2D] = []
var _gtex: Array[ImageTexture] = []
var _time: float = 0.0
var last_build_ms: float = 0.0
var builds: int = 0


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
	var origin_cy: int = clampi(floori(drill.ship_pos.y / (drill.cell_m * float(CELLS))), 0, drill.chunk_rows - 1)
	# Nearest rows to the ship first, so the picture fills in around it.
	var order: Array[int] = []
	for d: int in range(drill.chunk_rows):
		for sign_i: int in [1, -1]:
			var cy: int = origin_cy + d * sign_i
			if cy < 0 or cy >= drill.chunk_rows or (d == 0 and sign_i == -1):
				continue
			for cx: int in range(drill.chunk_cols):
				order.append(cy * drill.chunk_cols + cx)
	var mw: int = drill.chunk_cols * CHUNK_PX
	var mh: int = drill.chunk_rows * CHUNK_PX
	_img_a = Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	_img_n = Image.create(mw, mh, false, Image.FORMAT_RGBA8)
	_img_n.fill(Color8(128, 128, 255, 255))
	_tex_a = ImageTexture.create_from_image(_img_a)
	_tex_n = ImageTexture.create_from_image(_img_n)
	var ct := CanvasTexture.new()
	ct.diffuse_texture = _tex_a
	ct.normal_texture = _tex_n
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rock = RockNode.new()
	_rock.tex = ct
	_rock.size_px = Vector2(float(mw), float(mh)) * _scale
	_rock.light_mask = LIGHT_MASK
	_rock.z_index = -20
	_rock.self_modulate = Color(ROCK_GAIN, ROCK_GAIN, ROCK_GAIN, 1.0)
	add_child(_rock)
	for i: int in range(n):
		_glints.append(null)
		_gtex.append(null)
		_occluders.append(null)
	for i: int in order:
		_dirty[i] = true


## Chunks still waiting to be painted (captures wait for zero).
func pending() -> int:
	return _dirty.size()


func _process(delta: float) -> void:
	_time += delta
	if drill == null:
		return
	var ch: PackedInt32Array = drill.chunk_changes
	for i: int in range(ch.size()):
		if ch[i] != _last[i]:
			_last[i] = ch[i]
			_note_change(i)
	var t0: int = Time.get_ticks_usec()
	var keys: Array = _dirty.keys()
	for k: Variant in keys:
		var i: int = k
		_dirty.erase(i)
		_paint(i % drill.chunk_cols, i / drill.chunk_cols)
		if Time.get_ticks_usec() - t0 > BUDGET_USEC:
			break
	if _mosaic_dirty:
		_mosaic_dirty = false
		_tex_a.update(_img_a)
		_tex_n.update(_img_n)
	for i: int in range(_glints.size()):
		var g: Sprite2D = _glints[i]
		if g != null:
			var tw: float = 0.78 + 0.22 * sin(_time * 3.1 + float(i) * 1.9) + 0.08 * sin(_time * 7.3 + float(i))
			g.self_modulate = Color(tw, tw, tw, 1.0)


func _note_change(ci: int) -> void:
	var ccols: int = drill.chunk_cols
	var cx: int = ci % ccols
	var cy: int = ci / ccols
	var cols: int = drill.cols
	var grid: PackedByteArray = drill.grid
	for r: int in range(cy * CELLS, mini((cy + 1) * CELLS, drill.rows)):
		for c: int in range(cx * CELLS, mini((cx + 1) * CELLS, cols)):
			var k: int = r * cols + c
			if grid[k] == _seen[k]:
				continue
			_seen[k] = grid[k]
			_dirty[ci] = true
			var lc: int = c - cx * CELLS
			var lr: int = r - cy * CELLS
			var dx: int = -1 if lc == 0 else (1 if lc == CELLS - 1 else 0)
			var dy: int = -1 if lr == 0 else (1 if lr == CELLS - 1 else 0)
			if dx != 0:
				_mark(cx + dx, cy)
			if dy != 0:
				_mark(cx, cy + dy)
			if dx != 0 and dy != 0:
				_mark(cx + dx, cy + dy)


func _mark(cx: int, cy: int) -> void:
	if cx >= 0 and cx < drill.chunk_cols and cy >= 0 and cy < drill.chunk_rows:
		_dirty[cy * drill.chunk_cols + cx] = true


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


func _make_palette() -> void:
	_cr.resize(256)
	_cg.resize(256)
	_cb.resize(256)
	_kind.resize(256)
	for code: int in range(256):
		var m: Dictionary = drill.material(code)
		var col := Color(0.42, 0.38, 0.34)
		if not m.is_empty() and m.has("color"):
			col = Color.html(str(m["color"]))
		_cr[code] = col.r
		_cg[code] = col.g
		_cb[code] = col.b
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


func _paint(cx: int, cy: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var idx: int = cy * drill.chunk_cols + cx
	var gx0: int = cx * CELLS
	var gy0: int = cy * CELLS
	var pc := PackedByteArray()
	pc.resize(PAD * PAD)
	var ps := PackedFloat32Array()
	ps.resize(PAD * PAD)
	var pv := PackedFloat32Array()
	pv.resize(PAD * PAD)
	for j: int in range(PAD):
		for i: int in range(PAD):
			var code: int = _code_at(gx0 - 1 + i, gy0 - 1 + j)
			pc[j * PAD + i] = code
			ps[j * PAD + i] = 0.0 if code == 0 else 1.0
			pv[j * PAD + i] = 0.88 + 0.24 * _hash(gx0 - 1 + i, gy0 - 1 + j, 9)
	# Per column and per row lookups.
	var ci := PackedInt32Array()
	var ft := PackedFloat32Array()
	var dft := PackedFloat32Array()
	ci.resize(CHUNK_PX)
	ft.resize(CHUNK_PX)
	dft.resize(CHUNK_PX)
	for p: int in range(CHUNK_PX):
		var u: float = (float(p) + 0.5) / float(CELL_PX) - 0.5
		var i0: int = floori(u)
		var f: float = u - float(i0)
		ci[p] = i0 + 1
		ft[p] = f * f * (3.0 - 2.0 * f)
		dft[p] = 6.0 * f * (1.0 - f)
	var alb: PackedByteArray = PackedByteArray()
	alb.resize(CHUNK_PX * CHUNK_PX * 4)
	var nrm: PackedByteArray = _flat_normal.duplicate()
	var tile: PackedFloat32Array = _tile
	var total_px: float = float(drill.rows * CELL_PX)
	for y: int in range(CHUNK_PX):
		var pj: int = ci[y]
		var ty: float = ft[y]
		var dty: float = dft[y]
		var Y: int = gy0 * CELL_PX + y
		var ydepth: float = clampf(float(Y) / total_px, 0.0, 1.0)
		for x: int in range(CHUNK_PX):
			var pi: int = ci[x]
			var tx: float = ft[x]
			var s00: float = ps[pj * PAD + pi]
			var s10: float = ps[pj * PAD + pi + 1]
			var s01: float = ps[(pj + 1) * PAD + pi]
			var s11: float = ps[(pj + 1) * PAD + pi + 1]
			var top: float = s00 + (s10 - s00) * tx
			var bot: float = s01 + (s11 - s01) * tx
			var h: float = top + (bot - top) * ty
			var X: int = gx0 * CELL_PX + x
			var na: float = tile[((Y & 255) << 8) | (X & 255)]
			var v: float = h + (na - 0.5) * 0.3
			var cover: float = clampf((v - 0.5) * 10.0 + 0.5, 0.0, 1.0)
			if cover <= 0.004:
				continue
			var nb: float = tile[(((Y + (X >> 2) * 5 + 17) & 255) << 8) | ((X + (Y >> 1) * 3 + 101) & 255)]
			# Material from a noise-warped lookup, so boundaries are ragged.
			var wi: int = clampi(floori((float(x) + (nb - 0.5) * 8.0) / float(CELL_PX)) + 1, 0, PAD - 1)
			var wj: int = clampi(floori((float(y) + (na - 0.5) * 8.0) / float(CELL_PX)) + 1, 0, PAD - 1)
			var cell: int = wj * PAD + wi
			var code: int = pc[cell]
			if code == 0:
				cell = clampi(y / CELL_PX + 1, 0, PAD - 1) * PAD + clampi(x / CELL_PX + 1, 0, PAD - 1)
				code = pc[cell]
				if code == 0:
					for nbr: int in [cell - 1, cell + 1, cell - PAD, cell + PAD]:
						if nbr >= 0 and nbr < PAD * PAD and pc[nbr] != 0:
							cell = nbr
							code = pc[nbr]
							break
			var kind: int = _kind[code]
			var tex: float = 0.8 + (na - 0.5) * 0.4 + (nb - 0.5) * 0.24
			var band: float = 0.07 * sin(float(Y) * 0.045 + nb * 2.6)
			var shade: float = tex * pv[cell] * (1.0 + band) * (1.0 - 0.28 * ydepth)
			var depth_in: float = clampf((v - 0.5) * 3.2, 0.0, 1.0)
			shade *= 0.32 + 0.68 * depth_in
			var r: float = _cr[code]
			var g: float = _cg[code]
			var b: float = _cb[code]
			var bump: float = 1.0
			if kind == 1:
				if na > 0.7:
					var m: float = clampf((na - 0.7) * 5.0, 0.0, 0.7)
					r = lerpf(r, 1.0, m)
					g = lerpf(g, 0.78, m)
					b = lerpf(b, 0.5, m)
			elif kind == 2:
				var f: float = smoothstep(0.45, 0.85, nb)
				shade = 0.4 + 0.55 * f * (0.7 + 0.5 * na)
				bump = 1.5
			elif kind == 3:
				shade *= 0.55
				var sheen: float = smoothstep(0.78, 0.95, 0.5 + 0.5 * sin(float(Y) * 0.4 + na * 5.0))
				b += sheen * 0.35
				g += sheen * 0.15
				bump = 0.15
			var o: int = (y * CHUNK_PX + x) * 4
			alb[o] = clampi(roundi(r * shade * 255.0), 0, 255)
			alb[o + 1] = clampi(roundi(g * shade * 255.0), 0, 255)
			alb[o + 2] = clampi(roundi(b * shade * 255.0), 0, 255)
			alb[o + 3] = clampi(roundi(cover * 255.0), 0, 255)
			var dhdx: float = ((s10 - s00) * (1.0 - ty) + (s11 - s01) * ty) * dft[x] * 0.125
			var dhdy: float = ((s01 - s00) * (1.0 - tx) + (s11 - s10) * tx) * dty * 0.125
			var gxn: float = tile[((Y & 255) << 8) | ((X + 2) & 255)] - tile[((Y & 255) << 8) | ((X - 2) & 255)]
			var gyn: float = tile[(((Y + 2) & 255) << 8) | (X & 255)] - tile[(((Y - 2) & 255) << 8) | (X & 255)]
			var nx: float = -(dhdx * 3.4 + gxn * 0.32 * bump)
			var ny: float = dhdy * 3.4 + gyn * 0.32 * bump
			var inv: float = 1.0 / sqrt(nx * nx + ny * ny + 1.0)
			nrm[o] = clampi(roundi((nx * inv * 0.5 + 0.5) * 255.0), 0, 255)
			nrm[o + 1] = clampi(roundi((ny * inv * 0.5 + 0.5) * 255.0), 0, 255)
			nrm[o + 2] = clampi(roundi((inv * 0.5 + 0.5) * 255.0), 0, 255)
	_apply(idx, alb, nrm)
	_paint_glint(idx, cx, cy)
	if ROCK_SHADOWS:
		_build_occluder(idx, cx, cy)
	last_build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	builds += 1


func _apply(idx: int, alb: PackedByteArray, nrm: PackedByteArray) -> void:
	var at := Vector2i((idx % drill.chunk_cols) * CHUNK_PX, (idx / drill.chunk_cols) * CHUNK_PX)
	var src := Rect2i(0, 0, CHUNK_PX, CHUNK_PX)
	_img_a.blit_rect(Image.create_from_data(CHUNK_PX, CHUNK_PX, false, Image.FORMAT_RGBA8, alb), src, at)
	_img_n.blit_rect(Image.create_from_data(CHUNK_PX, CHUNK_PX, false, Image.FORMAT_RGBA8, nrm), src, at)
	_mosaic_dirty = true


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
			var cr: float = 0.75 if gem else 1.0
			var cg: float = 1.0 if gem else 0.78
			var cb: float = 0.95 if gem else 0.4
			var n: int = 6 if gem else 3
			if gem:
				for yy: int in range(CELL_PX):
					for xx: int in range(CELL_PX):
						var d: float = Vector2(float(xx) - 3.5, float(yy) - 3.5).length() / 5.0
						_put(px, lc * CELL_PX + xx, lr * CELL_PX + yy, cr, cg, cb, 0.12 * clampf(1.0 - d, 0.0, 1.0))
			for k: int in range(n):
				var sx: int = lc * CELL_PX + 1 + floori(_hash(c, r, 20 + k) * 6.0)
				var sy: int = lr * CELL_PX + 1 + floori(_hash(c, r, 40 + k) * 6.0)
				var inten: float = 0.55 + 0.45 * _hash(c, r, 60 + k)
				if not gem:
					inten *= 0.4
				_put(px, sx, sy, cr, cg, cb, inten)
				if gem:
					for dxy: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						_put(px, sx + dxy.x, sy + dxy.y, cr, cg, cb, inten * 0.5)
				if gem:
					for dxy2: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
						_put(px, sx + dxy2.x, sy + dxy2.y, cr, cg, cb, inten * 0.25)
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
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		g.material = mat
		# CanvasModulate multiplies everything, so divide it out and push the sparkles above 1.0.
		g.modulate = Color(1.7 / AMBIENT.r, 1.7 / AMBIENT.g, 1.7 / AMBIENT.b, 1.0)
		add_child(g)
		_glints[idx] = g
		_gtex[idx] = ImageTexture.create_from_image(img)
		g.texture = _gtex[idx]
	else:
		_gtex[idx].update(img)
	g.visible = true


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
	var tex: Texture2D = ShipView.canvas_tex("res://assets/test/rock_albedo.png", "res://assets/test/rock_normal.png")
	if tex == null:
		return
	var w: float = float(drill.cols) * drill.cell_m * ppm
	var h: float = float(drill.rows) * drill.cell_m * ppm
	var pad: float = 16.0 * ppm
	_wall(tex, Rect2(-pad, -pad, w + pad * 2.0, h + pad * 2.0), Color(1.7, 1.45, 1.3), -30)
	var apron := Color(1.5, 1.4, 1.3)
	_wall(tex, Rect2(-pad, -pad, pad, h + pad * 2.0), apron, -21)
	_wall(tex, Rect2(w, -pad, pad, h + pad * 2.0), apron, -21)
	_wall(tex, Rect2(0.0, h, w, pad), apron, -21)


func _wall(tex: Texture2D, rect: Rect2, tint: Color, z: int) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(rect.position, rect.size)
	s.position = rect.position
	s.self_modulate = tint
	s.light_mask = LIGHT_MASK
	s.modulate = Color.WHITE
	s.z_index = z
	add_child(s)
