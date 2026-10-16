class_name ShipView
extends Node2D
## Builds and updates the cutaway from the sim's state: painted rooms (RoomArt), hull plating, the
## drill crown, ladders, painted crew (CrewSprite), water, fire, heat and the lights that make it
## read. Godot lets one canvas item take only about 15 lights, so everything is split into small
## per-room, per-crew and per-strip nodes (each only meets nearby lights) and idle lights are
## disabled, not dimmed. Ship space is meters with y down; this node's origin is the ship's top-left.
## Draw order (z): rock -10, wall -5, floor -4, props -3, lamp -2, heat 0, ladders 1, doors and hatch
## rims 2, room frame 3, hull 3, flames 5, crew 6 (limbs 4 to 8), water 10, labels 12, tags 14.

const ROCK_CHUNK: int = 512
const LAMP_ENERGY: float = 1.7
const HULL_ART_PX: float = 48.0
## A rival tower: oxide-red hull plating, colder lamps, red marker lights (same room art as ours).
const ENEMY_HULL_TINT: Color = Color(2.2, 1.3, 1.0)
const ENEMY_LAMP: Color = Color(0.78, 0.88, 1.0)
const FLOOD_WARM: Color = Color(1.0, 0.88, 0.72)
const FLOOD_COLD: Color = Color(0.72, 0.86, 1.0)

## A node that draws through a callback, so each room or crew member is its own small canvas item.
class FnDraw extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var sim: Sim
var world: ShipWorld  ## The ship this view draws (the player's, or the enemy's in a fight).
var ppm: float = 80.0
var _font: Font
var _radial: GradientTexture2D
var _room_art: Array[RoomArt] = []
var _lamps: Array[PointLight2D] = []
var _alarms: Array[PointLight2D] = []
var _fire_lights: Array[PointLight2D] = []
var _flames: Array[CPUParticles2D] = []
var _sprays: Array[CPUParticles2D] = []  ## Water jetting in from the hull at a breach, per room.
var _enemy: bool = false
var _crew: Array[CrewSprite] = []
var _crew_lights: Array[PointLight2D] = []
var _redraw: Array[FnDraw] = []
var _foot_lift: float = 14.0
var _time: float = 0.0
## Drilling mode: the node rides the sim's ship_pos in segment space, over a RockView.
var _drill: DrillSim
var _m0_rock: Array[Node] = []
var _floods: Array[PointLight2D] = []
var _crown: Node2D
var _crown_glow: Array[Sprite2D] = []
var _crown_light: PointLight2D
var _crown_fill: PointLight2D
var _sparks: CPUParticles2D
var _dust: CPUParticles2D
var _chips: CPUParticles2D
var _streaks: CPUParticles2D
## Water sloshing with the tower's motion: a damped spring (see _update_slosh) and how agitated it is.
var _slosh: float = 0.0
var _slosh_v: float = 0.0
var _agit: float = 0.0
var _last_px: float = 0.0
var _last_vx: float = 0.0
var _last_heading: float = 0.0
var selected_crew_id: String = ""  ## Set by Main: that crew member gets the selection ring.


func setup(p_sim: Sim, p_world: ShipWorld, p_ppm: float) -> void:
	sim = p_sim
	world = p_world
	ppm = p_ppm
	_font = ThemeDB.fallback_font
	_enemy = sim != null and world != sim.player
	_radial = ShipView.radial_texture(256)
	_foot_lift = RoomArt.GRATING_ART_H * 0.7 * ppm / ArtLib.ART_PPM
	_build_rock()
	_build_rooms()
	_build_ladders()
	_build_hull()
	_build_occluders()
	_build_lights()
	_build_flames()
	_build_sprays()
	_build_crown()
	_build_crew()
	_build_tags()
	if _enemy:
		_fn(4, func(n: Node2D) -> void: _draw_rust(n), 1, 1.7)
		_fn(4, func(n: Node2D) -> void: _draw_markers(n), 2, 2.0)


