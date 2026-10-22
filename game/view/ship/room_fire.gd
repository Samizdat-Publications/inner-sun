class_name RoomFire
extends RefCounted
## Fire that reads as an emergency (critics 006 and 008): flame tongues that fill the floor, a fire
## light that flickers hard and reaches the room's art and crew, smoke that rises and collects in a
## haze under the ceiling (and a thinner one in the room above a hatch), and a scorch that stays on
## the floor and lower walls after the fire is out. Everything here is view memory: nothing feeds back
## into the sim. Per burning room: 50 core + 60 tongue + 16 ember + 48 smoke = 174 particles at most
## and one light. Idle rooms emit nothing and their nodes are hidden.
## Draw order (z): scorch -1 (above the painted room art, -5 to -2), haze 4, flames 5.

const CORE_N: int = 50
const TONGUE_N: int = 60
const EMBER_N: int = 16
const SMOKE_N: int = 48
const HAZE_COLS: int = 12
const SMOKE_RISE_PER_S: float = 0.4  ## Haze thickens by this much of its range per second.
const SMOKE_CLEAR_S: float = 8.0  ## Seconds for the haze to thin out once the fire is out.
const SCORCH_FADE_S: float = 30.0
const UPSTAIRS_SHARE: float = 0.45  ## The room above a hatch shows this share of the smoke below.
const FIRE_LIGHT_ENERGY: float = 3.8
const FLAME_LIFE: float = 0.75

## A small node that draws through a callback (one canvas item per room and layer).
class FireDraw extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var _ppm: float = 80.0
var _foot_lift: float = 14.0
var _rects: Array[Rect2] = []
var _lights: Array[PointLight2D] = []
var _core: Array[CPUParticles2D] = []
var _tongues: Array[CPUParticles2D] = []
var _embers: Array[CPUParticles2D] = []
var _smoke_p: Array[CPUParticles2D] = []
var _haze_nodes: Array[FireDraw] = []
var _scorch_nodes: Array[FireDraw] = []
var _fire: PackedFloat32Array = PackedFloat32Array()
var _burn_s: PackedFloat32Array = PackedFloat32Array()
var _smoke: PackedFloat32Array = PackedFloat32Array()
var _haze_in: PackedFloat32Array = PackedFloat32Array()  ## Haze borrowed from the room below.
var _scorch: PackedFloat32Array = PackedFloat32Array()
var _hatch_up: PackedInt32Array = PackedInt32Array()
var _hatch_down: PackedInt32Array = PackedInt32Array()
var _haze_pts: Array[PackedVector2Array] = []
var _haze_cols: Array[PackedColorArray] = []
var _time: float = 0.0


## Flame top above the floor (px) for a fire level: a lick along the floor at 0.1, about 60 percent
## of the room's height at 1.0.
static func flame_height_px(fire: float, room_h_px: float) -> float:
	return room_h_px * (0.08 + 0.52 * clampf(fire, 0.0, 1.0))


## The fraction of the room's width the flames spread across.
static func flame_span(fire: float) -> float:
	return clampf(0.22 + 0.74 * clampf(fire, 0.0, 1.0), 0.0, 0.96)


## Where the haze under the ceiling is heading (0 to 1): more with the fire and with how long the
## room has burned, none when it is out.
static func smoke_target(fire: float, burn_s: float) -> float:
	if fire <= 0.0:
		return 0.0
	var f: float = clampf(fire, 0.0, 1.0)
	return clampf(maxf(0.2, 0.7 * f + 0.3 * clampf(burn_s / 30.0, 0.0, 1.0)), 0.0, 1.0)


## One step of the haze toward its target: thickens fairly quickly, thins out over SMOKE_CLEAR_S.
static func smoke_step(current: float, target: float, dt: float) -> float:
	if target > current:
		return minf(target, current + SMOKE_RISE_PER_S * dt)
	return maxf(target, current - dt / SMOKE_CLEAR_S)


## One step of the scorch: it builds while the room burns and fades over SCORCH_FADE_S afterward.
static func scorch_step(current: float, fire: float, dt: float) -> float:
	if fire > 0.0:
		return minf(1.0, current + dt * (0.25 + 0.6 * clampf(fire, 0.0, 1.0)))
	return maxf(0.0, current - dt / SCORCH_FADE_S)


## How thick the haze is shown in a room: its own, or the share borrowed from the room below.
static func shown_haze(own: float, below: float) -> float:
	return maxf(own, UPSTAIRS_SHARE * below)


