class_name RockTiles
extends RefCounted
## The painted rock tiles as one atlas (albedo and normal) plus the shader that fills the rock mosaic
## with them. The mosaic keeps the shape, rims, depth tint and bumps at low resolution; the shader
## looks the material up per pixel (warped by sine noise so the boundaries are ragged), reads the
## painted tile at full resolution and multiplies it by the mosaic shading.
## The lead's call: the plain granite tile reads as cobblestones, so the "rock" material uses the
## dense tile with a lighter, warmer tint (slot 1) and rock_albedo.png stays unused.

const TILE_PX: int = 128
const SLOTS: int = 8
## Tile size in meters on screen (art is 160 px per meter, a little larger reads less repetitive).
const TILE_M: float = 1.28
## Slot per material id; 7 is the shaft back wall.
const SLOT_OF: Dictionary = {
	"soft_rock": 0, "rock": 1, "dense_rock": 2, "hard_rock": 3, "iron_ore": 4, "gem": 5, "water_pocket": 6,
	# Buried structures: built things, not strata. Slot 7 is flat in the shader (colour from the mosaic).
	"timber": 7, "steel": 7, "crate": 7, "tape_case": 7, "rubble": 2,
}
const FILES: Array[String] = ["soft", "dense", "dense", "hard", "iron", "gem", "water", "shaft"]
## Per slot tint (granite lighter and warmer; iron a little cooler so it reads as metal in rock).
const TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.2, 1.1, 0.95), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
	Color(0.92, 0.9, 0.95), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
]

## How hard each slot reads (0 crumbly, 1 hard): drives the strata contrast, the cracks and the tone.
const HARDNESS: PackedFloat32Array = [0.0, 0.35, 0.65, 1.0, 0.7, 0.5, 0.2, 0.3]