## Follow a new sim with the same ship layout (a new run of the same ship): the nodes stay.
func rebind(p_sim: Sim, p_world: ShipWorld) -> void:
	sim = p_sim
	world = p_world
	_rebuild_crew()


func ship_size_m() -> Vector2:
	var end := Vector2.ZERO
	for r: Room in world.ship.rooms:
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


## mode 0: lit, 1: unshaded, 2: additive and unshaded. `boost` brightens an unshaded drawing (the
## CanvasModulate still darkens it a little; measured, a plain color comes out about twice too dim).
func _fn(z: int, fn: Callable, mode: int = 0, boost: float = 1.0) -> FnDraw:
	var n := FnDraw.new()
	n.fn = fn
	n.z_index = z
	if mode != 0:
		n.material = ArtLib.unshaded() if mode == 1 else ArtLib.additive_unshaded()
		n.modulate = Color(boost, boost, boost, 1.0)
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
	var tex: Texture2D = RockTiles.canvas_tile("dense")
	var k: float = RockTiles.TILE_M * ppm / float(RockTiles.TILE_PX)
	var origin: Vector2 = (center_px() - Vector2(2048, 1536)).snapped(Vector2(ROCK_CHUNK, ROCK_CHUNK))
	for gy: int in range(6):
		for gx: int in range(8):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			var at := origin + Vector2(gx * ROCK_CHUNK, gy * ROCK_CHUNK)
			s.region_rect = Rect2(at / k, Vector2(ROCK_CHUNK, ROCK_CHUNK) / k)
			s.scale = Vector2(k, k)
			s.position = at
			s.self_modulate = Color(1.15, 1.08, 1.0)
			s.z_index = -10
			add_child(s)
			_m0_rock.append(s)
	var size: Vector2 = ship_size_m() * ppm
	_m0_rock.append(_light(Vector2(-ppm * 0.6, size.y * 0.3), Color(0.55, 0.68, 0.85), 1.5, ppm * 8.0, true, 260.0))
	_m0_rock.append(_light(Vector2(size.x + ppm * 0.6, size.y * 0.3), Color(0.55, 0.68, 0.85), 1.5, ppm * 8.0, true, 260.0))


func _build_rooms() -> void:
	var ship: Ship = world.ship
	for r: Room in ship.rooms:
		var art := RoomArt.new()
		art.build(ship, r, ppm)
		add_child(art)
		_room_art.append(art)
		if _enemy:
			art.modulate = Color(0.9, 0.96, 1.1)
		var ri: int = r.index
		_fn(0, func(n: Node2D) -> void: RoomFx.draw_heat(n, world.ship.rooms[ri], room_rect_px(world.ship.rooms[ri]), _time), 2, 2.0)
		_fn(3, func(n: Node2D) -> void: RoomFx.draw_frame(n, room_rect_px(world.ship.rooms[ri])))
		var left: bool = r.rect.get_center().x < ship_size_m().x * 0.5
		_fn(10, func(n: Node2D) -> void: RoomWater.draw(n, world.ship.rooms[ri], room_rect_px(world.ship.rooms[ri]), ppm, _time, _slosh, _agit, left), 1, 1.8)
		_fn(11, func(n: Node2D) -> void: RoomFx.draw_alarm_rim(n, world.ship.rooms[ri], room_rect_px(world.ship.rooms[ri]), _time), 2, 2.0)
		_fn(12, func(n: Node2D) -> void: RoomFx.draw_label(n, world.ship, world.ship.rooms[ri], room_rect_px(world.ship.rooms[ri]), ppm, _font, _time), 1)


