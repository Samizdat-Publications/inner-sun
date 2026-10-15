class_name ShipView
extends Node2D
## Builds and updates the cutaway from the sim's state: rock around the hull, back walls, water,
## fire, crew, ladders and the lights that make it read. Placeholder art in M0.
## Godot lets one canvas item take only about 15 lights, so everything is split into small per-room,
## per-crew and per-chunk nodes (each only meets nearby lights) and idle lights are disabled, not
## dimmed. Ship space is meters with y down; this node's origin is the ship's top-left corner.

const WALL_PX: float = 8.0
const ROCK_CHUNK: int = 512
const CREW_COLORS: Array[Color] = [Color(0.95, 0.52, 0.16), Color(0.2, 0.7, 0.72), Color(0.9, 0.78, 0.25)]


## A node that draws through a callback, so each room or crew member is its own small canvas item.
class FnDraw extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var run: ScenarioRun
var ppm: float = 80.0
var _font: Font
var _radial: GradientTexture2D
var _lamps: Array[PointLight2D] = []
var _alarms: Array[PointLight2D] = []
var _fire_lights: Array[PointLight2D] = []
var _flames: Array[CPUParticles2D] = []
var _crew_nodes: Array[FnDraw] = []
var _crew_lights: Array[PointLight2D] = []
var _redraw: Array[FnDraw] = []
var _drill_light: PointLight2D
var _drill_poly: Polygon2D
var _time: float = 0.0
## Drilling mode: the node rides the sim's ship_pos in segment space, over a RockView.
var _drill: DrillSim
var _m0_rock: Array[Node] = []
var _floods: Array[PointLight2D] = []
var _crown: Node2D
var _crown_glow: Array[Polygon2D] = []
var _crown_light: PointLight2D
var _sparks: CPUParticles2D
var _dust: CPUParticles2D


func setup(p_run: ScenarioRun, p_ppm: float) -> void:
	run = p_run
	ppm = p_ppm
	_font = ThemeDB.fallback_font
	_radial = ShipView.radial_texture(256)
	_build_rock()
	_build_rooms()
	_build_occluders()
	_build_lights()
	_build_flames()
	_build_drill()
	_build_crown()
	_build_props()
	_build_crew()


func rebind(p_run: ScenarioRun) -> void:
	run = p_run


func ship_size_m() -> Vector2:
	var end := Vector2.ZERO
	for r: Room in run.sim.ship.rooms:
		end = end.max(r.rect.end)
	return end


func center_px() -> Vector2:
	var s: Vector2 = ship_size_m()
	return Vector2(s.x * 0.5, s.y * 0.5 + 0.8) * ppm


func room_rect_px(r: Room) -> Rect2:
	return Rect2(r.rect.position * ppm, r.rect.size * ppm)


static func canvas_tex(albedo: String, normal: String) -> Texture2D:
	if not ResourceLoader.exists(albedo):
		return null
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load(albedo) as Texture2D
	if ResourceLoader.exists(normal):
		ct.normal_texture = load(normal) as Texture2D
	ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return ct


