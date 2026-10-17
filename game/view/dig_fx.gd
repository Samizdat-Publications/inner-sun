class_name DigFx
extends Node2D
## The dig verbs' effects in the world, in segment space (this node sits at the origin of the rock, like
## RockView). It only READS the sim: it follows `sim.events` by index (like DigLog and the audio
## director) and the drill's state, and never writes anything.
##  - the blast aim: while the BlastCard is armed, the range ring around the tower and a target circle
##    at the mouse (green when the shot is allowed, red when out of range);
##  - the blast: the charge flies from the crown (a bright dot with a trail), then a flash, a hot light
##    that lights the rock, a burst of rock chips and dust, and a camera kick;
##  - rockfall: on the warning, dust sifts and cracks creep across the roof; on the impact, rock falls
##    onto the top deck with a kick (a smaller one if bracing held);
##  - side cutting: sparks and chips along the leading side of the hull when the heading is past 30
##    degrees.
## `shake_offset()` is what Main adds to the camera. The draw layer is unshaded and additive, so colors
## are the colors on screen after the boost (see HANDOFF, glow).

const KICK_BLAST: float = 20.0
const KICK_FALL: float = 15.0
const KICK_HELD: float = 6.0
const KICK_DECAY: float = 70.0  ## Pixels per second.
const SIDE_CUT_DEG: float = 30.0
const FLASH_S: float = 0.55
const LIGHT_S: float = 0.6
const BOOST: float = 1.9

## One additive, unshaded drawing node (kept small: lights meet it only through its rectangle).
class Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var sim: Sim = null
var blast: BlastCard = null
var ppm: float = 80.0
var kick: float = 0.0
var aim_override: Vector2 = Vector2(-1.0, -1.0)  ## Dev only (--aim): use this point instead of the mouse.
var _seen: int = 0
var _t: float = 0.0
var _layer: Layer = null
var _shots: Array[Dictionary] = []  ## {from, to, age, fuse}
var _flashes: Array[Dictionary] = []  ## {pos, age}
var _light: PointLight2D = null
var _light_age: float = 99.0
var _debris: CPUParticles2D = null
var _dust: CPUParticles2D = null
var _warn_dust: CPUParticles2D = null
var _fall: CPUParticles2D = null
var _side_sparks: CPUParticles2D = null
var _side_chips: CPUParticles2D = null
var _crack_age: float = 99.0
var _was_live: bool = false


func setup(p_sim: Sim, p_blast: BlastCard, p_ppm: float) -> void:
	ppm = p_ppm
	z_index = 30
	_layer = Layer.new()
	_layer.fn = _draw_layer
	_layer.material = ArtLib.additive_unshaded()
	_layer.modulate = Color(BOOST, BOOST, BOOST, 1.0)
	add_child(_layer)
	_build_particles()
	_light = PointLight2D.new()
	_light.texture = RockView.light_texture(128, 0.0, 0.5, 0.35)
	_light.texture_scale = ppm * 9.0 * 2.0 / 128.0 / 0.4
	_light.color = Color(1.0, 0.62, 0.28)
	_light.energy = 0.0
	_light.height = 140.0
	_light.range_item_cull_mask = 2
	_light.enabled = false
	add_child(_light)
	bind(p_sim, p_blast)


func bind(p_sim: Sim, p_blast: BlastCard) -> void:
	sim = p_sim
	blast = p_blast
	_seen = sim.events.size() if sim != null else 0
	_shots.clear()
	_flashes.clear()
	kick = 0.0
	_crack_age = 99.0


## The camera offset for the current kick (Main adds it to the camera).
func shake_offset() -> Vector2:
	if kick <= 0.05:
		return Vector2.ZERO
	return Vector2(sin(_t * 93.0), cos(_t * 77.0)) * kick