func _build_ladders() -> void:
	var ship: Ship = world.ship
	var tex: Texture2D = ArtLib.lit("ship", "ladder")
	var k: float = ppm / ArtLib.ART_PPM
	for l: Link in ship.links:
		if l.kind != Link.Kind.HATCH:
			continue
		var li: int = l.index
		var y0: float = ship.rooms[l.a].floor_y() * ppm - ppm * 0.9
		var y1: float = ship.rooms[l.b].floor_y() * ppm - _foot_lift * 0.4
		if tex != null:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			s.region_rect = Rect2(0.0, 0.0, tex.get_size().x, (y1 - y0) / k)
			s.scale = Vector2(k, k)
			s.position = Vector2(l.x * ppm - tex.get_size().x * 0.5 * k, y0)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			s.z_index = 1
			add_child(s)
		_fn(9, func(n: Node2D) -> void: RoomFx.draw_ladder_flow(n, world.ship, world, li, ppm, _time), 1, 1.8)


## The outer plating strips around the tower: top, left and right, in pieces so each is lit by
## only nearby lamps.
func _build_hull() -> void:
	var size: Vector2 = ship_size_m() * ppm
	var k: float = ppm / ArtLib.ART_PPM
	var th: float = HULL_ART_PX * k
	var overlap: float = 3.0
	var top: Texture2D = ArtLib.lit("ship", "hull_top")
	var left: Texture2D = ArtLib.lit("ship", "hull_left")
	var right: Texture2D = ArtLib.lit("ship", "hull_right")
	var seg: float = 3.0 * ppm
	if top != null:
		var x: float = -th + overlap
		var end: float = size.x + th - overlap
		while x < end:
			var w: float = minf(seg, end - x)
			_strip(top, Vector2(x, -th + overlap), Rect2((x + th) / k, 0.0, w / k, HULL_ART_PX), k)
			x += w
	for side: int in range(2):
		var tex: Texture2D = left if side == 0 else right
		if tex == null:
			continue
		var y: float = 0.0
		while y < size.y:
			var h: float = minf(seg, size.y - y)
			var px: float = -th + overlap if side == 0 else size.x - overlap
			_strip(tex, Vector2(px, y), Rect2(0.0, y / k, HULL_ART_PX, h / k), k)
			y += h


func _strip(tex: Texture2D, at: Vector2, region: Rect2, k: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = region
	s.scale = Vector2(k, k)
	s.position = at
	s.self_modulate = ENEMY_HULL_TINT if _enemy else Color(1.6, 1.6, 1.6, 1.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.z_index = 3
	add_child(s)


func _build_occluders() -> void:
	var ship: Ship = world.ship
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
	var h: float = 4.0
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
	for r: Room in world.ship.rooms:
		var rp: Rect2 = room_rect_px(r)
		var bulb: Vector2 = rp.position + RoomArt.lamp_point(rp, ppm)
		_lamps.append(_light(bulb + Vector2(0, ppm * 0.1), ENEMY_LAMP if _enemy else Color(1.0, 0.84, 0.62), LAMP_ENERGY, rp.size.x * 0.85, true, 200.0))
		_alarms.append(_light(Vector2(rp.position.x + ppm * 0.4, rp.position.y + ppm * 0.3), Color(1.0, 0.1, 0.06), 0.0, rp.size.x * 0.9, true, 160.0))
		_fire_lights.append(_light(Vector2(rp.get_center().x, rp.end.y - ppm * 0.6), Color(1.0, 0.48, 0.16), 0.0, rp.size.x * 0.95, true, 140.0))


func _build_flames() -> void:
	var dot: GradientTexture2D = ShipView.radial_texture(32)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(3.0, 2.2, 0.9, 1.0))
	ramp.set_color(1, Color(0.4, 0.05, 0.02, 0.0))
	ramp.add_point(0.4, Color(2.2, 0.75, 0.15, 0.85))
	var mat := ArtLib.additive_unshaded()
	for r: Room in world.ship.rooms:
		var rp: Rect2 = room_rect_px(r)
		var p := CPUParticles2D.new()
		p.texture = dot
		p.material = mat
		p.amount = 90
		p.lifetime = 0.8
		p.emitting = false
		p.position = Vector2(rp.get_center().x, rp.end.y - _foot_lift)
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
		p.z_index = 5
		add_child(p)
		_flames.append(p)


## A jet of water from the outer wall into each room, shown while the room has a breach. The wall is
## the nearer side of the tower (the sim does not say which); the jet arcs in and falls.
func _build_sprays() -> void:
	var dot: GradientTexture2D = ShipView.radial_texture(16)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(2.0, 1.95, 1.6, 0.95))
	ramp.set_color(1, Color(0.55, 0.5, 0.3, 0.0))
	ramp.add_point(0.5, Color(1.3, 1.25, 0.95, 0.7))
	var mid_x: float = ship_size_m().x * 0.5
	for r: Room in world.ship.rooms:
		var rp: Rect2 = room_rect_px(r)
		var left: bool = r.rect.get_center().x < mid_x
		var inward: float = 1.0 if left else -1.0
		var p := CPUParticles2D.new()
		p.texture = dot
		p.material = ArtLib.additive_unshaded()
		p.amount = 90
		p.lifetime = 1.0
		p.emitting = false
		p.position = Vector2(rp.position.x + 6.0 if left else rp.end.x - 6.0, rp.position.y + rp.size.y * 0.5)
		p.direction = Vector2(inward, -0.3)
		p.spread = 9.0
		p.gravity = Vector2(0.0, 620.0)
		p.initial_velocity_min = 230.0
		p.initial_velocity_max = 380.0
		p.scale_amount_min = 0.9
		p.scale_amount_max = 1.8
		p.color_ramp = ramp
		p.z_index = 11
		add_child(p)
		_sprays.append(p)