static func radial_texture(size: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


func _fn(z: int, fn: Callable, unshaded: bool = false) -> FnDraw:
	var n := FnDraw.new()
	n.fn = fn
	n.z_index = z
	if unshaded:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		n.material = m
	add_child(n)
	_redraw.append(n)
	return n


func _light(at: Vector2, color: Color, energy: float, radius_px: float, shadows: bool, height: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _radial
	l.texture_scale = radius_px * 2.0 / float(_radial.width)
	l.position = at
	l.color = color
	l.energy = energy
	l.height = height
	l.shadow_enabled = shadows
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_color = Color(0, 0, 0, 0.85)
	add_child(l)
	return l


func _build_rock() -> void:
	var tex: Texture2D = ShipView.canvas_tex("res://assets/test/rock_albedo.png", "res://assets/test/rock_normal.png")
	if tex == null:
		return
	var origin: Vector2 = (center_px() - Vector2(2048, 1536)).snapped(Vector2(ROCK_CHUNK, ROCK_CHUNK))
	for gy: int in range(6):
		for gx: int in range(8):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			var at := origin + Vector2(gx * ROCK_CHUNK, gy * ROCK_CHUNK)
			s.region_rect = Rect2(at, Vector2(ROCK_CHUNK, ROCK_CHUNK))
			s.position = at
			s.z_index = -10
			add_child(s)
			_m0_rock.append(s)
	var size: Vector2 = ship_size_m() * ppm
	_m0_rock.append(_light(Vector2(-ppm * 0.6, size.y * 0.3), Color(0.55, 0.68, 0.85), 1.5, ppm * 8.0, true, 260.0))
	_m0_rock.append(_light(Vector2(size.x + ppm * 0.6, size.y * 0.3), Color(0.55, 0.68, 0.85), 1.5, ppm * 8.0, true, 260.0))


func _build_rooms() -> void:
	var wall: Texture2D = ShipView.canvas_tex("res://assets/test/wall_albedo.png", "res://assets/test/wall_normal.png")
	var ship: Ship = run.sim.ship
	for r: Room in ship.rooms:
		var rp: Rect2 = room_rect_px(r)
		if wall != null:
			var back := Sprite2D.new()
			back.texture = wall
			back.centered = false
			back.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			back.region_enabled = true
			back.region_rect = Rect2(Vector2.ZERO, rp.size)
			back.position = rp.position
			back.self_modulate = Color(0.8, 0.8, 0.84)
			back.z_index = -5
			add_child(back)
		var ri: int = r.index
		_fn(0, func(n: Node2D) -> void: _draw_heat(n, ri))
		_fn(5, func(n: Node2D) -> void: _draw_water(n, ri))
		_fn(3, func(n: Node2D) -> void: _draw_frame(n, ri))
		_fn(10, func(n: Node2D) -> void: _draw_label(n, ri), true)
	for l: Link in ship.links:
		if l.kind == Link.Kind.HATCH:
			var li: int = l.index
			_fn(1, func(n: Node2D) -> void: _draw_ladder(n, li))
	var size: Vector2 = ship_size_m() * ppm
	_fn(4, func(n: Node2D) -> void: n.draw_rect(Rect2(Vector2(-WALL_PX, -WALL_PX), size + Vector2(WALL_PX * 2.0, WALL_PX * 2.0)), Color(0.09, 0.09, 0.1), false, WALL_PX * 1.5))


func _build_occluders() -> void:
	var ship: Ship = run.sim.ship
	for r: Room in ship.rooms:
		var rp: Rect2 = room_rect_px(r)
		var top_gaps: Array[Vector2] = []
		var floor_gaps: Array[Vector2] = []
		var left_gaps: Array[Vector2] = []
		var right_gaps: Array[Vector2] = []
		for l: Link in ship.links:
			if l.kind == Link.Kind.HATCH:
				var g := Vector2(l.x - l.span_m * 0.5, l.x + l.span_m * 0.5) * ppm
				if l.a == r.index:
					floor_gaps.append(g)
				elif l.b == r.index:
					top_gaps.append(g)
			elif l.a == r.index or l.b == r.index:
				var door := Vector2(r.floor_y() - l.height_m, r.floor_y()) * ppm
				if absf(l.x - r.rect.position.x) < 0.01:
					left_gaps.append(door)
				else:
					right_gaps.append(door)
		_wall_segments(rp.position, Vector2(rp.end.x, rp.position.y), top_gaps, true)
		_wall_segments(Vector2(rp.position.x, rp.end.y), rp.end, floor_gaps, true)
		_wall_segments(rp.position, Vector2(rp.position.x, rp.end.y), left_gaps, false)
		_wall_segments(Vector2(rp.end.x, rp.position.y), rp.end, right_gaps, false)


func _wall_segments(a: Vector2, b: Vector2, gaps: Array[Vector2], horizontal: bool) -> void:
	var stop: float = b.x if horizontal else b.y
	gaps.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var cursor: float = a.x if horizontal else a.y
	for g: Vector2 in gaps:
		if g.x > cursor:
			_occluder_span(a, horizontal, cursor, g.x)
		cursor = maxf(cursor, g.y)
	if cursor < stop:
		_occluder_span(a, horizontal, cursor, stop)


func _occluder_span(origin: Vector2, horizontal: bool, from: float, to: float) -> void:
	var h: float = WALL_PX * 0.5
	var pts := PackedVector2Array()
	if horizontal:
		pts = PackedVector2Array([Vector2(from, origin.y - h), Vector2(to, origin.y - h), Vector2(to, origin.y + h), Vector2(from, origin.y + h)])
	else:
		pts = PackedVector2Array([Vector2(origin.x - h, from), Vector2(origin.x + h, from), Vector2(origin.x + h, to), Vector2(origin.x - h, to)])
	var poly := OccluderPolygon2D.new()
	poly.polygon = pts
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	var occ := LightOccluder2D.new()
	occ.occluder = poly
	add_child(occ)


func _build_lights() -> void:
	for r: Room in run.sim.ship.rooms:
		var rp: Rect2 = room_rect_px(r)
		_lamps.append(_light(Vector2(rp.get_center().x, rp.position.y + ppm * 0.35), Color(1.0, 0.86, 0.66), 1.25, rp.size.x * 0.9, true, 220.0))
		_alarms.append(_light(Vector2(rp.position.x + ppm * 0.4, rp.position.y + ppm * 0.3), Color(1.0, 0.1, 0.06), 0.0, rp.size.x * 0.9, true, 160.0))
		_fire_lights.append(_light(Vector2(rp.get_center().x, rp.end.y - ppm * 0.6), Color(1.0, 0.48, 0.16), 0.0, rp.size.x * 0.95, true, 140.0))


func _build_flames() -> void:
	var dot: GradientTexture2D = ShipView.radial_texture(32)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(3.0, 2.2, 0.9, 1.0))
	ramp.set_color(1, Color(0.4, 0.05, 0.02, 0.0))
	ramp.add_point(0.4, Color(2.2, 0.75, 0.15, 0.85))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for r: Room in run.sim.ship.rooms:
		var rp: Rect2 = room_rect_px(r)
		var p := CPUParticles2D.new()
		p.texture = dot
		p.material = mat
		p.amount = 90
		p.lifetime = 0.8
		p.emitting = false
		p.position = Vector2(rp.get_center().x, rp.end.y - 4.0)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(rp.size.x * 0.38, 3.0)
		p.direction = Vector2(0, -1)
		p.spread = 16.0
		p.gravity = Vector2(0, -260)
		p.initial_velocity_min = 40.0
		p.initial_velocity_max = 110.0
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.6
		p.color_ramp = ramp
		p.z_index = 6
		add_child(p)
		_flames.append(p)


func _build_drill() -> void:
	var di: int = run.sim.ship.room_with_system("drill")
	if di < 0:
		return
	var rp: Rect2 = room_rect_px(run.sim.ship.rooms[di])
	var cx: float = rp.get_center().x
	_drill_poly = Polygon2D.new()
	_drill_poly.polygon = PackedVector2Array([
		Vector2(cx - ppm * 1.1, rp.end.y + WALL_PX * 0.5), Vector2(cx + ppm * 1.1, rp.end.y + WALL_PX * 0.5),
		Vector2(cx + ppm * 0.7, rp.end.y + ppm * 0.6), Vector2(cx, rp.end.y + ppm * 1.7),
		Vector2(cx - ppm * 0.7, rp.end.y + ppm * 0.6)])
	_drill_poly.color = Color(2.4, 1.0, 0.35)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_drill_poly.material = unlit
	add_child(_drill_poly)
	_drill_light = _light(Vector2(cx, rp.end.y + ppm * 1.5), Color(1.0, 0.55, 0.2), 1.8, ppm * 6.0, true, 160.0)


## True while the node follows a drilling segment (set by Main when a RockView is present).
func is_drilling() -> bool:
	return _drill != null


## Switch between the M0 cutaway (static rock, small drill glow) and a drilling segment: with a
## DrillSim the static rock goes away, the crown, sparks and hull floodlights switch on, and this
## node follows the sim's ship_pos. Pass null to go back.
func set_drilling(d: DrillSim) -> void:
	_drill = d
	var on: bool = d != null
	for n: Node in _m0_rock:
		if n is CanvasItem:
			(n as CanvasItem).visible = not on
		elif n is Light2D:
			(n as Light2D).enabled = not on
	if _drill_poly != null:
		_drill_poly.visible = not on
	if _drill_light != null:
		_drill_light.enabled = not on
	for l: PointLight2D in _floods:
		l.enabled = on
	if _crown != null:
		_crown.visible = on
	if _crown_light != null:
		_crown_light.enabled = on
	if not on:
		_sparks.emitting = false
		_dust.emitting = false
		position = Vector2.ZERO


## The cutting crown under the whole tower, the hull floodlights, sparks and dust. Hidden and dark
## until set_drilling. Rock lights use light mask 2 (RockView.LIGHT_MASK); the crown parts use 3 so
## those lights shade them too.
func _build_crown() -> void:
	var size: Vector2 = ship_size_m() * ppm
	var amb: Color = RockView.AMBIENT
	_crown = Node2D.new()
	_crown.position = Vector2(0.0, size.y)
	_crown.z_index = 6
	_crown.visible = false
	add_child(_crown)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-6, -8), Vector2(size.x + 6.0, -8), Vector2(size.x + 6.0, 14), Vector2(-6, 14)])
	body.color = Color(0.3, 0.29, 0.28)
	body.light_mask = 3
	_crown.add_child(body)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	unlit.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var teeth: int = maxi(1, roundi(size.x / 80.0))
	var tw: float = size.x / float(teeth)
	for i: int in range(teeth):
		var x0: float = float(i) * tw
		var tooth := Polygon2D.new()
		tooth.polygon = PackedVector2Array([Vector2(x0 + 2, 12), Vector2(x0 + tw - 2, 12), Vector2(x0 + tw * 0.5, 47)])
		tooth.color = Color(0.28, 0.27, 0.26).darkened(0.15 * float(i % 2))
		tooth.light_mask = 3
		_crown.add_child(tooth)
		var glow := Polygon2D.new()
		glow.polygon = PackedVector2Array([Vector2(x0 + tw * 0.25, 30), Vector2(x0 + tw * 0.75, 30), Vector2(x0 + tw * 0.5, 48)])
		glow.color = Color(1.5 / amb.r, 0.62 / amb.g, 0.2 / amb.b, 1.0)
		glow.material = unlit
		_crown.add_child(glow)
		_crown_glow.append(glow)
	_crown_light = _light(Vector2(size.x * 0.5, size.y + 34.0), Color(1.0, 0.55, 0.22), 0.3, ppm * 6.0, false, 110.0)
	_crown_light.texture = RockView.light_texture(128, 0.0, 0.3, 0.6)
	_crown_light.texture_scale = ppm * 6.0 * 2.0 / 128.0 / 0.4
	_crown_light.range_item_cull_mask = 2
	_crown_light.enabled = false
	# Hull floodlights: low corners throw down and out, mid-hull ones rake the shaft walls.
	var flood_col := Color(0.9, 0.95, 1.0)
	var wide: ImageTexture = RockView.light_texture(128, 0.3, 0.65, 0.38)
	for spec: Vector4 in [Vector4(90.0, size.y - 50.0, 1.5, 11.0), Vector4(size.x - 90.0, size.y - 50.0, 1.5, 11.0),
			Vector4(110.0, size.y * 0.5, 0.9, 9.0), Vector4(size.x - 110.0, size.y * 0.5, 0.9, 9.0)]:
		var fl: PointLight2D = _light(Vector2(spec.x, spec.y), flood_col, spec.z, ppm * spec.w, false, 110.0)
		fl.texture = wide
		fl.texture_scale = ppm * spec.w * 2.0 / 128.0 / 0.4
		fl.range_item_cull_mask = 2
		fl.enabled = false
		_floods.append(fl)
	var hot := Gradient.new()
	hot.set_color(0, Color(1.7 / amb.r, 1.45 / amb.g, 0.8 / amb.b, 1.0))
	hot.set_color(1, Color(0.8 / amb.r, 0.18 / amb.g, 0.04 / amb.b, 0.0))
	hot.add_point(0.35, Color(1.5 / amb.r, 0.8 / amb.g, 0.25 / amb.b, 0.9))
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sparks = CPUParticles2D.new()
	_sparks.texture = ShipView.radial_texture(12)
	_sparks.material = add_mat
	_sparks.amount = 150
	_sparks.lifetime = 0.6
	_sparks.emitting = false
	_sparks.position = Vector2(size.x * 0.5, size.y + 40.0)
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.emission_rect_extents = Vector2(size.x * 0.46, 3.0)
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 100.0
	_sparks.gravity = Vector2(0, 1200)
	_sparks.initial_velocity_min = 140.0
	_sparks.initial_velocity_max = 520.0
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.5
	_sparks.color_ramp = hot
	_sparks.z_index = -6
	add_child(_sparks)
	var puff := Gradient.new()
	puff.set_color(0, Color(0.7 / amb.r, 0.6 / amb.g, 0.5 / amb.b, 0.0))
	puff.set_color(1, Color(0.5 / amb.r, 0.45 / amb.g, 0.4 / amb.b, 0.0))
	puff.add_point(0.25, Color(0.55 / amb.r, 0.5 / amb.g, 0.44 / amb.b, 0.26))
	var mix_mat := CanvasItemMaterial.new()
	mix_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_dust = CPUParticles2D.new()
	_dust.texture = ShipView.radial_texture(48)
	_dust.material = mix_mat
	_dust.amount = 36
	_dust.lifetime = 2.2
	_dust.emitting = false
	_dust.position = Vector2(size.x * 0.5, size.y + 36.0)
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(size.x * 0.5, 4.0)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 90.0
	_dust.gravity = Vector2(0, -14)
	_dust.initial_velocity_min = 25.0
	_dust.initial_velocity_max = 90.0
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 4.5
	_dust.color_ramp = puff
	_dust.z_index = -7
	add_child(_dust)


