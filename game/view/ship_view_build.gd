class_name ShipViewBuild
extends RefCounted
## Static builders for the ShipView, moved out of it to keep that file short: the stand-in rock, the hull
## plating, the light occluders, the breach sprays, and the rival tower's rust wash and marker lights.
## Every function works on the ShipView `v` it is given and creates the same nodes the view once did.

static func rock(v: ShipView) -> void:
	var tex: Texture2D = RockTiles.canvas_tile("dense")
	var k: float = RockTiles.TILE_M * v.ppm / float(RockTiles.TILE_PX)
	var origin: Vector2 = (v.center_px() - Vector2(2048, 1536)).snapped(Vector2(ShipView.ROCK_CHUNK, ShipView.ROCK_CHUNK))
	for gy: int in range(6):
		for gx: int in range(8):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			var at := origin + Vector2(gx * ShipView.ROCK_CHUNK, gy * ShipView.ROCK_CHUNK)
			s.region_rect = Rect2(at / k, Vector2(ShipView.ROCK_CHUNK, ShipView.ROCK_CHUNK) / k)
			s.scale = Vector2(k, k)
			s.position = at
			s.self_modulate = Color(1.15, 1.08, 1.0)
			s.z_index = -10
			v.add_child(s)
			v._m0_rock.append(s)
	var size: Vector2 = v.ship_size_m() * v.ppm
	v._m0_rock.append(v._light(Vector2(-v.ppm * 0.6, size.y * 0.3), Color(0.55, 0.68, 0.85), 1.5, v.ppm * 8.0, true, 260.0))
	v._m0_rock.append(v._light(Vector2(size.x + v.ppm * 0.6, size.y * 0.3), Color(0.55, 0.68, 0.85), 1.5, v.ppm * 8.0, true, 260.0))


## The outer plating strips around the tower: top, left and right, in pieces so each is lit by
## only nearby lamps.
static func hull(v: ShipView) -> void:
	var size: Vector2 = v.ship_size_m() * v.ppm
	var k: float = v.ppm / ArtLib.ART_PPM
	var th: float = ShipView.HULL_ART_PX * k
	var overlap: float = 3.0
	var top: Texture2D = ArtLib.lit("ship", "hull_top")
	var left: Texture2D = ArtLib.lit("ship", "hull_left")
	var right: Texture2D = ArtLib.lit("ship", "hull_right")
	var seg: float = 3.0 * v.ppm
	if top != null:
		var x: float = -th + overlap
		var end: float = size.x + th - overlap
		while x < end:
			var w: float = minf(seg, end - x)
			strip(v, top, Vector2(x, -th + overlap), Rect2((x + th) / k, 0.0, w / k, ShipView.HULL_ART_PX), k)
			x += w
	for side: int in range(2):
		var tex: Texture2D = left if side == 0 else right
		if tex == null:
			continue
		var y: float = 0.0
		while y < size.y:
			var h: float = minf(seg, size.y - y)
			var px: float = -th + overlap if side == 0 else size.x - overlap
			strip(v, tex, Vector2(px, y), Rect2(0.0, y / k, ShipView.HULL_ART_PX, h / k), k)
			y += h


