class_name StructureLayer
extends Node2D
## The buried structure of the drilling segment, in the world (segment space: this node sits at the
## origin of the rock, like RockView). It only READS the sim and follows `sim.events` by index.
##  - the old air: RockView paints a structure's interior as air, so this layer lays a dark room
##    under the rock (an alpha mask built from the cells, smoothed like the rock's own cut edges),
##    a faint warm glow in it (additive, unshaded, flickering a little) and one warm lamp that lights
##    the rock around the room;
##  - the break-in ("structure_entered"): the lamp flares and settles brighter than before, the glow
##    comes up and a ring spreads from the room;
##  - a crate opening ("loot"): a warm flash ring and a burst of splinters where the crate stood (the
##    loot text itself is a floating pickup, see DigLog and PickupLayer).
## The rock is one canvas item that meets every light, so there is exactly one lamp here, and it is
## switched off when the segment has no structure.

const CELL_PX: int = 8  ## Texture pixels per cell (the same density as RockView's mosaic).
const GLOW_BEFORE: float = 0.30
const GLOW_AFTER: float = 0.6
const LAMP_BEFORE: float = 0.30
const LAMP_AFTER: float = 0.85
const LAMP_FLARE: float = 1.9
const FLARE_S: float = 1.4
const RING_S: float = 0.7
const BOOST: float = 1.9
const POPS: int = 4  ## Splinter bursts that can play at once.
const WARM: Color = Color(1.0, 0.62, 0.30)
const ROOM: Color = Color8(14, 11, 9)  ## The old air's dark, unless the structure's "light" says otherwise.

## One additive, unshaded drawing node for the rings.
class Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var sim: Sim = null
var ppm: float = 80.0
var serial: int = -1  ## The grid serial the layer was built for.
var lit_cells: int = 0  ## Cells of the room drawn (tests).
var lamp: PointLight2D = null
var tint: Color = WARM  ## The structure's light colour (its data's "light.color").
var _room_col: Color = ROOM
var _facets: bool = false
var _glow_k: float = 1.0  ## "light.glow": the glow's strength against the default.
var _lamp_k: float = 1.0  ## "light.lamp": the lamp's strength against the default.
var lamp_energy: float = 0.0  ## Where the lamp is now (tests).
var glow_level: float = 0.0
var entered: bool = false
var _seen: int = 0
var _t: float = 0.0
var _enter_age: float = 99.0
var _rect: Rect2i = Rect2i()
var _lit: PackedByteArray = PackedByteArray()
var _room: Sprite2D = null
var _glow: Sprite2D = null
var _tex_room: ImageTexture = null
var _tex_glow: ImageTexture = null
var _center: Vector2 = Vector2.ZERO
var _since_check: int = 0
var _rings: Array[Dictionary] = []  ## {pos, age, radius, life}
var _layer: Layer = null
var _pops: Array[CPUParticles2D] = []
var _next_pop: int = 0


func setup(p_sim: Sim, p_ppm: float) -> void:
	ppm = p_ppm
	z_index = 0
	_layer = Layer.new()
	_layer.fn = _draw_rings
	_layer.material = ArtLib.additive_unshaded()
	_layer.modulate = Color(BOOST, BOOST, BOOST, 1.0)
	_layer.z_index = 30
	add_child(_layer)
	lamp = PointLight2D.new()
	lamp.texture = RockView.light_texture(128, 0.0, 0.5, 0.35)
	lamp.color = WARM
	lamp.energy = 0.0
	lamp.height = 110.0
	lamp.range_item_cull_mask = RockView.LIGHT_MASK
	lamp.enabled = false
	add_child(lamp)
	for i: int in range(POPS):
		var p: CPUParticles2D = CrownDebris.make_chips(Vector2(1.0, 0.0), 0.0)
		p.amount = 26
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 0.9
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 330.0
		p.scale_amount_max = 2.8
		p.z_index = 31
		p.modulate = Color(1.7, 1.45, 1.05, 1.0)
		add_child(p)
		_pops.append(p)
	bind(p_sim)


## Follow a (new) sim from its current end; the room is rebuilt at the next frame.
func bind(p_sim: Sim) -> void:
	sim = p_sim
	_seen = sim.events.size() if sim != null else 0
	serial = -1
	_rings.clear()
	_clear_room()


# Pure helpers (tests read these) -----------------------------------------------------------------

## Cells of the structure's stamp that are old air now: interior cells (mark 2) whose material is air
## or a structure's air (a crate in it is rock to the view until it is cut). Row-major over cell_rect.
static func lit_mask(d: DrillSim) -> PackedByteArray:
	var cr: Rect2i = d.structures.cell_rect
	var out := PackedByteArray()
	out.resize(maxi(0, cr.size.x * cr.size.y))
	for r: int in range(cr.size.y):
		for c: int in range(cr.size.x):
			var i: int = (cr.position.y + r) * d.cols + cr.position.x + c
			var code: int = d.grid[i]
			if d.structure_marks[i] == StructureStamp.MARK_INTERIOR and (code == 0 or d.interior_of[code] == 1):
				out[r * cr.size.x + c] = 1
	return out