func build(parent: Node2D, ship: Ship, ppm: float, foot_lift: float, radial: Texture2D) -> void:
	_ppm = ppm
	_foot_lift = foot_lift
	var n: int = ship.rooms.size()
	_fire.resize(n)
	_burn_s.resize(n)
	_smoke.resize(n)
	_haze_in.resize(n)
	_scorch.resize(n)
	for l: Link in ship.links:
		if l.kind == Link.Kind.HATCH:
			_hatch_up.append(l.a)
			_hatch_down.append(l.b)
	for r: Room in ship.rooms:
		var rp := Rect2(r.rect.position * ppm, r.rect.size * ppm)
		_rects.append(rp)
		var ri: int = r.index
		var sc := FireDraw.new()
		sc.z_index = -1
		sc.material = _scorch_material()
		sc.fn = func(d: Node2D) -> void: _draw_scorch(d, ri)
		sc.visible = false
		parent.add_child(sc)
		_scorch_nodes.append(sc)
		var hz := FireDraw.new()
		hz.z_index = 4
		hz.material = ArtLib.unshaded()
		hz.fn = func(d: Node2D) -> void: _draw_haze(d, ri)
		hz.visible = false
		parent.add_child(hz)
		_haze_nodes.append(hz)
		var pts := PackedVector2Array()
		pts.resize((HAZE_COLS + 1) * 2)
		_haze_pts.append(pts)
		var cols := PackedColorArray()
		cols.resize((HAZE_COLS + 1) * 2)
		_haze_cols.append(cols)
		var base := Vector2(rp.get_center().x, rp.end.y - foot_lift)
		_smoke_p.append(_make_smoke(parent, base))
		_core.append(_make_core(parent, base))
		_tongues.append(_make_tongues(parent, base))
		_embers.append(_make_embers(parent, base))
		var lt := PointLight2D.new()
		lt.texture = radial
		lt.position = Vector2(rp.get_center().x, rp.end.y - ppm * 0.6)
		lt.color = Color(1.0, 0.48, 0.16)
		lt.energy = 0.0
		lt.enabled = false
		lt.height = 140.0
		lt.texture_scale = rp.size.x * 0.95 * 2.0 / float(radial.get_width())
		lt.shadow_enabled = true
		lt.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		lt.shadow_color = Color(0, 0, 0, 0.85)
		parent.add_child(lt)
		_lights.append(lt)


## Forget all view memory (a new run or segment rebind): no haze, no scorch, no burn timers.
func reset() -> void:
	for i: int in range(_fire.size()):
		_fire[i] = 0.0
		_burn_s[i] = 0.0
		_smoke[i] = 0.0
		_haze_in[i] = 0.0
		_scorch[i] = 0.0
		_lights[i].enabled = false
		for p: CPUParticles2D in [_core[i], _tongues[i], _embers[i], _smoke_p[i]]:
			p.restart()
			p.emitting = false
		_haze_nodes[i].visible = false
		_scorch_nodes[i].visible = false


func update(ship: Ship, t: float, dt: float) -> void:
	_time = t
	var n: int = mini(ship.rooms.size(), _fire.size())
	for i: int in range(n):
		var f: float = ship.rooms[i].fire
		_fire[i] = f
		_burn_s[i] = _burn_s[i] + dt if f > 0.0 else 0.0
		_smoke[i] = smoke_step(_smoke[i], smoke_target(f, _burn_s[i]), dt)
		_scorch[i] = scorch_step(_scorch[i], f, dt)
		_haze_in[i] = 0.0
	for k: int in range(_hatch_up.size()):
		var up: int = _hatch_up[k]
		var down: int = _hatch_down[k]
		if up < n and down < n:
			_haze_in[up] = maxf(_haze_in[up], _smoke[down])
	for i: int in range(n):
		_update_room(i, t)