func _process_drilling() -> void:
	var d: DrillSim = _drill
	var cut: bool = d.cutting and d.speed_m_s > 0.02
	var pulse: float = 0.86 + 0.14 * sin(_time * 34.0) + 0.07 * sin(_time * 57.0)
	var load_k: float = clampf(d.speed_m_s / 1.3, 0.2, 1.6)
	var shake: Vector2 = Vector2.ZERO
	if cut:
		shake = Vector2(sin(_time * 71.0), cos(_time * 83.0)) * 1.4
	position = d.ship_pos * ppm + shake
	_crown_light.energy = (1.1 + 0.4 * load_k) * pulse if cut else 0.25
	var wear_dim: float = 1.0 - 0.45 * d.bit_wear
	for g: Polygon2D in _crown_glow:
		g.color.a = clampf(pulse * wear_dim, 0.0, 1.0) if cut else 0.1
	_sparks.emitting = cut
	_sparks.speed_scale = 0.7 + 0.5 * load_k
	_dust.emitting = cut


func _build_props() -> void:
	var tex: Texture2D = ShipView.canvas_tex("res://assets/test/reactor_albedo.png", "res://assets/test/reactor_normal.png")
	var ri: int = run.sim.ship.room_with_system("reactor")
	if tex == null or ri < 0:
		return
	var rp: Rect2 = room_rect_px(run.sim.ship.rooms[ri])
	var s := Sprite2D.new()
	s.texture = tex
	var k: float = (ppm * 1.7) / 320.0
	s.scale = Vector2(k, k)
	s.position = Vector2(rp.position.x + rp.size.x * 0.68, rp.end.y - ppm * 0.85)
	s.z_index = -1
	add_child(s)


