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
}
const FILES: Array[String] = ["soft", "dense", "dense", "hard", "iron", "gem", "water", "shaft"]
## Per slot tint (granite lighter and warmer; iron a little cooler so it reads as metal in rock).
const TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.2, 1.1, 0.95), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
	Color(0.92, 0.9, 0.95), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0),
]

const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D atlas_a : filter_linear, repeat_disable;
uniform sampler2D atlas_n : filter_linear, repeat_disable;
uniform sampler2D ids : filter_nearest, repeat_disable;
uniform vec2 size_px;
uniform float tile_px;
uniform vec3 tints[8];
uniform float detail = 0.9;
void fragment() {
	vec2 p = UV * size_px;
	vec2 w = vec2(sin(p.y * 0.083 + sin(p.x * 0.047) * 2.1), sin(p.x * 0.071 + sin(p.y * 0.059) * 2.3)) * 6.0;
	w += vec2(sin(p.y * 0.31 + p.x * 0.17), sin(p.x * 0.29 - p.y * 0.21)) * 2.0;
	float idv = texture(ids, UV + w / size_px).r;
	int slot = int(floor(idv * 255.0 / 16.0 + 0.5));
	vec2 f = fract(p / tile_px);
	f = clamp(f, vec2(0.004), vec2(0.996));
	vec2 uv = vec2((float(slot) + f.x) / 8.0, f.y);
	vec4 base = COLOR;
	vec3 tile = texture(atlas_a, uv).rgb;
	COLOR = vec4(tile * tints[slot] * base.rgb * 1.25, base.a);
	vec3 nm = NORMAL_MAP;
	vec3 tn = texture(atlas_n, uv).xyz;
	vec2 xy = (nm.xy - 0.5) * 2.0 + (tn.xy - 0.5) * 2.0 * detail;
	NORMAL_MAP = normalize(vec3(xy, 1.0)) * 0.5 + 0.5;
}
"""

static var _atlas_a: ImageTexture
static var _atlas_n: ImageTexture
static var _shader: Shader
static var _emission: Image


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
	return m


## A CanvasTexture of one tile (albedo and normal) for plain sprites (the shaft back wall).
static func canvas_tile(tile_name: String) -> CanvasTexture:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load("res://assets/rock/%s_albedo.png" % tile_name) as Texture2D
	ct.normal_texture = load("res://assets/rock/%s_normal.png" % tile_name) as Texture2D
	ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return ct