func _update_room(i: int, t: float) -> void:
	var f: float = _fire[i]
	var rp: Rect2 = _rects[i]
	var burning: bool = f > 0.02
	var floor_pt := Vector2(rp.get_center().x, rp.end.y - _foot_lift)
	var span_px: float = rp.size.x * flame_span(f)
	var h: float = flame_height_px(f, rp.size.y)
	var lt: PointLight2D = _lights[i]
	lt.enabled = f > 0.0
	if f > 0.0:
		var fl: float = 0.7 + 0.2 * sin(t * 23.0 + float(i) * 1.7) + 0.15 * sin(t * 41.0) + 0.12 * sin(t * 67.0 + float(i))
		lt.energy = FIRE_LIGHT_ENERGY * f * maxf(fl, 0.2)
		lt.texture_scale = rp.size.x * (0.8 + 0.55 * f) * 2.0 / 256.0
		lt.position = Vector2(rp.get_center().x + 7.0 * f * sin(t * 9.0 + float(i)), rp.end.y - _ppm * 0.6 - h * 0.35)
	var core: CPUParticles2D = _core[i]
	core.emitting = burning
	var tg: CPUParticles2D = _tongues[i]
	tg.emitting = burning
	var em: CPUParticles2D = _embers[i]
	em.emitting = f > 0.15
	var sm: CPUParticles2D = _smoke_p[i]
	sm.emitting = f > 0.05
	if burning:
		var ext := Vector2(span_px * 0.5, 3.0)
		var core_px: float = clampf(rp.size.y * (0.12 + 0.16 * f), 20.0, 110.0)
		core.position = floor_pt - Vector2(0.0, core_px * 0.4)  # Sprites are centred: keep them above the floor.
		core.emission_rect_extents = ext
		core.scale_amount_min = core_px * 0.7 / 48.0
		core.scale_amount_max = core_px * 1.2 / 48.0
		core.speed_scale = 0.7 + f
		var tongue_px: float = clampf(h * 0.8, 24.0, 190.0)
		tg.position = floor_pt - Vector2(0.0, tongue_px * 0.42)
		tg.emission_rect_extents = ext
		tg.scale_amount_min = tongue_px * 0.6 / 64.0
		tg.scale_amount_max = tongue_px / 64.0
		var vmax: float = maxf(0.0, (h - tongue_px * 0.5) / FLAME_LIFE)
		tg.initial_velocity_max = vmax
		tg.initial_velocity_min = vmax * 0.45
		tg.speed_scale = 0.8 + 0.6 * f
		em.position = floor_pt
		em.emission_rect_extents = ext
		em.initial_velocity_max = 60.0 + h * 1.4
		sm.position = floor_pt + Vector2(0.0, -h * 0.5)
		sm.emission_rect_extents = Vector2(span_px * 0.4, 4.0)
		sm.initial_velocity_max = 30.0 + rp.size.y * 0.25
		sm.initial_velocity_min = 12.0
	var haze: float = shown_haze(_smoke[i], _haze_in[i])
	var hv: bool = haze > 0.01
	_haze_nodes[i].visible = hv
	if hv:
		_haze_nodes[i].queue_redraw()
	var sv: bool = _scorch[i] > 0.01
	_scorch_nodes[i].visible = sv
	if sv:
		_scorch_nodes[i].queue_redraw()


func _draw_haze(d: Node2D, i: int) -> void:
	var rp: Rect2 = _rects[i]
	var amount: float = shown_haze(_smoke[i], _haze_in[i])
	if amount <= 0.01:
		return
	var depth: float = rp.size.y * (0.2 + 0.7 * amount)
	var pts: PackedVector2Array = _haze_pts[i]
	var cols: PackedColorArray = _haze_cols[i]
	var top_a: float = clampf(1.9 * amount, 0.0, 0.9)
	for k: int in range(HAZE_COLS + 1):
		var x: float = rp.position.x + rp.size.x * float(k) / float(HAZE_COLS)
		var roll: float = 1.0 + 0.16 * sin(_time * 0.7 + float(k) * 1.3 + float(i)) + 0.1 * sin(_time * 1.3 - float(k) * 2.1)
		pts[k] = Vector2(x, rp.position.y)
		cols[k] = Color(0.34, 0.32, 0.3, top_a)  # Grey and milky: near-black vanished into the dark rooms.
		var back: int = (HAZE_COLS + 1) * 2 - 1 - k
		pts[back] = Vector2(x, rp.position.y + depth * roll)
		cols[back] = Color(0.3, 0.28, 0.26, 0.0)
	d.draw_polygon(pts, cols)


func _draw_scorch(d: Node2D, i: int) -> void:
	var rp: Rect2 = _rects[i]
	var s: float = _scorch[i]
	if s <= 0.01:
		return
	# Multiply blend (D059): each colour darkens what is under it; white leaves it as it was.
	var up: float = rp.size.y * 0.42 * s
	var dark: Color = soot(0.97 * s)
	var clear := Color.WHITE
	d.draw_polygon(
		PackedVector2Array([Vector2(rp.position.x, rp.end.y), Vector2(rp.end.x, rp.end.y), Vector2(rp.end.x, rp.end.y - up), Vector2(rp.position.x, rp.end.y - up)]),
		PackedColorArray([dark, dark, clear, clear]))
	var w: float = rp.size.x * 0.16 * (0.4 + 0.6 * s)
	var wall_up: float = rp.size.y * 0.7 * s
	d.draw_polygon(
		PackedVector2Array([Vector2(rp.position.x, rp.end.y), Vector2(rp.position.x + w, rp.end.y), Vector2(rp.position.x, rp.end.y - wall_up)]),
		PackedColorArray([dark, clear, clear]))
	d.draw_polygon(
		PackedVector2Array([Vector2(rp.end.x, rp.end.y), Vector2(rp.end.x - w, rp.end.y), Vector2(rp.end.x, rp.end.y - wall_up)]),
		PackedColorArray([dark, clear, clear]))
	# Soot streaks climbing the walls and a few blotches on the floor, fixed per room.
	for k: int in range(5):
		var fx: float = fposmod(float(k) * 0.37 + float(i) * 0.21, 1.0)
		var x: float = rp.position.x + rp.size.x * fx
		d.draw_circle(Vector2(x, rp.end.y - 6.0), (10.0 + 14.0 * fposmod(fx * 7.0, 1.0)) * s, soot(0.4 * s))


