class_name DepthLayers
extends Node2D
## The depth behind and in front of the rock (ledger 34). The rock is the cut plane of a side
## cutaway, so depth shows through its openings (the shaft above the tower, tunnels, hollows):
##  - FAR WALL (scrolls at F_FAR of the camera): one camera-following rect with a shader that reads its
##    texture by parallax coordinates, cooler, darker and flatter than the rock, with a painted pool of
##    light round the hull. Unlit (lights are not needed, so the 15-lights-per-item limit is moot).
##  - GLOWS (F_FAR): now and then a faint warm (heat) or green (something living) glow far off.
##  - SILHOUETTES (F_MID): sparse big dark shapes (cavern, column, stalactite curtain, arch), a rim of
##    light on one edge, opaque so they read by value and not by alpha. One slot every SLOT_M metres of
##    descent holds a shape with probability SLOT_ODDS, all picked by an integer hash of (segment, slot).
##  - DUST (F_DUST): motes in front of the rock, lit-only (they only exist where the floodlights reach).
## A layer that scrolls at factor f is a node placed at camera * (1 - f): content at layer position Q
## then shows where a point of the world sits when the camera is at Q / f.
## Also the pure depth-band functions the rock shader mirrors (bands 25 to 60 m thick by absolute depth).
## View only: nothing here reads the sim's random streams or changes the sim.

const F_FAR: float = 0.45
const F_MID: float = 0.7
const F_DUST: float = 1.25
const SLOT_M: float = 13.0
const SLOT_ODDS: float = 0.8
const DUST_COUNT: int = 22
const WALL_HALF: Vector2 = Vector2(4600.0, 2700.0)  ## Covers a camera zoom down to about 0.3.
const Z_FAR: int = -30
const Z_GLOW: int = -29
const Z_MID: int = -28
const Z_DUST: int = 20

## Depth bands: boundary k sits at k * BAND_G + jitter within +-BAND_J, so a band is 25 to 59 m thick.
const BAND_G: float = 42.0
const BAND_J: float = 8.5
## Band palette (multiplies the rock): iron red, pale limestone, grey-blue shale, dark basalt, ochre, green-grey.
const PALETTE: Array[Color] = [
	Color(1.22, 0.92, 0.80), Color(1.18, 1.14, 1.02), Color(0.86, 0.98, 1.16),
	Color(0.74, 0.78, 0.86), Color(1.16, 1.05, 0.82), Color(0.92, 1.08, 0.94),
]
const BLEND_M: float = 2.0  ## Bands blend over about this many metres at a boundary.

const K_CAVERN: int = 0
const K_COLUMN: int = 1
const K_CURTAIN: int = 2
const K_ARCH: int = 3
const FILL: Color = Color(0.05, 0.06, 0.09)
const RIMS: Array[Color] = [Color(2.4, 1.35, 0.7), Color(0.8, 1.9, 2.1)]
const GLOWS: Array[Color] = [Color(2.6, 0.95, 0.3, 0.55), Color(0.5, 2.2, 0.9, 0.5)]

const WALL_CODE: String = """
shader_type canvas_item;
uniform sampler2D tex : filter_linear, repeat_enable;
uniform vec2 cam;
uniform float f = 0.45;
uniform float ppm = 80.0;
uniform vec2 pool;
uniform vec3 gain = vec3(0.85, 1.05, 1.4);
varying vec2 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 m = ((wpos - cam) + cam * f) / ppm;
	float a = dot(texture(tex, m / 3.4).rgb, vec3(0.33));
	float b = dot(texture(tex, vec2(m.y, -m.x) / 8.7 + vec2(0.37, 0.71)).rgb, vec3(0.33));
	float g = mix(a, b, 0.35);
	g = clamp(0.2 + (g - 0.2) * 2.4, 0.0, 1.0);  // Averaged samples go flat: push the contrast back around the tile's mean.
	vec2 dd = (wpos - pool) / (ppm * vec2(15.0, 11.0));
	float lit = 0.55 + 0.85 * exp(-dot(dd, dd));
	COLOR = vec4(vec3(g) * gain * lit * 3.8, 1.0);
}
"""

var drill: DrillSim
var ppm: float = 80.0
var seg_top_m: float = 0.0  ## Absolute depth (m below the surface) of the segment's y = 0.

var _seed: int = 0
var _wall: FarWall
var _wall_mat: ShaderMaterial
var _far_root: Node2D
var _mid_root: Node2D
var _dust_root: Node2D
var _glows: Array[Sprite2D] = []
var _dust: Array[Sprite2D] = []
var _dust_base: PackedVector2Array = PackedVector2Array()
var _dust_drift: PackedVector2Array = PackedVector2Array()
var _t: float = 0.0