static func strip(v: ShipView, tex: Texture2D, at: Vector2, region: Rect2, k: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = region
	s.scale = Vector2(k, k)
	s.position = at
	s.self_modulate = ShipView.ENEMY_HULL_TINT if v._enemy else Color(1.6, 1.6, 1.6, 1.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.z_index = 3
	v.add_child(s)


static func occluders(v: ShipView) -> void:
	var ship: Ship = v.world.ship
	for r: Room in ship.rooms:
		var rp: Rect2 = v.room_rect_px(r)
		var top_gaps: Array[Vector2] = []
		var floor_gaps: Array[Vector2] = []
		var left_gaps: Array[Vector2] = []
		var right_gaps: Array[Vector2] = []
		for l: Link in ship.links:
			if l.kind == Link.Kind.HATCH:
				var g := Vector2(l.x - l.span_m * 0.5, l.x + l.span_m * 0.5) * v.ppm
				if l.a == r.index:
					floor_gaps.append(g)
				elif l.b == r.index:
					top_gaps.append(g)
			elif l.a == r.index or l.b == r.index:
				var door := Vector2(r.floor_y() - l.height_m, r.floor_y()) * v.ppm
				if absf(l.x - r.rect.position.x) < 0.01:
					left_gaps.append(door)
				else:
					right_gaps.append(door)
		wall_segments(v, rp.position, Vector2(rp.end.x, rp.position.y), top_gaps, true)
		wall_segments(v, Vector2(rp.position.x, rp.end.y), rp.end, floor_gaps, true)
		wall_segments(v, rp.position, Vector2(rp.position.x, rp.end.y), left_gaps, false)
		wall_segments(v, Vector2(rp.end.x, rp.position.y), rp.end, right_gaps, false)


static func wall_segments(v: ShipView, a: Vector2, b: Vector2, gaps: Array[Vector2], horizontal: bool) -> void:
	var stop: float = b.x if horizontal else b.y
	gaps.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var cursor: float = a.x if horizontal else a.y
	for g: Vector2 in gaps:
		if g.x > cursor:
			occluder_span(v, a, horizontal, cursor, g.x)
		cursor = maxf(cursor, g.y)
	if cursor < stop:
		occluder_span(v, a, horizontal, cursor, stop)


static func occluder_span(v: ShipView, origin: Vector2, horizontal: bool, from: float, to: float) -> void:
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
	v.add_child(occ)


## A jet of water from the outer wall into each room, shown while the room has a breach. The wall is
## the nearer side of the tower (the sim does not say which); the jet arcs in and falls.
static func sprays(v: ShipView) -> void:
	var dot: GradientTexture2D = ShipView.radial_texture(16)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(2.0, 1.95, 1.6, 0.95))
	ramp.set_color(1, Color(0.55, 0.5, 0.3, 0.0))
	ramp.add_point(0.5, Color(1.3, 1.25, 0.95, 0.7))
	var mid_x: float = v.ship_size_m().x * 0.5
	for r: Room in v.world.ship.rooms:
		var rp: Rect2 = v.room_rect_px(r)
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
		v.add_child(p)
		v._sprays.append(p)


## Oxide-red wash over the blue hull plating (a multiply tint alone cannot turn blue paint red).
static func draw_rust(v: ShipView, n: Node2D) -> void:
	var size: Vector2 = v.ship_size_m() * v.ppm
	var th: float = ShipView.HULL_ART_PX * v.ppm / ArtLib.ART_PPM
	var rust := Color(0.42, 0.11, 0.06, 0.5)
	n.draw_rect(Rect2(-th + 3.0, -th + 3.0, size.x + th * 2.0 - 6.0, th), rust)
	n.draw_rect(Rect2(-th + 3.0, 0.0, th, size.y), rust)
	n.draw_rect(Rect2(size.x - 3.0, 0.0, th, size.y), rust)


## Red marker lights down both hull edges and across the top, blinking out of step.
static func draw_markers(v: ShipView, n: Node2D) -> void:
	var size: Vector2 = v.ship_size_m() * v.ppm
	var th: float = ShipView.HULL_ART_PX * v.ppm / ArtLib.ART_PPM
	var edge: float = th * 0.5 - 1.5

	var i: int = 0
	var y: float = v.ppm * 0.9
	while y < size.y:
		for side: int in range(2):
			var x: float = -edge if side == 0 else size.x + edge
			marker(v, n, Vector2(x, y), i + side)
		i += 2
		y += v.ppm * 2.2
	var x2: float = v.ppm * 1.2
	while x2 < size.x:
		marker(v, n, Vector2(x2, -edge), i)
		i += 1
		x2 += v.ppm * 3.0


static func marker(v: ShipView, n: Node2D, at: Vector2, i: int) -> void:
	var pulse: float = 0.5 + 0.5 * sin(v._time * 2.6 + float(i) * 1.7)
	n.draw_circle(at, 9.0, Color(0.5, 0.04, 0.02, 0.18 + 0.2 * pulse))
	n.draw_circle(at, 3.5, Color(1.0, 0.16, 0.1, 0.55 + 0.45 * pulse))
	n.draw_circle(at, 1.6, Color(1.0, 0.7, 0.55, 0.6 + 0.4 * pulse))