## The multiply colour for soot of strength a (0 leaves the art as it is, 1 is nearly black).
static func soot(a: float) -> Color:
	var c: Color = Color.WHITE.lerp(Color(0.02, 0.015, 0.012), clampf(a, 0.0, 1.0))
	c.a = 1.0
	return c


static func _scorch_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	return m


func _base(parent: Node2D, tex: Texture2D, amount: int, life: float, z: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(20.0, 3.0)
	p.direction = Vector2(0, -1)
	p.z_index = z
	parent.add_child(p)
	return p


func _fade_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.6))
	c.add_point(Vector2(0.2, 1.0))
	c.add_point(Vector2(1.0, 0.1))
	return c


func _make_core(parent: Node2D, at: Vector2) -> CPUParticles2D:
	var p: CPUParticles2D = _base(parent, ArtLib.flame_blob(), CORE_N, 0.55, 5)
	p.material = ArtLib.additive_unshaded()
	p.position = at
	p.spread = 25.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 28.0
	p.scale_amount_curve = _fade_curve()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(2.2, 1.7, 0.8, 0.0))
	ramp.set_color(1, Color(0.9, 0.12, 0.03, 0.0))
	ramp.add_point(0.15, Color(1.8, 1.2, 0.4, 0.55))
	ramp.add_point(0.6, Color(1.5, 0.45, 0.08, 0.4))
	p.color_ramp = ramp
	return p


func _make_tongues(parent: Node2D, at: Vector2) -> CPUParticles2D:
	var p: CPUParticles2D = _base(parent, ArtLib.flame_tongue(), TONGUE_N, FLAME_LIFE, 5)
	p.material = ArtLib.additive_unshaded()
	p.position = at
	p.spread = 9.0
	p.gravity = Vector2(0, -40)
	p.angle_min = -12.0
	p.angle_max = 12.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 90.0
	p.scale_amount_curve = _fade_curve()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.6, 1.3, 0.7, 0.0))
	ramp.set_color(1, Color(0.7, 0.08, 0.02, 0.0))
	ramp.add_point(0.1, Color(1.5, 0.95, 0.3, 0.9))
	ramp.add_point(0.6, Color(1.3, 0.4, 0.07, 0.7))
	p.color_ramp = ramp
	return p


func _make_embers(parent: Node2D, at: Vector2) -> CPUParticles2D:
	var p: CPUParticles2D = _base(parent, ArtLib.flame_blob(), EMBER_N, 1.7, 5)
	p.material = ArtLib.additive_unshaded()
	p.position = at
	p.spread = 35.0
	p.gravity = Vector2(0, -30)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.16
	var ramp := Gradient.new()
	ramp.set_color(0, Color(3.0, 1.9, 0.6, 1.0))
	ramp.set_color(1, Color(1.0, 0.15, 0.02, 0.0))
	p.color_ramp = ramp
	return p


func _make_smoke(parent: Node2D, at: Vector2) -> CPUParticles2D:
	var p: CPUParticles2D = _base(parent, ArtLib.smoke_puff(), SMOKE_N, 3.2, 4)
	p.material = ArtLib.unshaded()
	p.modulate = Color(1.8, 1.8, 1.8, 1.0)
	p.position = at
	p.spread = 22.0
	p.gravity = Vector2(0, -8)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 50.0
	p.angle_min = -40.0
	p.angle_max = 40.0
	p.angular_velocity_min = -12.0
	p.angular_velocity_max = 12.0
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.5
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.7))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.1, 0.09, 0.08, 0.0))
	ramp.set_color(1, Color(0.05, 0.045, 0.04, 0.0))
	ramp.add_point(0.2, Color(0.34, 0.31, 0.28, 0.6))
	ramp.add_point(0.7, Color(0.22, 0.2, 0.18, 0.5))
	p.color_ramp = ramp
	return p