func _build_crew() -> void:
	for c: CrewMember in run.sim.ship.crew:
		var ci: int = c.index
		_crew_nodes.append(_fn(4, func(n: Node2D) -> void: _draw_crew(n, ci)))
		_crew_lights.append(_light(Vector2.ZERO, Color(0.85, 0.92, 1.0), 0.45, ppm * 1.7, false, 120.0))


func _process(delta: float) -> void:
	_time += delta
	var ship: Ship = run.sim.ship
	for r: Room in ship.rooms:
		var i: int = r.index
		var hazard: bool = r.fire > 0.0 or r.breach_m2 > 0.0 or r.level_m() > 0.3
		_alarms[i].enabled = hazard
		_alarms[i].energy = 0.4 + 0.9 * (0.5 + 0.5 * sin(_time * 6.0 + float(i)))
		_fire_lights[i].enabled = r.fire > 0.0
		_fire_lights[i].energy = 2.6 * r.fire * (0.8 + 0.2 * sin(_time * 23.0 + float(i) * 1.7) + 0.1 * sin(_time * 41.0))
		_flames[i].emitting = r.fire > 0.02
		_flames[i].speed_scale = 0.6 + r.fire
		_lamps[i].energy = 1.25 * (1.0 - clampf(r.level_m() / r.rect.size.y, 0.0, 0.7))
	for c: CrewMember in ship.crew:
		_crew_nodes[c.index].position = c.pos * ppm
		_crew_lights[c.index].position = (c.pos + Vector2(0, -1.0)) * ppm
		_crew_lights[c.index].enabled = c.alive
	if _drill != null:
		_process_drilling()
	elif _drill_light != null:
		var spin: float = 0.85 + 0.15 * sin(_time * 30.0)
		_drill_light.energy = 1.8 * spin
		_drill_poly.color = Color(2.4 * spin, 1.0 * spin, 0.35)
	for n: FnDraw in _redraw:
		n.queue_redraw()