## True while the node follows a drilling segment (set by Main when a RockView is present).
func is_drilling() -> bool:
	return _drill != null


## Switch between the plain cutaway (static rock behind the tower) and a drilling segment: with a
## DrillSim the static rock goes away, the crown bites, the sparks and hull floodlights switch on,
## and this node follows the sim's ship_pos. Pass null to go back.
func set_drilling(d: DrillSim) -> void:
	_drill = d
	var on: bool = d != null
	for n: Node in _m0_rock:
		if n is CanvasItem:
			(n as CanvasItem).visible = not on
		elif n is Light2D:
			(n as Light2D).enabled = not on
	for l: PointLight2D in _floods:
		l.enabled = on
	if _crown_light != null:
		_crown_light.enabled = on
	if not on:
		_sparks.emitting = false
		_dust.emitting = false
		_chips.emitting = false
		_streaks.emitting = false
		position = Vector2.ZERO
		_set_crown_glow(0.5)


## Switch the hull floodlights (they light the rock only; the combat view turns them on for both towers).
func set_floodlights(on: bool) -> void:
	for l: PointLight2D in _floods:
		l.enabled = on


## Show or hide the stand-in rock behind the tower (and its two side lights). The combat view uses
## this for an enemy ship; set_drilling also drives it.
func set_backdrop_visible(on: bool) -> void:
	for n: Node in _m0_rock:
		if n is CanvasItem:
			(n as CanvasItem).visible = on
		elif n is Light2D:
			(n as Light2D).enabled = on


func _set_crown_glow(target: float) -> void:
	for g: Sprite2D in _crown_glow:
		ArtLib.set_glow(g, target)