func _build_particles() -> void:
	var hot := Gradient.new()
	hot.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
	hot.set_color(1, Color(0.5, 0.15, 0.04, 0.0))
	_debris = CrownDebris.make_chips(Vector2(1.0, 0.0), 0.0)
	_debris.amount = 70
	_debris.one_shot = true
	_debris.explosiveness = 1.0
	_debris.lifetime = 1.1
	_debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	_debris.direction = Vector2(0, -1)
	_debris.spread = 180.0
	_debris.initial_velocity_min = 220.0
	_debris.initial_velocity_max = 620.0
	_debris.scale_amount_max = 3.2
	_debris.z_index = 0
	add_child(_debris)
	var puff := Gradient.new()
	puff.set_color(0, Color(0.5, 0.45, 0.4, 0.0))
	puff.set_color(1, Color(0.35, 0.31, 0.27, 0.0))
	puff.add_point(0.2, Color(0.5, 0.45, 0.4, 0.4))
	_dust = _puff(puff, 40, 1.8, 90.0, 2.5, 6.0)
	_dust.one_shot = true
	_dust.explosiveness = 0.9
	_dust.spread = 180.0
	_dust.direction = Vector2(0, -1)
	_dust.gravity = Vector2(0, -20)
	add_child(_dust)
	_warn_dust = _puff(puff, 30, 1.6, 40.0, 1.2, 3.0)
	_warn_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_warn_dust.direction = Vector2(0, 1)
	_warn_dust.spread = 25.0
	_warn_dust.gravity = Vector2(0, 90)
	add_child(_warn_dust)
	_fall = CrownDebris.make_chips(Vector2(1.0, 0.0), 0.0)
	_fall.amount = 56
	_fall.one_shot = true
	_fall.explosiveness = 0.55
	_fall.lifetime = 0.9
	_fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fall.direction = Vector2(0, 1)
	_fall.spread = 22.0
	_fall.gravity = Vector2(0, 1500)
	_fall.initial_velocity_min = 160.0
	_fall.initial_velocity_max = 420.0
	_fall.scale_amount_min = 2.4
	_fall.scale_amount_max = 6.0
	_fall.z_index = 0
	add_child(_fall)
	_side_sparks = CrownDebris.make_streaks(Vector2(1.0, 0.0), 0.0)
	_side_sparks.amount = 80
	_side_sparks.lifetime = 0.55
	_side_sparks.scale_amount_min = 0.9
	_side_sparks.scale_amount_max = 2.0
	_side_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_side_sparks.z_index = 0
	add_child(_side_sparks)
	_side_chips = CrownDebris.make_chips(Vector2(1.0, 0.0), 0.0)
	_side_chips.amount = 36
	_side_chips.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_side_chips.z_index = 0
	add_child(_side_chips)


static func _puff(ramp: Gradient, amount: int, life: float, vel: float, scale_min: float, scale_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = ShipView.radial_texture(48)
	p.material = ArtLib.unshaded()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color_ramp = ramp
	p.modulate = Color(1.7, 1.6, 1.5, 1.0)  # The CanvasModulate dims unshaded drawings: lift them back.
	return p


func _process(delta: float) -> void:
	_t += delta
	kick = move_toward(kick, 0.0, KICK_DECAY * delta)
	if sim == null:
		return
	var n: int = sim.events.size()
	if n < _seen:
		_seen = 0
	for i: int in range(_seen, n):
		_on_event(sim.events[i])
	_seen = n
	var d: DrillSim = sim.drill
	_crack_age = _crack_age + delta
	_update_light(delta)
	_update_side(d)
	_update_warn(d)
	for s: Dictionary in _shots:
		s["age"] = float(s["age"]) + delta
	for f: Dictionary in _flashes:
		f["age"] = float(f["age"]) + delta
	_shots = _shots.filter(func(s: Dictionary) -> bool: return float(s["age"]) < float(s["fuse"]) + 0.05)
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return float(f["age"]) < FLASH_S)
	var live: bool = (blast != null and blast.armed) or not _shots.is_empty() or not _flashes.is_empty() 		or d.verbs.rockfall_ticks > 0 or _crack_age < 1.5
	if live or _was_live:
		_layer.queue_redraw()
	_was_live = live


func _on_event(e: Dictionary) -> void:
	match str(e.get("kind", "")):
		"blast_fired":
			var from := Vector2(float(e["from_x_m"]), float(e["from_y_m"])) * ppm
			var to := Vector2(float(e["x_m"]), float(e["y_m"])) * ppm
			_shots.append({"from": from, "to": to, "age": 0.0, "fuse": maxf(0.05, float(e.get("fuse_s", 0.6)))})
		"blast":
			var at := Vector2(float(e["x_m"]), float(e["y_m"])) * ppm
			_flashes.append({"pos": at, "age": 0.0})
			_light.position = at
			_light_age = 0.0
			_debris.position = at
			_debris.restart()
			_dust.position = at
			_dust.restart()
			kick = maxf(kick, KICK_BLAST)
		"rockfall_warn":
			_crack_age = 0.0
		"rockfall":
			_place_fall()
			_fall.restart()
			_fall.emitting = true
			kick = maxf(kick, KICK_HELD if bool(e.get("absorbed", false)) else KICK_FALL)
			_crack_age = 99.0