## The wall's one big rect; the shader does everything.
class FarWall extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-DepthLayers.WALL_HALF, DepthLayers.WALL_HALF * 2.0), Color.WHITE)


# Pure functions (tested) ---------------------------------------------------------------------------

static func hash_i(a: int, b: int, c: int) -> int:
	var h: int = ((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff
	h ^= h >> 15
	h = (h * 0x2c1b3c6d) & 0x7fffffff
	h ^= h >> 12
	h = (h * 0x297a2d39) & 0x7fffffff
	h ^= h >> 15
	return h


## A hash as a float in [0, 1).
static func unit(a: int, b: int, c: int) -> float:
	return float(hash_i(a, b, c) % 100000) / 100000.0


## A sin based hash of a float (CPU only: the shader gets the band numbers as uniforms).
static func _h1(n: float) -> float:
	return fposmod(sin(n * 91.345) * 437.585, 1.0)


## Depth (m) at which band k begins.
static func band_boundary(k: int) -> float:
	return float(k) * BAND_G + (_h1(float(k) * 7.31 + 3.7) - 0.5) * 2.0 * BAND_J


## The band that holds absolute depth `d`.
static func band_index(d: float) -> int:
	var k0: int = floori(d / BAND_G)
	for j: int in [k0 + 1, k0, k0 - 1]:
		if band_boundary(j) <= d:
			return j
	return k0 - 2


static func band_thickness(k: int) -> float:
	return band_boundary(k + 1) - band_boundary(k)


## The colour multiplier of band k: a palette entry picked by hash, with a small value shift.
static func band_tint(k: int) -> Color:
	var idx: int = mini(floori(_h1(float(k) * 3.17 + 1.3) * 6.0), 5)
	var vs: float = 1.0 + (_h1(float(k) * 5.9 + 0.7) - 0.5) * 0.16
	var c: Color = PALETTE[idx]
	return Color(c.r * vs, c.g * vs, c.b * vs, 1.0)


## The tint at depth `d`: the band's own, blended with its neighbour within BLEND_M / 2 of a boundary.
static func tint_at(d: float) -> Color:
	var k: int = band_index(d)
	var lo: float = d - band_boundary(k)
	var hi: float = band_boundary(k + 1) - d
	var half: float = BLEND_M * 0.5
	var w_prev: float = 0.5 * (1.0 - smoothstep(0.0, half, lo))
	var w_next: float = 0.5 * (1.0 - smoothstep(0.0, half, hi))
	var here: Color = band_tint(k)
	var c: Color = here * (1.0 - w_prev - w_next) + band_tint(k - 1) * w_prev + band_tint(k + 1) * w_next
	c.a = 1.0
	return c


## Hands the rock shader the bands that cover [top_m, bottom_m] (absolute depth): band j is band k0 + j,
## band_b[j] is where it begins (n + 1 entries), band_c[j] its colour. The CPU does the hashing so the
## shader never depends on GPU sine precision.
static func band_arrays(top_m: float, bottom_m: float) -> Dictionary:
	var k0: int = band_index(top_m) - 1
	var n: int = clampi(band_index(bottom_m) + 2 - k0, 1, 31)
	var b := PackedFloat32Array()
	var c := PackedVector3Array()
	for j: int in range(32):
		b.append(band_boundary(k0 + j) if j <= n else 1.0e6)
		var t: Color = band_tint(k0 + j) if j < n else Color.WHITE
		c.append(Vector3(t.r, t.g, t.b))
	return {"k0": k0, "n": n, "b": b, "c": c}


static func apply_bands(mat: ShaderMaterial, top_m: float, bottom_m: float) -> void:
	var a: Dictionary = band_arrays(top_m, bottom_m)
	mat.set_shader_parameter("seg_top_m", top_m)
	mat.set_shader_parameter("band_b", a["b"])
	mat.set_shader_parameter("band_c", a["c"])
	mat.set_shader_parameter("band_n", int(a["n"]))


static func slot_of_depth(d: float) -> int:
	return floori(d / SLOT_M)


## What a slot of descent holds, from the segment seed and the slot number alone.
static func shape_for(seed_i: int, slot: int) -> Dictionary:
	var u0: float = unit(seed_i, slot, 1)
	var kind: int = hash_i(seed_i, slot, 2) % 4
	var d: float = (float(slot) + 0.15 + 0.7 * unit(seed_i, slot, 3)) * SLOT_M
	var w: float = 5.0 + 5.0 * unit(seed_i, slot, 4)
	var h: float = 4.0 + 4.0 * unit(seed_i, slot, 5)
	if kind == K_COLUMN:
		w = 1.3 + 1.0 * unit(seed_i, slot, 4)
		h = 7.0 + 3.0 * unit(seed_i, slot, 5)
	elif kind == K_ARCH:
		w = 7.0 + 3.0 * unit(seed_i, slot, 4)
		h = 5.0 + 3.0 * unit(seed_i, slot, 5)
	return {
		"has": u0 < SLOT_ODDS, "kind": kind, "depth_m": d, "dx_m": (unit(seed_i, slot, 6) - 0.5) * 32.0,
		"w_m": w, "h_m": h, "rim": hash_i(seed_i, slot, 7) % 2,
		"glow": unit(seed_i, slot, 8) < 0.42, "glow_kind": 1 if unit(seed_i, slot, 9) < 0.4 else 0,
		"glow_depth_m": (float(slot) + unit(seed_i, slot, 10)) * SLOT_M, "glow_dx_m": (unit(seed_i, slot, 11) - 0.5) * 16.0,
		"glow_r_m": 3.0 + 3.0 * unit(seed_i, slot, 12),
	}


## Outline of a shape in metres around its centre.
static func shape_points(kind: int, w: float, h: float, s: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		K_COLUMN:
			var raw: Array[Vector2] = [Vector2(-0.9, -0.5), Vector2(0.9, -0.5), Vector2(0.45, -0.25), Vector2(0.35, 0.05),
					Vector2(0.5, 0.3), Vector2(1.0, 0.5), Vector2(-1.0, 0.5), Vector2(-0.5, 0.3), Vector2(-0.3, 0.05), Vector2(-0.45, -0.25)]
			for i: int in range(raw.size()):
				var j: float = 0.85 + 0.3 * unit(s, i, 21)
				pts.append(Vector2(raw[i].x * w * j, raw[i].y * h))
		K_CURTAIN:
			var n: int = 7
			pts.append(Vector2(-w * 0.5, -h * 0.5))
			pts.append(Vector2(w * 0.5, -h * 0.5))
			for i: int in range(n, 0, -1):
				var x1: float = -w * 0.5 + w * float(i) / float(n)
				var x0: float = -w * 0.5 + w * float(i - 1) / float(n)
				pts.append(Vector2(x1, -h * 0.5 + 0.9))
				pts.append(Vector2((x0 + x1) * 0.5, -h * 0.5 + 1.2 + (h - 1.2) * (0.35 + 0.65 * unit(s, i, 22))))
			pts.append(Vector2(-w * 0.5, -h * 0.5 + 0.9))
		K_ARCH:
			var leg: float = w * 0.2
			var steps: int = 10
			for i: int in range(steps + 1):
				var a: float = PI + PI * float(i) / float(steps)
				pts.append(Vector2(cos(a) * w * 0.5, h * 0.5 + sin(a) * h))
			pts.append(Vector2(w * 0.5, h * 0.5))
			pts.append(Vector2(w * 0.5 - leg, h * 0.5))
			for i: int in range(steps, -1, -1):
				var a: float = PI + PI * float(i) / float(steps)
				pts.append(Vector2(cos(a) * (w * 0.5 - leg), h * 0.5 + sin(a) * (h - leg)))
			pts.append(Vector2(-w * 0.5 + leg, h * 0.5))
			pts.append(Vector2(-w * 0.5, h * 0.5))
		_:
			var n2: int = 16
			for i: int in range(n2):
				var a2: float = TAU * float(i) / float(n2)
				var r: float = 0.8 + 0.4 * unit(s, i, 23)
				pts.append(Vector2(cos(a2) * w * 0.5 * r, sin(a2) * h * 0.5 * r))
	return pts


# Build ---------------------------------------------------------------------------------------------

func setup(p_drill: DrillSim, p_ppm: float) -> void:
	drill = p_drill
	ppm = p_ppm
	seg_top_m = drill.start_depth_m - drill.start_y
	_seed = drill.segment_id.hash() & 0x7fffffff
	_build_wall()
	_far_root = Node2D.new()
	_mid_root = Node2D.new()
	_far_root.z_index = Z_GLOW
	_mid_root.z_index = Z_MID
	add_child(_far_root)
	add_child(_mid_root)
	var seg_h: float = float(drill.rows) * drill.cell_m
	var s0: int = slot_of_depth(seg_top_m)
	var s1: int = slot_of_depth(seg_top_m + seg_h)
	for slot: int in range(s0, s1 + 1):
		var sh: Dictionary = shape_for(_seed, slot)
		if bool(sh["has"]):
			_add_shape(sh, slot)
		if bool(sh["glow"]):
			_add_glow(sh)
	_build_dust()


func _build_wall() -> void:
	_wall = FarWall.new()
	_wall.z_index = Z_FAR
	_wall_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WALL_CODE
	_wall_mat.shader = sh
	_wall_mat.set_shader_parameter("tex", load("res://assets/rock/shaft_albedo.png") as Texture2D)
	_wall_mat.set_shader_parameter("f", F_FAR)
	_wall_mat.set_shader_parameter("ppm", ppm)
	_wall.material = _wall_mat
	add_child(_wall)


## Layer position of a shape at absolute depth `d_m`, `dx_m` to the side of where the ship starts.
func _layer_pos(f: float, d_m: float, dx_m: float) -> Vector2:
	return Vector2(f * drill.start_center_x * ppm + dx_m * ppm, f * (d_m - seg_top_m) * ppm)


func _poly(pts: PackedVector2Array, scale_k: float, off: Vector2, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(v * scale_k * ppm + off)
	p.polygon = out
	p.color = col
	p.antialiased = true
	return p


func _add_shape(sh: Dictionary, slot: int) -> void:
	var holder := Node2D.new()
	holder.position = _layer_pos(F_MID, float(sh["depth_m"]), float(sh["dx_m"]))
	var pts: PackedVector2Array = shape_points(int(sh["kind"]), float(sh["w_m"]), float(sh["h_m"]), hash_i(_seed, slot, 30))
	var rim: Color = RIMS[int(sh["rim"])]
	holder.add_child(_poly(pts, 1.16, Vector2.ZERO, Color(FILL.r, FILL.g, FILL.b, 0.55)))  # soft halo
	holder.add_child(_poly(pts, 1.0, Vector2(0.0, 0.26 * ppm), rim))  # rim of light on the lower edges
	holder.add_child(_poly(pts, 1.0, Vector2.ZERO, FILL))
	_mid_root.add_child(holder)


func _add_glow(sh: Dictionary) -> void:
	var g := Sprite2D.new()
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	g.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	g.self_modulate = GLOWS[int(sh["glow_kind"])]
	g.scale = Vector2.ONE * float(sh["glow_r_m"]) * 2.0 * ppm / 64.0
	g.position = _layer_pos(F_FAR, float(sh["glow_depth_m"]), float(sh["glow_dx_m"]))
	_far_root.add_child(g)
	_glows.append(g)


func _build_dust() -> void:
	_dust_root = Node2D.new()
	_dust_root.z_index = Z_DUST
	add_child(_dust_root)
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 16
	tex.height = 16
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY
	for i: int in range(DUST_COUNT):
		var m := Sprite2D.new()
		m.texture = tex
		m.material = mat
		m.light_mask = RockView.LIGHT_MASK
		m.self_modulate = Color(1.25, 1.15, 1.0, 0.4)  # Soft and dim: brighter specks read as static.
		m.scale = Vector2.ONE * (1.1 + 1.3 * unit(_seed, i, 44))
		_dust.append(m)
		_dust_root.add_child(m)
		_dust_base.append(Vector2(unit(_seed, i, 40), unit(_seed, i, 41)))
		_dust_drift.append(Vector2(unit(_seed, i, 42) - 0.5, unit(_seed, i, 43) * 0.6 + 0.2) * 14.0)


# Per frame -----------------------------------------------------------------------------------------

## Called every frame after the camera moved: `cam` is the camera's centre in world px, `light` the
## hull's centre (the far wall's pool of light), `combat` hides the dust.
func follow(cam: Vector2, zoom: float, light: Vector2, combat: bool, delta: float) -> void:
	_t += delta
	_wall.position = cam
	_wall_mat.set_shader_parameter("cam", cam)
	_wall_mat.set_shader_parameter("pool", light)
	_far_root.position = cam * (1.0 - F_FAR)
	_mid_root.position = cam * (1.0 - F_MID)
	var pulse: float = 0.85 + 0.15 * sin(_t * 0.9)
	for g: Sprite2D in _glows:
		g.modulate.a = pulse
	_dust_root.visible = not combat
	if combat:
		return
	var rect: Rect2 = RunScreen.WORLD_RECT
	var inv: float = 1.0 / maxf(zoom, 0.01)
	for i: int in range(_dust.size()):
		var b: Vector2 = _dust_base[i]
		var dr: Vector2 = _dust_drift[i]
		var sx: float = fposmod(b.x * rect.size.x - F_DUST * cam.x * zoom + dr.x * _t, rect.size.x)
		var sy: float = fposmod(b.y * rect.size.y - F_DUST * cam.y * zoom + dr.y * _t, rect.size.y)
		var m: Sprite2D = _dust[i]
		m.position = cam + (rect.position + Vector2(sx, sy) - Vector2(960.0, 540.0)) * inv
		m.scale = Vector2.ONE * (0.2 + 0.16 * unit(_seed, i, 44)) * inv