## The painted drill crown under the whole tower (the teeth glow brighter while cutting), the hull
## floodlights, sparks and dust. Rock lights use light mask 2 (RockView.LIGHT_MASK); the crown parts
## use 3 so those lights shade them too.
func _build_crown() -> void:
	var size: Vector2 = ship_size_m() * ppm
	_crown = Node2D.new()
	_crown.position = Vector2(0.0, size.y - 6.0)
	_crown.z_index = 6
	add_child(_crown)
	var tex: Texture2D = ArtLib.lit("ship", "drill_crown")
	var glow_tex: Texture2D = ArtLib.plain("ship", "drill_crown", "emission")
	var crown_h: float = 0.0
	if tex != null:
		var art: Vector2 = tex.get_size()
		var sc: float = size.x / art.x
		crown_h = art.y * sc
		var pieces: int = 4
		var pw: float = art.x / float(pieces)
		for i: int in range(pieces):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.region_enabled = true
			s.region_rect = Rect2(pw * float(i), 0.0, pw, art.y)
			s.scale = Vector2(sc, sc)
			s.position = Vector2(pw * float(i) * sc, 0.0)
			s.light_mask = 3
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_crown.add_child(s)
			if glow_tex != null:
				var g := Sprite2D.new()
				g.texture = glow_tex
				g.centered = false
				g.region_enabled = true
				g.region_rect = s.region_rect
				g.scale = s.scale
				g.position = s.position
				g.material = ArtLib.additive_unshaded()
				g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				_crown.add_child(g)
				_crown_glow.append(g)
		_set_crown_glow(0.5)
	var tip_y: float = size.y - 6.0 + maxf(crown_h, 60.0) - 14.0
	_crown_light = _light(Vector2(size.x * 0.5, tip_y - 4.0), Color(1.0, 0.55, 0.22), 0.3, ppm * 6.0, false, 110.0)
	_crown_light.texture = RockView.light_texture(128, 0.0, 0.3, 0.6)
	_crown_light.texture_scale = ppm * 6.0 * 2.0 / 128.0 / 0.4
	_crown_light.range_item_cull_mask = 2
	_crown_light.enabled = false
	_crown_fill = _light(Vector2(size.x * 0.5, size.y + ppm * 0.9), Color(1.0, 0.72, 0.5), 1.1, ppm * 5.5, false, 140.0)
	# Hull floodlights: low corners throw down and out, mid-hull ones rake the shaft walls.
	# Warm and soft: no flat core (that read as blown-out plaster), a long gentle falloff.
	var flood_col: Color = FLOOD_COLD if _enemy else FLOOD_WARM
	var wide: ImageTexture = RockView.light_texture(128, 0.0, 0.5, 0.3)
	for spec: Vector4 in [Vector4(90.0, size.y - 50.0, 1.05, 11.0), Vector4(size.x - 90.0, size.y - 50.0, 1.05, 11.0),
			Vector4(110.0, size.y * 0.5, 0.7, 9.0), Vector4(size.x - 110.0, size.y * 0.5, 0.7, 9.0)]:
		var fl: PointLight2D = _light(Vector2(spec.x, spec.y), flood_col, spec.z, ppm * spec.w, false, 110.0)
		fl.texture = wide
		fl.texture_scale = ppm * spec.w * 2.0 / 128.0 / 0.4
		fl.range_item_cull_mask = 2
		fl.enabled = false
		_floods.append(fl)
	if not _enemy:
		# One wide, faint warm fill over the shaft so the rock around the tower is never pitch black.
		var fill: PointLight2D = _light(Vector2(size.x * 0.5, size.y * 0.8), Color(0.95, 0.82, 0.68), 1.1, ppm * 20.0, false, 220.0)
		fill.texture = wide
		fill.texture_scale = ppm * 20.0 * 2.0 / 128.0 / 0.4
		fill.range_item_cull_mask = 2
		fill.enabled = false
		_floods.append(fill)
	var hot := Gradient.new()
	hot.set_color(0, Color(1.7, 1.45, 0.8, 1.0))
	hot.set_color(1, Color(0.8, 0.18, 0.04, 0.0))
	hot.add_point(0.35, Color(1.5, 0.8, 0.25, 0.9))
	_sparks = CPUParticles2D.new()
	_sparks.texture = ShipView.radial_texture(12)
	_sparks.material = ArtLib.additive_unshaded()
	_sparks.amount = 150
	_sparks.lifetime = 0.6
	_sparks.emitting = false
	_sparks.position = Vector2(size.x * 0.5, tip_y)
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
	puff.set_color(0, Color(0.4, 0.36, 0.32, 0.0))
	puff.set_color(1, Color(0.3, 0.27, 0.24, 0.0))
	puff.add_point(0.25, Color(0.36, 0.32, 0.28, 0.3))
	_dust = CPUParticles2D.new()
	_dust.texture = ShipView.radial_texture(48)
	_dust.material = ArtLib.unshaded()
	_dust.amount = 56
	_dust.lifetime = 2.2
	_dust.emitting = false
	_dust.position = Vector2(size.x * 0.5, tip_y - 6.0)
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(size.x * 0.5, 4.0)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 90.0
	_dust.gravity = Vector2(0, -14)
	_dust.initial_velocity_min = 25.0
	_dust.initial_velocity_max = 90.0
	_dust.scale_amount_min = 3.0
	_dust.scale_amount_max = 7.0
	_dust.color_ramp = puff
	_dust.z_index = -7
	add_child(_dust)
	_chips = CrownDebris.make_chips(size, tip_y)
	add_child(_chips)
	_streaks = CrownDebris.make_streaks(size, tip_y)
	add_child(_streaks)