## Rock falling onto the roof: a band across the top deck, starting a few meters up.
func _place_fall() -> void:
	var d: DrillSim = sim.drill
	_fall.position = Vector2((d.ship_pos.x + d.ship_size.x * 0.5) * ppm, (d.ship_pos.y - 1.1) * ppm)
	_fall.emission_rect_extents = Vector2(d.ship_size.x * 0.46 * ppm, 6.0)


func _update_light(delta: float) -> void:
	if _light_age >= LIGHT_S:
		_light.enabled = false
		return
	_light_age += delta
	_light.enabled = true
	var k: float = clampf(1.0 - _light_age / LIGHT_S, 0.0, 1.0)
	_light.energy = 5.0 * k * k


## Dust sifts from the roof from the warning until the impact.
func _update_warn(d: DrillSim) -> void:
	var on: bool = d.active and d.verbs.rockfall_ticks > 0
	if on:
		_place_warn(d)
	_warn_dust.emitting = on


func _place_warn(d: DrillSim) -> void:
	_warn_dust.position = Vector2((d.ship_pos.x + d.ship_size.x * 0.5) * ppm, (d.ship_pos.y - 0.6) * ppm)
	_warn_dust.emission_rect_extents = Vector2(d.ship_size.x * 0.5 * ppm, 4.0)


## Sparks and chips along the leading side of the hull when cutting sideways.
func _update_side(d: DrillSim) -> void:
	var on: bool = d.active and d.cutting and d.speed_m_s > 0.02 and absf(d.heading_deg) > SIDE_CUT_DEG
	_side_sparks.emitting = on
	_side_chips.emitting = on
	if not on:
		return
	var dir: float = signf(d.heading_deg)
	var x: float = (d.ship_pos.x + (d.ship_size.x if dir > 0.0 else 0.0)) * ppm
	var y: float = (d.ship_pos.y + d.ship_size.y * 0.62) * ppm
	var ext := Vector2(3.0, d.ship_size.y * 0.36 * ppm)
	for p: CPUParticles2D in [_side_sparks, _side_chips]:
		p.position = Vector2(x, y)
		p.emission_rect_extents = ext
		p.direction = Vector2(dir * 0.9, -0.35)
		p.spread = 55.0
		p.gravity = Vector2(0, 1100)
	_side_sparks.speed_scale = 0.8 + 0.2 * clampf(d.speed_m_s, 0.0, 2.0)


# Drawing ---------------------------------------------------------------------------------------

func _zoom() -> float:
	return maxf(0.2, get_viewport().get_canvas_transform().get_scale().x)


func _draw_layer(n: Node2D) -> void:
	if sim == null:
		return
	var d: DrillSim = sim.drill
	var k: float = 1.0 / _zoom()
	if blast != null and blast.armed and d.active:
		_draw_aim(n, d, k)
	for s: Dictionary in _shots:
		_draw_shot(n, s, k)
	for f: Dictionary in _flashes:
		_draw_flash(n, f, k)
	if d.active and (d.verbs.rockfall_ticks > 0 or _crack_age < 1.5):
		_draw_cracks(n, d, k)


## The aim: a dashed ring of the blast's range around the tower and a circle where the click would land.
func _draw_aim(n: Node2D, d: DrillSim, k: float) -> void:
	var centre := Vector2(d.ship_pos.x + d.ship_size.x * 0.5, d.ship_pos.y + d.ship_size.y * 0.5) * ppm
	var range_m: float = sim.db.tune("drill.blast_range_m")
	var pulse: float = 0.65 + 0.25 * sin(_t * 4.0)
	var col := Color(1.0, 0.72, 0.30, pulse)
	var seg: int = 40
	for i: int in range(seg):
		if i % 2 == 1:
			continue
		var a0: float = float(i) / float(seg) * TAU
		var a1: float = float(i + 1) / float(seg) * TAU
		n.draw_arc(centre, range_m * ppm, a0, a1, 6, col, 5.0 * k)
	var m: Vector2 = _aim_point()
	if m.x < 0.0:
		return
	var ok: bool = d.verbs.aim_ok(d, m).is_empty()
	var tc := Color(0.5, 1.0, 0.6, 0.9) if ok else Color(1.0, 0.35, 0.25, 0.9)
	var rad: float = sim.db.tune("drill.blast_radius_m") * ppm
	n.draw_arc(m * ppm, rad, 0.0, TAU, 40, tc, 3.0 * k)
	n.draw_circle(m * ppm, rad, Color(tc.r, tc.g, tc.b, 0.10))
	n.draw_line(m * ppm - Vector2(10, 0) * k, m * ppm + Vector2(10, 0) * k, tc, 2.0 * k)
	n.draw_line(m * ppm - Vector2(0, 10) * k, m * ppm + Vector2(0, 10) * k, tc, 2.0 * k)
	if ok:
		n.draw_dashed_line(Vector2(d.ship_pos.x + d.ship_size.x * 0.5, d.ship_pos.y + d.ship_size.y) * ppm, m * ppm, Color(tc, 0.35), 2.0 * k, 10.0 * k)