func _draw_heat(n: Node2D, ri: int) -> void:
	var r: Room = run.sim.ship.rooms[ri]
	var heat: float = clampf((r.temp_c() - 34.0) / 90.0, 0.0, 0.35)
	if heat > 0.0:
		n.draw_rect(room_rect_px(r), Color(1.0, 0.3, 0.05, heat))


func _draw_water(n: Node2D, ri: int) -> void:
	var ship: Ship = run.sim.ship
	var r: Room = ship.rooms[ri]
	var rp: Rect2 = room_rect_px(r)
	if r.water_ml > 0:
		var lvl: float = minf(r.level_m() * ppm, rp.size.y)
		n.draw_rect(Rect2(rp.position.x, rp.end.y - lvl, rp.size.x, lvl), Color(0.08, 0.3, 0.4, 0.6))
		var pts := PackedVector2Array()
		for k: int in range(25):
			var x: float = rp.position.x + rp.size.x * float(k) / 24.0
			pts.append(Vector2(x, rp.end.y - lvl + 2.0 * sin(_time * 2.2 + x * 0.045)))
		n.draw_polyline(pts, Color(0.6, 0.95, 1.1, 0.9), 2.0)


func _draw_ladder(n: Node2D, li: int) -> void:
	var ship: Ship = run.sim.ship
	var l: Link = ship.links[li]
	var x0: float = (l.x - 0.22) * ppm
	var x1: float = (l.x + 0.22) * ppm
	var y0: float = ship.rooms[l.a].floor_y() * ppm - ppm * 0.9
	var y1: float = ship.rooms[l.b].floor_y() * ppm
	var col := Color(0.6, 0.57, 0.5)
	n.draw_line(Vector2(x0, y0), Vector2(x0, y1), col, 3.0)
	n.draw_line(Vector2(x1, y0), Vector2(x1, y1), col, 3.0)
	var y: float = y0 + 10.0
	while y < y1:
		n.draw_line(Vector2(x0, y), Vector2(x1, y), col, 2.0)
		y += ppm * 0.3
	var flow: float = run.sim.hazards.link_flow_ml_s[li] / Room.ML_PER_M3
	if flow > 0.0:
		var lower: Room = ship.rooms[l.b]
		var top_y: float = ship.rooms[l.a].floor_y() * ppm
		var bottom_y: float = lower.floor_y() * ppm - minf(lower.level_m() * ppm, lower.rect.size.y * ppm)
		var w: float = clampf(flow * 40.0, 3.0, 20.0)
		n.draw_rect(Rect2(l.x * ppm - w * 0.5, top_y, w, bottom_y - top_y), Color(0.25, 0.6, 0.75, 0.55))
		n.draw_line(Vector2(l.x * ppm, top_y), Vector2(l.x * ppm, bottom_y), Color(0.7, 1.0, 1.2, 0.8), 1.5)