## Oxide-red wash over the blue hull plating (a multiply tint alone cannot turn blue paint red).
func _draw_rust(n: Node2D) -> void:
	var size: Vector2 = ship_size_m() * ppm
	var th: float = HULL_ART_PX * ppm / ArtLib.ART_PPM
	var rust := Color(0.42, 0.11, 0.06, 0.5)
	n.draw_rect(Rect2(-th + 3.0, -th + 3.0, size.x + th * 2.0 - 6.0, th), rust)
	n.draw_rect(Rect2(-th + 3.0, 0.0, th, size.y), rust)
	n.draw_rect(Rect2(size.x - 3.0, 0.0, th, size.y), rust)


## Red marker lights down both hull edges and across the top, blinking out of step.
func _draw_markers(n: Node2D) -> void:
	var size: Vector2 = ship_size_m() * ppm
	var th: float = HULL_ART_PX * ppm / ArtLib.ART_PPM
	var edge: float = th * 0.5 - 1.5

	var i: int = 0
	var y: float = ppm * 0.9
	while y < size.y:
		for side: int in range(2):
			var x: float = -edge if side == 0 else size.x + edge
			_marker(n, Vector2(x, y), i + side)
		i += 2
		y += ppm * 2.2
	var x2: float = ppm * 1.2
	while x2 < size.x:
		_marker(n, Vector2(x2, -edge), i)
		i += 1
		x2 += ppm * 3.0


func _marker(n: Node2D, at: Vector2, i: int) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.6 + float(i) * 1.7)
	n.draw_circle(at, 9.0, Color(0.5, 0.04, 0.02, 0.18 + 0.2 * pulse))
	n.draw_circle(at, 3.5, Color(1.0, 0.16, 0.1, 0.55 + 0.45 * pulse))
	n.draw_circle(at, 1.6, Color(1.0, 0.7, 0.55, 0.6 + 0.4 * pulse))


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
	_set_crown_glow(1.7 * pulse * wear_dim if cut else 0.45)
	_sparks.emitting = cut
	_sparks.speed_scale = 0.7 + 0.5 * load_k
	_dust.emitting = cut
	_chips.emitting = cut
	_chips.speed_scale = 0.7 + 0.5 * load_k
	_streaks.emitting = cut
	_streaks.speed_scale = 0.7 + 0.4 * load_k


func _build_crew() -> void:
	var enemy: bool = sim != null and world != sim.player
	for c: CrewMember in world.ship.crew:
		_add_crew(c, enemy)


func _add_crew(c: CrewMember, enemy: bool) -> void:
	var spr := CrewSprite.new()
	spr.setup(c, ppm, enemy)
	add_child(spr)
	_crew.append(spr)
	_crew_lights.append(_light(Vector2.ZERO, Color(0.9, 0.93, 1.0), 0.8, ppm * 1.7, false, 120.0))


func _rebuild_crew() -> void:
	for s: CrewSprite in _crew:
		s.queue_free()
	for l: PointLight2D in _crew_lights:
		l.queue_free()
	_crew.clear()
	_crew_lights.clear()
	_build_crew()