## The room's RGBA mask (a dark brown, alpha = the smoothed cells) and the glow's (warm, brightest in
## the middle of the room), both `w * CELL_PX` by `h * CELL_PX`, one cell of margin on each side.
## `tint` colours the glow and `room` the dark air (a structure's "light" block); `facets` scatters
## bright specks over the glow, for crystal walls.
static func room_images(lit: PackedByteArray, w: int, h: int, tint: Color = WARM, room_col: Color = ROOM, facets: bool = false) -> Array[Image]:
	var pw: int = (w + 2) * CELL_PX
	var ph: int = (h + 2) * CELL_PX
	var room := PackedByteArray()
	room.resize(pw * ph * 4)
	var glow := PackedByteArray()
	glow.resize(pw * ph * 4)
	var cxm: float = float(w + 2) * 0.5
	var cym: float = float(h + 2) * 0.5
	for y: int in range(ph):
		var v: float = (float(y) + 0.5) / float(CELL_PX) - 1.5  # One cell of margin: image cell 1 is mask cell 0.
		var j0: int = floori(v)
		var fy: float = v - float(j0)
		for x: int in range(pw):
			var u: float = (float(x) + 0.5) / float(CELL_PX) - 1.5
			var i0: int = floori(u)
			var fx: float = u - float(i0)
			var a: float = lerpf(_m(lit, w, h, i0, j0), _m(lit, w, h, i0 + 1, j0), fx)
			var b: float = lerpf(_m(lit, w, h, i0, j0 + 1), _m(lit, w, h, i0 + 1, j0 + 1), fx)
			var m: float = lerpf(a, b, fy)
			# Ragged like the rock's own cuts: the edge is nudged by a hash of the pixel.
			var n: float = RockView._hash(x >> 1, y >> 1, 5) - 0.5
			var alpha: float = clampf((m - 0.5 + n * 0.25) * 6.0 + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var o: int = (y * pw + x) * 4
			room[o] = room_col.r8
			room[o + 1] = room_col.g8
			room[o + 2] = room_col.b8
			room[o + 3] = roundi(alpha * 235.0)
			var dx: float = (float(x) / float(CELL_PX) - cxm) / maxf(1.0, float(w) * 0.5)
			var dy: float = (float(y) / float(CELL_PX) - cym) / maxf(1.0, float(h) * 0.5)
			var fall: float = clampf(1.0 - sqrt(dx * dx * 0.7 + dy * dy * 0.5), 0.0, 1.0)
			var g: float = alpha * (0.25 + 0.75 * fall) * 0.55
			if facets and RockView._hash(x, y, 11) > 0.975:
				g = minf(1.0, g * 2.0 + 0.06)
			glow[o] = roundi(tint.r * g * 255.0)
			glow[o + 1] = roundi(tint.g * g * 255.0)
			glow[o + 2] = roundi(tint.b * g * 255.0)
			glow[o + 3] = 255
	var out: Array[Image] = []
	out.append(Image.create_from_data(pw, ph, false, Image.FORMAT_RGBA8, room))
	out.append(Image.create_from_data(pw, ph, false, Image.FORMAT_RGBA8, glow))
	return out


static func _m(lit: PackedByteArray, w: int, h: int, c: int, r: int) -> float:
	if c < 0 or r < 0 or c >= w or r >= h:
		return 0.0
	return float(lit[r * w + c])


## The lamp's energy at `age` seconds after the break-in (-1: not entered): dim and sealed before, a
## flare at the break-in that settles brighter than it was.
static func lamp_at(entered_now: bool, age: float) -> float:
	if not entered_now:
		return LAMP_BEFORE
	var k: float = clampf(age / FLARE_S, 0.0, 1.0)
	return lerpf(LAMP_FLARE, LAMP_AFTER, 1.0 - pow(1.0 - k, 2.0))


# Following the sim -------------------------------------------------------------------------------

func _clear_room() -> void:
	if _room != null:
		_room.queue_free()
		_room = null
	if _glow != null:
		_glow.queue_free()
		_glow = null
	_tex_room = null
	_tex_glow = null
	lit_cells = 0
	entered = false
	_enter_age = 99.0
	glow_level = 0.0
	lamp_energy = 0.0
	if lamp != null:
		lamp.enabled = false


func _rebuild() -> void:
	var d: DrillSim = sim.drill
	serial = d.grid_serial
	_clear_room()
	var sr: DrillStructures = d.structures
	if not sr.has_structure():
		return
	_rect = sr.cell_rect
	_lit = lit_mask(d)
	var light: Dictionary = sr.def.get("light", {})
	tint = Color.html(str(light.get("color", WARM.to_html(false))))
	_room_col = Color.html(str(light.get("room", ROOM.to_html(false))))
	_facets = bool(light.get("facets", false))
	_glow_k = float(light.get("glow", 1.0))
	_lamp_k = float(light.get("lamp", 1.0))
	lamp.color = tint
	_apply_room()
	entered = sr.entered
	_enter_age = FLARE_S if entered else 99.0
	var m: Rect2 = sr.interior if sr.interior.size.x > 0.0 else sr.rect
	_center = m.get_center() * ppm
	var radius_m: float = maxf(m.size.x, m.size.y) * 0.5 + 3.5
	lamp.position = _center
	lamp.texture_scale = ppm * radius_m * 2.0 / 128.0 / 0.4
	lamp.enabled = true


## Build (or refresh) the room and glow sprites from _lit.
func _apply_room() -> void:
	lit_cells = 0
	for v: int in _lit:
		lit_cells += v
	var imgs: Array[Image] = room_images(_lit, _rect.size.x, _rect.size.y, tint, _room_col, _facets)
	var d: DrillSim = sim.drill
	var origin := (Vector2(_rect.position) - Vector2.ONE) * d.cell_m * ppm
	var k: float = ppm * d.cell_m / float(CELL_PX)
	if _room == null:
		_tex_room = ImageTexture.create_from_image(imgs[0])
		_tex_glow = ImageTexture.create_from_image(imgs[1])
		_room = Sprite2D.new()
		_room.texture = _tex_room
		_room.centered = false
		_room.scale = Vector2(k, k)
		_room.position = origin
		_room.z_index = -25
		_room.light_mask = RockView.LIGHT_MASK
		add_child(_room)
		_glow = Sprite2D.new()
		_glow.texture = _tex_glow
		_glow.centered = false
		_glow.scale = Vector2(k, k)
		_glow.position = origin
		_glow.z_index = -24
		_glow.light_mask = 0
		_glow.material = ArtLib.additive_unshaded()
		add_child(_glow)
	else:
		_tex_room.update(imgs[0])
		_tex_glow.update(imgs[1])


var frozen: bool = false: set = set_frozen  ## The visible pause: no time passes in this node's animations.


func set_frozen(on: bool) -> void:
	if frozen == on:
		return
	frozen = on
	WorldFreeze.apply(self, on)


func _process(delta: float) -> void:
	_update(WorldFreeze.dt(frozen, delta))
	if frozen:
		WorldFreeze.apply(self, true)


func _update(delta: float) -> void:
	_t += delta
	if sim == null:
		return
	var d: DrillSim = sim.drill
	if d.grid_serial != serial:
		_rebuild()
	var n: int = sim.events.size()
	if n < _seen:
		_seen = 0
	for i: int in range(_seen, n):
		_on_event(sim.events[i])
	_seen = n
	var live: bool = not _rings.is_empty()
	for r: Dictionary in _rings:
		r["age"] = float(r["age"]) + delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["age"]) < float(r["life"]))
	if live:
		_layer.queue_redraw()
	if _room == null:
		return
	_enter_age += delta
	_since_check += 1
	if _since_check >= 6:
		_since_check = 0
		var now: PackedByteArray = lit_mask(d)
		if now != _lit:
			_lit = now
			_apply_room()
	var flicker: float = 1.0 + 0.07 * sin(_t * 5.3) + 0.04 * sin(_t * 11.7)
	lamp_energy = lamp_at(entered, _enter_age) * flicker
	lamp.energy = lamp_energy * _lamp_k
	glow_level = lerpf(glow_level, GLOW_AFTER if entered else GLOW_BEFORE, 1.0 - exp(-3.0 * delta))
	var gl: float = glow_level * flicker * _glow_k
	_glow.modulate = Color(BOOST * gl, BOOST * gl, BOOST * gl, 1.0)