## The mouse in segment meters (or the dev override), or (-1, -1) when the mouse is not over the world.
func _aim_point() -> Vector2:
	if aim_override.x >= 0.0:
		return aim_override
	var vp: Viewport = get_viewport()
	var mp: Vector2 = vp.get_mouse_position()
	if not RunScreen.WORLD_RECT.has_point(mp):
		return Vector2(-1.0, -1.0)
	return (get_global_transform_with_canvas().affine_inverse() * mp) / ppm


func _draw_shot(n: Node2D, s: Dictionary, k: float) -> void:
	var t: float = clampf(float(s["age"]) / float(s["fuse"]), 0.0, 1.0)
	var from: Vector2 = s["from"]
	var to: Vector2 = s["to"]
	var head: Vector2 = from.lerp(to, t)
	var tail: Vector2 = from.lerp(to, maxf(0.0, t - 0.35))
	n.draw_line(tail, head, Color(1.0, 0.6, 0.2, 0.55), 6.0 * k)
	n.draw_line(tail.lerp(head, 0.5), head, Color(1.0, 0.9, 0.6, 0.9), 3.0 * k)
	n.draw_circle(head, 7.0 * k, Color(1.0, 0.8, 0.4, 0.9))
	n.draw_circle(head, 3.5 * k, Color(1.0, 1.0, 0.9, 1.0))


func _draw_flash(n: Node2D, f: Dictionary, k: float) -> void:
	var t: float = clampf(float(f["age"]) / FLASH_S, 0.0, 1.0)
	var pos: Vector2 = f["pos"]
	var radius: float = sim.db.tune("drill.blast_radius_m") * ppm
	var a: float = 1.0 - t
	n.draw_circle(pos, radius * (0.5 + 1.1 * sqrt(t)), Color(1.0, 0.45, 0.12, 0.35 * a * a))
	n.draw_circle(pos, radius * (0.3 + 0.7 * t), Color(1.0, 0.75, 0.35, 0.6 * a))
	n.draw_circle(pos, radius * 0.5 * (1.0 - t), Color(1.0, 1.0, 0.85, 0.95 * a))
	n.draw_arc(pos, radius * (0.4 + 1.6 * t), 0.0, TAU, 48, Color(1.0, 0.85, 0.5, 0.8 * a), 4.0 * k)


## Cracks creeping across the roof of the top deck while the rockfall is on its way.
func _draw_cracks(n: Node2D, d: DrillSim, k: float) -> void:
	var total: float = maxf(0.2, sim.db.tune("drill.rockfall_warn_s"))
	var grow: float = 1.0
	if d.verbs.rockfall_ticks > 0:
		grow = clampf(1.0 - float(d.verbs.rockfall_ticks) / Sim.TICK_HZ / total, 0.0, 1.0)
	else:
		grow = clampf(1.0 - _crack_age / 1.5, 0.0, 1.0)
	var x0: float = d.ship_pos.x * ppm
	var w: float = d.ship_size.x * ppm
	var y: float = d.ship_pos.y * ppm - 14.0 * k
	var col := Color(0.95, 0.78, 0.45, 0.35 + 0.5 * grow)
	for i: int in range(5):
		var bx: float = x0 + w * (0.12 + 0.19 * float(i))
		var pts := PackedVector2Array()
		var len_px: float = (26.0 + 22.0 * float((i * 7) % 3)) * (0.3 + 0.7 * grow)
		for j: int in range(5):
			var jx: float = (1.0 if (i + j) % 2 == 0 else -1.0) * (5.0 + float(j) * 2.0)
			pts.append(Vector2(bx + jx * k, y - len_px * k * (1.0 - float(j) / 4.0) + 3.0 * k))
		n.draw_polyline(pts, col, 2.5 * k)