func _build_tags() -> void:
	_fn(14, func(n: Node2D) -> void: RoomFx.draw_tags(n, world.ship, _crew, ppm, _font), 1)


## The tower's motion sets its water sloshing: a damped spring pushed by the hull's sideways
## acceleration and by the drill turning, with a slow swell of its own so a flooded room never sits
## still. The chop grows while the drill shakes the hull. View-side only; the sim never reads it.
func _update_slosh(delta: float) -> void:
	var d: float = maxf(delta, 0.0001)
	var vx: float = (position.x - _last_px) / d
	var ax: float = clampf((vx - _last_vx) / d, -4000.0, 4000.0)
	_last_px = position.x
	_last_vx = vx
	var turn: float = 0.0
	var shake: float = 0.0
	if _drill != null:
		turn = clampf((_drill.heading_deg - _last_heading) / d, -60.0, 60.0)
		_last_heading = _drill.heading_deg
		if _drill.cutting and _drill.speed_m_s > 0.02:
			shake = clampf(0.45 + 0.4 * _drill.speed_m_s, 0.0, 1.0)
	var push: float = -turn * 0.25 - ax * 0.003
	_slosh_v += (14.0 * (0.12 * sin(_time * 0.8) - _slosh) - 2.4 * _slosh_v + push) * d
	_slosh = clampf(_slosh + _slosh_v * d, -1.0, 1.0)
	_agit = move_toward(_agit, clampf(shake + absf(_slosh_v) * 0.3, 0.0, 1.0), d * 2.5)


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_update(delta)
	PerfRecorder.span(PerfRecorder.SPAN_SHIP, Time.get_ticks_usec() - t0)


func _update(delta: float) -> void:
	_time += delta
	_update_slosh(delta)
	var ship: Ship = world.ship
	if ship.crew.size() < _crew.size():
		_rebuild_crew()
	var enemy: bool = sim != null and world != sim.player
	while _crew.size() < ship.crew.size():
		_add_crew(ship.crew[_crew.size()], enemy)
	for r: Room in ship.rooms:
		var i: int = r.index
		var hazard: bool = r.fire > 0.0 or r.breach_m2 > 0.0 or r.level_m() > 0.3
		_alarms[i].enabled = hazard
		_alarms[i].energy = 0.4 + 0.9 * (0.5 + 0.5 * sin(_time * 6.0 + float(i)))
		_fire_lights[i].enabled = r.fire > 0.0
		_fire_lights[i].energy = 2.6 * r.fire * (0.8 + 0.2 * sin(_time * 23.0 + float(i) * 1.7) + 0.1 * sin(_time * 41.0))
		_flames[i].emitting = r.fire > 0.02
		_flames[i].speed_scale = 0.6 + r.fire
		_sprays[i].emitting = r.breach_m2 > 0.0
		_sprays[i].speed_scale = clampf(0.8 + r.breach_m2 * 8.0, 0.8, 1.6)
		var lamp_k: float = 1.0 - clampf(r.level_m() / r.rect.size.y, 0.0, 0.7)
		_lamps[i].energy = LAMP_ENERGY * lamp_k
		_room_art[i].update(ship, r, _time, lamp_k)
	for c: CrewMember in ship.crew:
		var spr: CrewSprite = _crew[c.index]
		spr.crew = c
		spr.selected = c.alive and c.id == selected_crew_id
		spr.station_system = ship.rooms[c.room].system if c.room >= 0 and c.room < ship.rooms.size() else "none"
		spr.position = c.pos * ppm + Vector2(0.0, -_foot_lift)
		spr.update(delta, _time)
		_crew_lights[c.index].position = (c.pos + Vector2(0, -1.0)) * ppm
		_crew_lights[c.index].enabled = c.alive
	if _drill != null:
		_process_drilling()
	for n: FnDraw in _redraw:
		n.queue_redraw()