func _on_event(e: Dictionary) -> void:
	match str(e.get("kind", "")):
		"structure_entered":
			entered = true
			_enter_age = 0.0
			_rings.append({"pos": _center, "age": 0.0, "radius": 4.0 * ppm, "life": RING_S * 1.5})
		"loot":
			var at := Vector2(float(e.get("x_m", 0.0)), float(e.get("y_m", 0.0))) * ppm
			_rings.append({"pos": at, "age": 0.0, "radius": 1.3 * ppm, "life": RING_S})
			var p: CPUParticles2D = _pops[_next_pop % _pops.size()]
			_next_pop += 1
			p.position = at
			p.restart()
			p.emitting = true


func _draw_rings(n: Node2D) -> void:
	var k: float = 1.0 / maxf(0.2, get_viewport().get_canvas_transform().get_scale().x)
	for r: Dictionary in _rings:
		var t: float = clampf(float(r["age"]) / float(r["life"]), 0.0, 1.0)
		var a: float = 1.0 - t
		var pos: Vector2 = r["pos"]
		var rad: float = float(r["radius"])
		n.draw_circle(pos, rad * (0.25 + 0.45 * sqrt(t)), Color(1.0, 0.7, 0.32, 0.30 * a * a))
		n.draw_arc(pos, rad * (0.2 + 0.8 * t), 0.0, TAU, 40, Color(1.0, 0.85, 0.5, 0.85 * a), 4.0 * k)
