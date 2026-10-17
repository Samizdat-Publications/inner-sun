class_name ArtLib
extends RefCounted
## Loads the painted ship art once and makes sprites from it. Albedo and normal go together in a
## CanvasTexture so the room lamps, alarms and fire light the paint. Art is made at 160 px per meter
## and the game draws it at ppm px per meter, so every sprite is scaled by ppm / ART_PPM.

const ART_PPM: float = 160.0

static var _cache: Dictionary = {}
static var _emission_mat: CanvasItemMaterial
static var _unlit_mat: CanvasItemMaterial


## A lit texture (albedo plus normal) from res://assets/<dir>/<name>_albedo.png, or null.
static func lit(dir: String, tex_name: String) -> Texture2D:
	var key: String = "%s/%s" % [dir, tex_name]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var a: String = "res://assets/%s/%s_albedo.png" % [dir, tex_name]
	var tex: Texture2D = null
	if ResourceLoader.exists(a):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = load(a) as Texture2D
		var n: String = "res://assets/%s/%s_normal.png" % [dir, tex_name]
		if ResourceLoader.exists(n):
			ct.normal_texture = load(n) as Texture2D
		ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tex = ct
	_cache[key] = tex
	return tex


## A plain texture (the emission layer), or null.
static func plain(dir: String, tex_name: String, suffix: String) -> Texture2D:
	var key: String = "%s/%s_%s" % [dir, tex_name, suffix]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var p: String = "res://assets/%s/%s_%s.png" % [dir, tex_name, suffix]
	var tex: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_cache[key] = tex
	return tex


## The wall lamp with its translucent painted backdrop cut away (the art has a dark box around it).
static func lamp_texture() -> Texture2D:
	if _cache.has("lamp_clean"):
		return _cache["lamp_clean"] as Texture2D
	var src: Texture2D = load("res://assets/ship/lamp_albedo.png") as Texture2D
	var tex: Texture2D = null
	if src != null:
		var img: Image = src.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y: int in range(img.get_height()):
			for x: int in range(img.get_width()):
				var c: Color = img.get_pixel(x, y)
				if c.a < 0.82:
					c.a = 0.0
				else:
					c.a = 1.0
				img.set_pixel(x, y, c)
		var ct := CanvasTexture.new()
		ct.diffuse_texture = ImageTexture.create_from_image(img)
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tex = ct
	_cache["lamp_clean"] = tex
	return tex


static func additive_unshaded() -> CanvasItemMaterial:
	if _emission_mat == null:
		_emission_mat = CanvasItemMaterial.new()
		_emission_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_emission_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _emission_mat


static func unshaded() -> CanvasItemMaterial:
	if _unlit_mat == null:
		_unlit_mat = CanvasItemMaterial.new()
		_unlit_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unlit_mat


## A lit sprite whose feet (bottom center) sit at `foot`, in a parent drawn at ppm.
static func prop(dir: String, tex_name: String, foot: Vector2, ppm: float, flip: bool = false, extra_scale: float = 1.0) -> Sprite2D:
	var tex: Texture2D = lit(dir, tex_name)
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	var k: float = ppm / ART_PPM * extra_scale
	var size: Vector2 = tex.get_size()
	s.scale = Vector2(-k if flip else k, k)
	s.position = foot + Vector2(size.x * 0.5 * k if flip else -size.x * 0.5 * k, -size.y * k)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


## The emission twin of a prop sprite: additive, unshaded, set above 1.0 to bloom.
static func glow_of(src: Sprite2D, dir: String, tex_name: String, target: float) -> Sprite2D:
	var e: Texture2D = plain(dir, tex_name, "emission")
	if e == null:
		return null
	var g := Sprite2D.new()
	g.texture = e
	g.centered = false
	g.position = src.position
	g.scale = src.scale
	g.material = additive_unshaded()
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_glow(g, target)
	return g


## An emission sprite is additive and unshaded: its modulate is the brightness it adds (tuned against
## screenshots; above about 1.0 it blooms). Dividing by the CanvasModulate color blew everything out.
static func set_glow(g: CanvasItem, target: float) -> void:
	g.modulate = Color(target, target, target, 1.0)


## A flame tongue: a vertical teardrop (point up, round at the bottom), white-yellow at the heart,
## orange then red toward the edge, transparent at the rim. Made once; used additive.
static func flame_tongue() -> Texture2D:
	if _cache.has("flame_tongue"):
		return _cache["flame_tongue"] as Texture2D
	var w: int = 32
	var h: int = 64
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in range(h):
		var v: float = float(y) / float(h - 1)
		var half: float = 0.0
		if v <= 0.8:
			half = pow(sin(v / 0.8 * PI * 0.5), 1.5)
		else:
			half = cos((v - 0.8) / 0.2 * PI * 0.5)
		for x: int in range(w):
			var u: float = (float(x) - 15.5) / 16.0
			var d: float = absf(u) / maxf(half, 0.001)
			var c := Color(0, 0, 0, 0)
			if d < 1.0:
				var heart: float = pow(1.0 - d * d, 1.4) * (0.3 + 0.7 * v)
				c = _flame_color(heart)
				c.a = clampf(heart * 1.25, 0.0, 1.0) * clampf(v * 5.0, 0.0, 1.0)
			img.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["flame_tongue"] = tex
	return tex


static func _flame_color(heat: float) -> Color:
	var red := Color(1.0, 0.14, 0.03)
	var orange := Color(1.0, 0.55, 0.1)
	var hot := Color(1.0, 0.96, 0.62)
	if heat < 0.5:
		return red.lerp(orange, heat / 0.5)
	return orange.lerp(hot, (heat - 0.5) / 0.5)


## A soft round blob (flame core, embers): bright in the middle, quickly transparent.
static func flame_blob() -> Texture2D:
	if _cache.has("flame_blob"):
		return _cache["flame_blob"] as Texture2D
	var n: int = 48
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in range(n):
		for x: int in range(n):
			var d: float = Vector2(float(x) - 23.5, float(y) - 23.5).length() / 24.0
			var c := Color(0, 0, 0, 0)
			if d < 1.0:
				var k: float = pow(1.0 - d, 1.8)
				c = _flame_color(k)
				c.a = clampf(k * 1.3, 0.0, 1.0)
			img.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["flame_blob"] = tex
	return tex


## A soft grey smoke puff with a little lumpiness; tinted and faded by the particle ramp.
static func smoke_puff() -> Texture2D:
	if _cache.has("smoke_puff"):
		return _cache["smoke_puff"] as Texture2D
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in range(n):
		for x: int in range(n):
			var p := Vector2(float(x) - 31.5, float(y) - 31.5)
			var ang: float = atan2(p.y, p.x)
			var lump: float = 1.0 + 0.16 * sin(ang * 3.0 + 0.7) + 0.1 * sin(ang * 5.0 + 2.1)
			var d: float = p.length() / (32.0 * lump)
			var c := Color(0, 0, 0, 0)
			if d < 1.0:
				c = Color(0.55, 0.53, 0.5, clampf(pow(1.0 - d, 1.5), 0.0, 1.0))
			img.set_pixel(x, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["smoke_puff"] = tex
	return tex
