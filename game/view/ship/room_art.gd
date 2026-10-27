class_name RoomArt
extends Node2D
## The painted layers of one room (a node at the room's top-left corner, children in room pixels):
## the system's wall, floor grating (with gaps at hatches), the system's props standing on the floor,
## the ceiling lamp, hatch rims and doors. Lit sprites carry albedo and normal in a CanvasTexture so
## the room lamp, alarm and fire lights shade the paint. Emission twins (helm screens, coolant sight
## glass, reactor core, lamp bulb) are additive and unshaded (see ArtLib.set_glow).

const WALL_ART: Dictionary = {
	"helm": "bridge", "bracing": "bracing", "reactor": "reactor", "weapons": "weapons", "drill": "drill", "coolant": "coolant",
}
## Props per system: [texture, x as a fraction of the room width, mirrored, glows]
const PROPS: Dictionary = {
	"helm": [["bridge_helm", 0.56, false, true]],
	"bracing": [["bracing_jack", 0.13, false, false], ["bracing_manifold", 0.5, false, false], ["bracing_jack", 0.87, true, false]],
	"reactor": [["reactor_core", 0.5, false, true]],
	"weapons": [["weapons_breech", 0.42, false, false], ["weapons_ammo", 0.88, false, false]],
	"drill": [["drill_bitrack", 0.13, false, false], ["drill_motor", 0.46, false, false]],
	"coolant": [["coolant_pump", 0.33, false, false], ["coolant_tank", 0.76, false, true]],
}
const GRATING_ART_H: float = 40.0
const WALL_GAIN: float = 1.25

var room: Room
var ppm: float = 80.0
var rect_px: Rect2
var floor_h_px: float = 20.0
var lamp_pos: Vector2 = Vector2.ZERO  ## Where the lamp bulb is, in room pixels (the PointLight2D goes here).
var _glows: Array[Sprite2D] = []
var _glow_kind: Array[String] = []
var _lamp_glow: Sprite2D


## Where a room's lamp bulb sits, in the room's own pixels.
static func lamp_point(rect: Rect2, p_ppm: float) -> Vector2:
	return Vector2(rect.size.x * 0.5, p_ppm * 0.42)


func build(ship: Ship, r: Room, p_ppm: float) -> void:
	room = r
	ppm = p_ppm
	rect_px = Rect2(r.rect.position * ppm, r.rect.size * ppm)
	position = rect_px.position
	var k: float = ppm / ArtLib.ART_PPM
	floor_h_px = GRATING_ART_H * k
	lamp_pos = lamp_point(rect_px, ppm)
	_build_wall()
	_build_floor(ship)
	_build_props()
	_build_lamp()
	_build_links(ship)


func floor_line_y() -> float:
	return rect_px.size.y - floor_h_px * 0.7