func _draw_frame(n: Node2D, ri: int) -> void:
	var ship: Ship = run.sim.ship
	var r: Room = ship.rooms[ri]
	n.draw_rect(room_rect_px(r), Color(0.14, 0.145, 0.16), false, WALL_PX)
	for l: Link in ship.links:
		if l.a != ri:
			continue
		if l.kind == Link.Kind.DOOR:
			var fy: float = r.floor_y() * ppm
			n.draw_rect(Rect2(l.x * ppm - WALL_PX * 0.5, fy - l.height_m * ppm, WALL_PX, l.height_m * ppm), Color(0.34, 0.31, 0.27) if l.open else Color(0.55, 0.48, 0.2))
		else:
			var y: float = r.floor_y() * ppm
			var half: float = l.span_m * 0.5 * ppm
			n.draw_line(Vector2(l.x * ppm - half, y), Vector2(l.x * ppm + half, y), Color(0.9, 0.72, 0.15), 3.0)


func _draw_label(n: Node2D, ri: int) -> void:
	var r: Room = run.sim.ship.rooms[ri]
	var at: Vector2 = room_rect_px(r).position + Vector2(WALL_PX + 6.0, WALL_PX + 18.0)
	n.draw_string(_font, at, r.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.83, 0.76))
	var line: String = "%d C" % roundi(r.temp_c())
	if r.water_ml > 0:
		line += "   water %.2f m" % r.level_m()
	if r.fire > 0.0:
		line += "   FIRE %d%%" % roundi(r.fire * 100.0)
	if r.breach_m2 > 0.0:
		line += "   BREACH"
	n.draw_string(_font, at + Vector2(0, 18), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.68, 0.25) if r.fire <= 0.0 else Color(1.5, 0.55, 0.2))


func _draw_crew(n: Node2D, ci: int) -> void:
	var c: CrewMember = run.sim.ship.crew[ci]
	var col: Color = CREW_COLORS[ci % CREW_COLORS.size()]
	if not c.alive:
		n.draw_rect(Rect2(Vector2(-0.6 * ppm, -0.25 * ppm), Vector2(1.2 * ppm, 0.25 * ppm)), Color(0.35, 0.33, 0.32))
		return
	var w: float = 0.42 * ppm
	var h: float = 1.15 * ppm
	n.draw_rect(Rect2(Vector2(-w * 0.5, -h), Vector2(w, h)), col)
	n.draw_rect(Rect2(Vector2(-w * 0.5, -h * 0.45), Vector2(w, h * 0.12)), col.darkened(0.45))
	n.draw_circle(Vector2(0, -h - 0.17 * ppm), 0.17 * ppm, Color(0.86, 0.72, 0.6))
	n.draw_string(_font, Vector2(-w, -h - 0.42 * ppm), c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.85))