const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D atlas_a : filter_linear, repeat_disable;
uniform sampler2D atlas_n : filter_linear, repeat_disable;
uniform sampler2D ids : filter_nearest, repeat_disable;
uniform vec2 size_px;
uniform float tile_px;
uniform vec3 tints[8];
uniform float hardness[8];
uniform float ppm = 80.0;
uniform float detail = 0.9;
float hash1(float n) { return fract(sin(n * 91.345) * 437.585); }
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(i.x * 17.0 + i.y * 131.0);
	float b = hash1((i.x + 1.0) * 17.0 + i.y * 131.0);
	float c = hash1(i.x * 17.0 + (i.y + 1.0) * 131.0);
	float d = hash1((i.x + 1.0) * 17.0 + (i.y + 1.0) * 131.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
	vec2 p = UV * size_px;
	vec2 w = vec2(sin(p.y * 0.083 + sin(p.x * 0.047) * 2.1), sin(p.x * 0.071 + sin(p.y * 0.059) * 2.3)) * 6.0;
	w += vec2(sin(p.y * 0.31 + p.x * 0.17), sin(p.x * 0.29 - p.y * 0.21)) * 2.0;
	float idv = texture(ids, UV + w / size_px).r;
	int slot = int(floor(idv * 255.0 / 16.0 + 0.5));
	vec2 f = fract(p / tile_px);
	f = clamp(f, vec2(0.004), vec2(0.996));
	vec2 uv = vec2((float(slot) + f.x) / 8.0, f.y);
	// Break the 1.28 m repeat (critic 007): a second sample of the same tile, larger by the golden
	// ratio and turned 90 degrees (each sample alone stays seamless), blended in by slow noise.
	vec2 f2 = fract(p / (tile_px * 1.618) + vec2(0.37, 0.71));
	f2 = clamp(vec2(f2.y, 1.0 - f2.x), vec2(0.004), vec2(0.996));
	vec2 uv2 = vec2((float(slot) + f2.x) / 8.0, f2.y);
	float mixk = smoothstep(0.32, 0.68, vnoise(p / ppm * 0.45 + vec2(3.1, 7.7)));
	vec4 base = COLOR;
	vec3 tile = mix(texture(atlas_a, uv).rgb, texture(atlas_a, uv2).rgb, mixk);
	// Slot 7 is only the built materials of buried structures (timber, steel, crates): a neutral
	// grain, so the colour painted into the mosaic is the colour on screen.
	if (slot == 7) {
		tile = vec3(0.6 + (dot(tile, vec3(0.33)) - 0.4) * 0.5);
	}
	// Strata: warped horizontal beds (about 1.7 m thick) each a little lighter or darker, with a thin
	// dark seam between beds and finer banding inside them. Hard rock shows it harder (more contrast,
	// cooler and darker, with cracks); soft rock is warmer, paler and crumbly. Water and the shaft wall
	// (slots 6 and 7) keep their own look.
	float rockish = slot < 6 ? 1.0 : 0.0;
	float h = hardness[slot];
	vec2 m = p / ppm;
	// Fractured blocks, not wavy beds (critics 005 and 006: "scrolling wallpaper of wavy sand"): a
	// cellular split into blocks about 1.2 by 0.8 m, each a little lighter or darker, with dark crack
	// seams between them (wider in hard rock). A faint, broad layering is all that is left of the beds.
	vec2 q = vec2(m.x / (1.7 - 0.5 * h), m.y / (0.8 - 0.15 * h));
	vec2 ip = floor(q);
	vec2 fp = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 best = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 cell = ip + g;
			vec2 o = vec2(hash1(cell.x * 17.0 + cell.y * 131.0), hash1(cell.x * 59.0 + cell.y * 23.0 + 7.0)) * 0.8 + 0.1;
			vec2 r = g + o - fp;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = cell;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float gap = sqrt(d2) - sqrt(d1);
	float crack = 1.0 - smoothstep(0.015, 0.06 + 0.04 * h, gap);
	float chip = 1.0 - smoothstep(0.0, 0.25, gap);  // block edges a touch darker: they read as faces
	float bed_k = hash1(best.x * 7.0 + best.y * 113.0) - 0.5;
	float layer = sin(m.y * 0.35 + 0.6 * sin(m.x * 0.13)) * 0.5;
	float strata = 1.0 + rockish * ((0.16 + 0.2 * h) * bed_k * 2.0 + 0.05 * layer);
	// Cracks fade in and out along their length, so the blocks do not close up into paving stones.
	float run = smoothstep(-0.2, 0.6, sin(m.x * 1.7 + sin(m.y * 0.9) * 2.0) * sin(m.y * 2.3 + m.x * 0.4));
	strata *= 1.0 - rockish * ((0.18 + 0.32 * h) * crack * (0.35 + 0.65 * run) + 0.1 * chip);
	vec3 tone = mix(vec3(1.07, 1.02, 0.9), vec3(0.9, 0.95, 1.06), h);
	tile = mix(vec3(dot(tile, vec3(0.33))), tile, 1.0 - 0.25 * h) * mix(vec3(1.0), tone, rockish);
	// Beds also shift colour a little (iron-stained, pale, grey), so the layers read even in dim light.
	vec3 bed_tint = mix(vec3(1.0), vec3(1.0 + 0.3 * bed_k, 1.0 + 0.08 * bed_k, 1.0 - 0.28 * bed_k), rockish);
	COLOR = vec4(tile * tints[slot] * base.rgb * 1.25 * strata * bed_tint, base.a);
	vec3 nm = NORMAL_MAP;
	vec3 tn2 = texture(atlas_n, uv2).xyz;
	tn2 = vec3(1.0 - tn2.y, tn2.x, tn2.z);  // The turned sample's normals turn with it.
	vec3 tn = mix(texture(atlas_n, uv).xyz, tn2, mixk);
	vec2 xy = (nm.xy - 0.5) * 2.0 + (tn.xy - 0.5) * 2.0 * detail;
	NORMAL_MAP = normalize(vec3(xy, 1.0)) * 0.5 + 0.5;
}
"""

## The ore and gem glints: additive and unshaded, each 8 px cell flashing on its own clock (a sharp
## peak, mostly dim), so veins sparkle one after another as the light moves over them.
const GLINT_CODE: String = """
shader_type canvas_item;
render_mode blend_add, unshaded;
// The canvas modulate (the dark ambient) still multiplies this item, so the colours are lifted by its
// inverse: what the painted wash says is what reaches the screen. Without this the veins came out
// as a dim bluish smudge (found in a still, M1b round 3b).
uniform vec3 gain = vec3(3.33, 3.33, 2.94);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 cell = floor(UV * 16.0);
	float ph = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453) * 6.2832;
	float tw = pow(max(0.0, sin(TIME * (1.6 + 1.4 * fract(ph)) + ph)), 10.0);
	COLOR = vec4(c.rgb * (0.55 + 2.2 * tw) * gain, c.a);
}
"""

static var _glint_mat: ShaderMaterial
static var _atlas_a: ImageTexture
static var _atlas_n: ImageTexture
static var _shader: Shader
static var _emission: Image


static func glint_material() -> ShaderMaterial:
	if _glint_mat == null:
		var sh := Shader.new()
		sh.code = GLINT_CODE
		_glint_mat = ShaderMaterial.new()
		_glint_mat.shader = sh
		_glint_mat.set_shader_parameter("gain", Vector3(1.0 / RockView.AMBIENT.r, 1.0 / RockView.AMBIENT.g, 1.0 / RockView.AMBIENT.b))
	return _glint_mat


static func slot_of(material_id: String) -> int:
	return int(SLOT_OF.get(material_id, 2))


static func _load_image(path: String) -> Image:
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != TILE_PX or img.get_height() != TILE_PX:
		img.resize(TILE_PX, TILE_PX)
	return img


static func _build() -> void:
	if _atlas_a != null:
		return
	var a: Image = Image.create(TILE_PX * SLOTS, TILE_PX, false, Image.FORMAT_RGBA8)
	var n: Image = Image.create(TILE_PX * SLOTS, TILE_PX, false, Image.FORMAT_RGBA8)
	a.fill(Color(0.4, 0.38, 0.35, 1.0))
	n.fill(Color(0.5, 0.5, 1.0, 1.0))
	for i: int in range(SLOTS):
		var src_a: Image = _load_image("res://assets/rock/%s_albedo.png" % FILES[i])
		var src_n: Image = _load_image("res://assets/rock/%s_normal.png" % FILES[i])
		if src_a != null:
			a.blit_rect(src_a, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i(i * TILE_PX, 0))
		if src_n != null:
			n.blit_rect(src_n, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i(i * TILE_PX, 0))
	_atlas_a = ImageTexture.create_from_image(a)
	_atlas_n = ImageTexture.create_from_image(n)
	_shader = Shader.new()
	_shader.code = SHADER_CODE


## The gem emission tile (RGBA8, 128 px), or null if missing.
static func emission_image() -> Image:
	if _emission == null:
		_emission = _load_image("res://assets/rock/gem_emission.png")
	return _emission


static func material_for(size_px: Vector2, ids: Texture2D, scale_px_per_m: float) -> ShaderMaterial:
	_build()
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("atlas_a", _atlas_a)
	m.set_shader_parameter("atlas_n", _atlas_n)
	m.set_shader_parameter("ids", ids)
	m.set_shader_parameter("size_px", size_px)
	m.set_shader_parameter("tile_px", TILE_M * scale_px_per_m)
	var t := PackedVector3Array()
	for c: Color in TINTS:
		t.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("tints", t)
	m.set_shader_parameter("hardness", HARDNESS)
	m.set_shader_parameter("ppm", scale_px_per_m)
	return m


## A CanvasTexture of one tile (albedo and normal) for plain sprites (the shaft back wall).
static func canvas_tile(tile_name: String) -> CanvasTexture:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load("res://assets/rock/%s_albedo.png" % tile_name) as Texture2D
	ct.normal_texture = load("res://assets/rock/%s_normal.png" % tile_name) as Texture2D
	ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return ct