func _build_wall() -> void:
	var name_key: String = str(WALL_ART.get(room.system, "bracing"))
	var tex: Texture2D = ArtLib.lit("ship", name_key + "_wall")
	if tex == null:
		return
	var k: float = ppm / ArtLib.ART_PPM
	var src: Vector2 = tex.get_size()
	var want: Vector2 = rect_px.size / k  # art pixels the room would span at the art scale
	var fill: float = maxf(want.x / src.x, want.y / src.y)
	if fill < 1.0:
		fill = 1.0
	var region_size: Vector2 = want / fill
	region_size = region_size.min(src)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2((src - region_size) * 0.5, region_size)
	s.scale = Vector2(rect_px.size.x / region_size.x, rect_px.size.y / region_size.y)
	s.self_modulate = Color(WALL_GAIN, WALL_GAIN, WALL_GAIN, 1.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.z_index = -5
	add_child(s)


func _build_floor(ship: Ship) -> void:
	var tex: Texture2D = ArtLib.lit("ship", "floor_grating")
	if tex == null:
		return
	var k: float = ppm / ArtLib.ART_PPM
	var gaps: Array[Vector2] = []
	for l: Link in ship.links:
		if l.kind == Link.Kind.HATCH and l.a == room.index:
			var cx: float = (l.x - room.rect.position.x) * ppm
			gaps.append(Vector2(cx - l.span_m * 0.5 * ppm, cx + l.span_m * 0.5 * ppm))
	gaps.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var cursor: float = 0.0
	for g: Vector2 in gaps:
		if g.x > cursor:
			_floor_span(tex, cursor, g.x, k)
		cursor = maxf(cursor, g.y)
	if cursor < rect_px.size.x:
		_floor_span(tex, cursor, rect_px.size.x, k)


func _floor_span(tex: Texture2D, x0: float, x1: float, k: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(x0 / k, 0.0, (x1 - x0) / k, GRATING_ART_H)
	s.scale = Vector2(k, k)
	s.position = Vector2(x0, rect_px.size.y - floor_h_px)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.z_index = -4
	add_child(s)


func _build_props() -> void:
	var list: Array = PROPS.get(room.system, [])
	var foot_y: float = floor_line_y()
	for entry: Array in list:
		var tname: String = str(entry[0])
		var tex: Texture2D = ArtLib.lit("ship", tname)
		if tex == null:
			continue
		var extra: float = minf(1.0, rect_px.size.y * 0.8 / (tex.get_size().y * ppm / ArtLib.ART_PPM))
		var half: float = tex.get_size().x * ppm / ArtLib.ART_PPM * extra * 0.5
		var x: float = clampf(rect_px.size.x * float(entry[1]), half + 4.0, rect_px.size.x - half - 4.0)
		var s: Sprite2D = ArtLib.prop("ship", tname, Vector2(x, foot_y), ppm, bool(entry[2]), extra)
		if s == null:
			continue
		s.z_index = -3
		add_child(s)
		if bool(entry[3]):
			var g: Sprite2D = ArtLib.glow_of(s, "ship", tname, 0.9)
			if g != null:
				g.z_index = -2
				add_child(g)
				_glows.append(g)
				_glow_kind.append(room.system)


func _build_lamp() -> void:
	var tex: Texture2D = ArtLib.lamp_texture()
	if tex == null:
		return
	var k: float = ppm / ArtLib.ART_PPM
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = Vector2(k, k)
	s.position = lamp_pos - Vector2(0.42 * 80.0, 0.72 * 80.0) * k
	s.z_index = -2
	add_child(s)
	var e: Texture2D = ArtLib.plain("ship", "lamp", "emission")
	if e != null:
		_lamp_glow = Sprite2D.new()
		_lamp_glow.texture = e
		_lamp_glow.centered = false
		_lamp_glow.scale = s.scale
		_lamp_glow.position = s.position
		_lamp_glow.material = ArtLib.additive_unshaded()
		_lamp_glow.z_index = -1
		ArtLib.set_glow(_lamp_glow, 1.1)
		add_child(_lamp_glow)


func _build_links(ship: Ship) -> void:
	var k: float = ppm / ArtLib.ART_PPM
	for l: Link in ship.links:
		if l.a != room.index:
			continue
		var x: float = (l.x - room.rect.position.x) * ppm
		if l.kind == Link.Kind.HATCH:
			var rim: Sprite2D = ArtLib.prop("ship", "hatch_rim", Vector2(x, rect_px.size.y - floor_h_px * 0.55), ppm)
			if rim != null:
				rim.z_index = 2
				add_child(rim)
			var lid := HatchLid.new()
			var sz: Vector2 = ShipHits.rim_size(l, ppm)
			lid.setup(l, sz)
			lid.position = Vector2(x, rect_px.size.y - floor_h_px * 0.55)
			add_child(lid)
			_lids.append(lid)
		else:
			var s: Sprite2D = ArtLib.prop("ship", "door_closed", Vector2(x, floor_line_y() + floor_h_px * 0.25), ppm)
			if s != null:
				var want_h: float = l.height_m * ppm
				var tex_h: float = s.texture.get_size().y * k
				s.scale = s.scale * (want_h / tex_h)
				s.position.y = floor_line_y() + floor_h_px * 0.25 - want_h
				s.position.x = x - s.texture.get_size().x * 0.5 * s.scale.x
				s.z_index = 2
				s.set_meta("link", l.index)
				add_child(s)
				_door_nodes.append(s)
				var lamp := DoorLamp.new()
				lamp.width = maxf(10.0, s.texture.get_size().x * s.scale.x * 0.7)
				lamp.door_size = Vector2(s.texture.get_size().x * s.scale.x, want_h)
				lamp.position = Vector2(x, s.position.y - 6.0)
				lamp.link_index = l.index
				add_child(lamp)
				_lamps.append(lamp)


var _door_nodes: Array[Sprite2D] = []
var _lids: Array[HatchLid] = []
var _lamps: Array[DoorLamp] = []
var _vent: RoomVent


## A shut hatch: a dark steel plate over the rim, drawn with plain shapes (there is no painted lid art):
## brass border, corner bolts and hazard-stripe bars, so a closed hatch reads at a glance. Feet-centred
## on the rim like the rim sprite.
class HatchLid extends Node2D:
	var link: Link
	var size: Vector2 = Vector2(60.0, 20.0)
	var _closed: bool = false

	func setup(l: Link, sz: Vector2) -> void:
		link = l
		size = sz
		z_index = 3
		visible = false

	func set_closed(on: bool) -> void:
		if on != _closed:
			_closed = on
			visible = on
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(-size.x * 0.5 - 2.0, -size.y - 2.0, size.x + 4.0, size.y + 4.0)
		draw_rect(r, Color(0.2, 0.21, 0.24), true)
		draw_rect(r.grow(-3.0), Color(0.13, 0.14, 0.16), true)
		var stripe: float = 7.0
		var x: float = r.position.x + 5.0
		while x < r.end.x - 9.0:
			draw_colored_polygon(PackedVector2Array([Vector2(x, r.end.y - 4.0), Vector2(x + stripe, r.end.y - 4.0), Vector2(x + stripe + 4.0, r.position.y + 4.0), Vector2(x + 4.0, r.position.y + 4.0)]), Color(0.78, 0.55, 0.12, 0.85))
			x += stripe * 2.2
		draw_rect(r, Color(0.7, 0.55, 0.28), false, 2.0)
		for p: Vector2 in [r.position + Vector2(3, 3), Vector2(r.end.x - 3, r.position.y + 3), r.end - Vector2(3, 3), Vector2(r.position.x + 3, r.end.y - 3)]:
			draw_circle(p, 1.8, Color(0.85, 0.8, 0.65))


## A lamp over each door: while the door is shut an amber bar and a bold amber frame round the slab;
## while it is open no slab (the door sprite is hidden) but a soft lit gap and a small green dot
## (L-DOR-F1: a blind viewer read the painted open door as a wall).
class DoorLamp extends Node2D:
	var width: float = 20.0
	var door_size: Vector2 = Vector2(20.0, 160.0)
	var link_index: int = 0
	var _closed: bool = false

	func _init() -> void:
		z_index = 4
		material = ArtLib.unshaded()

	func set_closed(on: bool) -> void:
		if on != _closed:
			_closed = on
			queue_redraw()

	func _draw() -> void:
		var slab := Rect2(-door_size.x * 0.5, 6.0, door_size.x, door_size.y)
		if _closed:
			draw_circle(Vector2.ZERO, width * 0.55, Color(1.0, 0.55, 0.1, 0.18))
			var r := Rect2(-width * 0.5, -3.0, width, 6.0)
			draw_rect(r, Color(1.0, 0.64, 0.16), true)
			draw_rect(r, Color(0.28, 0.13, 0.02), false, 1.0)
			draw_rect(slab, Color(1.0, 0.62, 0.16, 0.95), false, 3.0)
		else:
			draw_rect(slab.grow_individual(-2.0, 0.0, -2.0, 0.0), Color(1.0, 0.86, 0.6, 0.16), true)
			draw_circle(Vector2.ZERO, 2.5, Color(0.35, 0.85, 0.4, 0.85))


## Add the purge vent button and its draught (the player's tower only).
func set_vents(world: ShipWorld) -> void:
	_vent = RoomVent.new()
	_vent.setup(world.ship, room, ppm)
	add_child(_vent)


## True while a crew member is passing through this shut link: the door and its lamp show open for
## them, as doors do for crew (the sim still treats the link as shut for fire, heat and water).
static func crew_passing(ship: Ship, l: Link) -> bool:
	for c: CrewMember in ship.crew:
		if not c.alive or c.away or (c.room != l.a and c.room != l.b):
			continue
		if l.kind == Link.Kind.DOOR:
			if absf(c.pos.x - l.x) < 0.55:
				return true
		elif c.climbing and absf(c.pos.x - l.x) < 0.6:
			return true
	return false


## Per frame: door art follows Link.open (and swings open for passing crew), glows breathe with power.
func update(ship: Ship, r: Room, t: float, lamp_k: float, hz: HazardSim = null) -> void:
	for s: Sprite2D in _door_nodes:
		var l: Link = ship.links[int(s.get_meta("link"))]
		var shown_open: bool = l.open or crew_passing(ship, l)
		s.visible = not shown_open  # Open: no slab, the lamp draws a lit gap instead (DoorLamp).
		var name_key: String = "door_open" if shown_open else "door_closed"
		var tex: Texture2D = ArtLib.lit("ship", name_key)
		if tex != null and s.texture != tex:
			s.texture = tex
	for lid: HatchLid in _lids:
		lid.set_closed(not lid.link.open and not crew_passing(ship, lid.link))
	for lamp: DoorLamp in _lamps:
		lamp.set_closed(not ship.links[lamp.link_index].open and not crew_passing(ship, ship.links[lamp.link_index]))
	if _vent != null:
		_vent.update(t, hz)
	var power: float = 1.0
	if r.sys_max > 0:
		power = clampf(float(r.sys_power) / float(r.sys_max), 0.0, 1.0)
	if r.sys_failed:
		power *= 0.35
	for i: int in range(_glows.size()):
		var v: float = 1.0
		match _glow_kind[i]:
			"reactor":
				v = (0.55 + 0.45 * power) * (0.92 + 0.08 * sin(t * 3.1 + float(room.index)))
			"helm":
				v = 0.8 + 0.2 * sin(t * 1.7) * sin(t * 0.43 + 1.0)
				v *= 0.4 + 0.6 * clampf(float(r.sys_power) + 0.5, 0.0, 1.0)
			_:
				v = 0.7 + 0.3 * sin(t * 2.0 + float(room.index))
		ArtLib.set_glow(_glows[i], 0.9 * v)
	if _lamp_glow != null:
		ArtLib.set_glow(_lamp_glow, 1.1 * lamp_k)
