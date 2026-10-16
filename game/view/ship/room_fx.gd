class_name RoomFx
extends RefCounted
## Draw callbacks for a room's hazards and readouts, so hazards read at a glance in a screenshot:
## a filled translucent water body with a moving surface, a warm shimmer above about 50 C, a pulsing
## red rim, a small label chip in a corner clear of ladders, the ladder art and falling water.
## All of it is drawn unshaded so colors are written as they should look.

const HEAT_FROM_C: float = 50.0
const LADDER_HALF_PX: float = 20.0


## The color as it should look. Everything here is drawn unshaded; the drawing nodes carry a boost
## (ShipView._fn) tuned against screenshots, because the CanvasModulate darkens them too.
static func lit_color(c: Color, a: float = 1.0) -> Color:
	return Color(c.r, c.g, c.b, a)


static func heat_k(r: Room) -> float:
	return clampf((r.temp_c() - HEAT_FROM_C) / 70.0, 0.0, 1.0)


## Additive warm tint and rising shimmer lines over the whole room when it is hot.
static func draw_heat(n: Node2D, r: Room, rp: Rect2, t: float) -> void:
	var h: float = heat_k(r)
	if h <= 0.0:
		return
	n.draw_rect(rp, lit_color(Color(0.6, 0.2, 0.04), 0.1 + 0.3 * h))
	var lines: int = 6
	for i: int in range(lines):
		var f: float = fposmod(t * (0.22 + 0.1 * h) + float(i) / float(lines), 1.0)
		var y: float = rp.end.y - f * rp.size.y
		var pts := PackedVector2Array()
		for k: int in range(17):
			var x: float = rp.position.x + rp.size.x * float(k) / 16.0
			pts.append(Vector2(x, y + 3.0 * sin(t * 3.0 + x * 0.09 + float(i) * 1.7)))
		n.draw_polyline(pts, lit_color(Color(1.0, 0.55, 0.2), (1.0 - f) * 0.28 * h), 2.0)


## A pulsing red rim when the room has fire, a breach or deep water.
static func draw_alarm_rim(n: Node2D, r: Room, rp: Rect2, t: float) -> void:
	var hazard: bool = r.fire > 0.0 or r.breach_m2 > 0.0 or r.level_m() > 0.3
	if not hazard:
		return
	var pulse: float = 0.5 + 0.5 * sin(t * 6.0 + float(r.index))
	n.draw_rect(rp.grow(-3.0), lit_color(Color(1.0, 0.15, 0.08), 0.35 + 0.45 * pulse), false, 3.0)


## A filled translucent water body with two moving surface waves, a bright crest and bubbles.
static func draw_water(n: Node2D, r: Room, rp: Rect2, ppm: float, t: float) -> void:
	if r.water_ml <= 0:
		return
	var lvl: float = clampf(maxf(r.level_m() * ppm, 7.0), 0.0, rp.size.y)
	var top: float = rp.end.y - lvl
	var pts := PackedVector2Array()
	var crest := PackedVector2Array()
	var steps: int = 32
	for k: int in range(steps + 1):
		var x: float = rp.position.x + rp.size.x * float(k) / float(steps)
		var wave: float = 2.4 * sin(t * 2.3 + x * 0.05) + 1.4 * sin(t * 3.7 - x * 0.11)
		crest.append(Vector2(x, top + wave))
	pts.append_array(crest)
	pts.append(Vector2(rp.end.x, rp.end.y))
	pts.append(Vector2(rp.position.x, rp.end.y))
	n.draw_colored_polygon(pts, lit_color(Color(0.1, 0.45, 0.6), 0.5))
	# Deeper half darker.
	var mid: float = top + lvl * 0.45
	if lvl > 14.0:
		var deep := PackedVector2Array([Vector2(rp.position.x, mid), Vector2(rp.end.x, mid), Vector2(rp.end.x, rp.end.y), Vector2(rp.position.x, rp.end.y)])
		n.draw_colored_polygon(deep, lit_color(Color(0.02, 0.14, 0.26), 0.3))
	n.draw_polyline(crest, lit_color(Color(0.45, 0.72, 0.8), 0.9), 3.0)
	var under := PackedVector2Array()
	for p: Vector2 in crest:
		under.append(Vector2(p.x, p.y + 7.0 + 1.5 * sin(t * 1.9 + p.x * 0.08)))
	n.draw_polyline(under, lit_color(Color(0.3, 0.6, 0.72), 0.35), 2.0)
	if lvl > 18.0:
		for i: int in range(6):
			var f: float = fposmod(t * 0.35 + float(i) * 0.173 + float(r.index) * 0.31, 1.0)
			var bx: float = rp.position.x + rp.size.x * fposmod(float(i) * 0.37 + 0.11 * float(r.index), 1.0)
			var by: float = rp.end.y - f * (lvl - 8.0)
			n.draw_arc(Vector2(bx + 3.0 * sin(t * 2.0 + float(i)), by), 2.5, 0.0, TAU, 10, lit_color(Color(0.5, 0.75, 0.8), 0.6 * (1.0 - f)), 1.0)


## The corner for a room's label chip: left unless a ladder from above comes down there, then right.
static func label_on_right(ship: Ship, r: Room, ppm: float, width_px: float) -> bool:
	var rw: float = r.rect.size.x * ppm
	for l: Link in ship.links:
		if l.kind == Link.Kind.HATCH and l.b == r.index:
			var lx: float = (l.x - r.rect.position.x) * ppm
			if lx - LADDER_HALF_PX < 10.0 + width_px + 4.0:
				return true
	return false


## A small crisp chip: the room name and its readout, in a corner clear of ladders.
static func draw_label(n: Node2D, ship: Ship, r: Room, rp: Rect2, ppm: float, font: Font, t: float) -> void:
	var name_text: String = r.name.to_upper()
	var line: String = "%d C" % roundi(r.temp_c())
	if r.water_ml > 0:
		line += "  %.1f m" % r.level_m()
	if r.fire > 0.0:
		line += "  FIRE"
	if r.breach_m2 > 0.0:
		line += "  BREACH"
	var w1: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var w2: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var w: float = maxf(w1, w2) + 10.0
	var right: bool = label_on_right(ship, r, ppm, w)
	var x: float = rp.end.x - w - 8.0 if right else rp.position.x + 8.0
	var y: float = rp.position.y + 8.0
	var hot: bool = r.fire > 0.0 or r.breach_m2 > 0.0
	n.draw_rect(Rect2(x, y, w, 28.0), Color(0.02, 0.02, 0.03, 0.62))
	n.draw_rect(Rect2(x, y, 2.0, 28.0), lit_color(Color(1.0, 0.5, 0.15) if hot else Color(0.8, 0.62, 0.3), 1.0))
	n.draw_string(font, Vector2(x + 6.0, y + 12.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, lit_color(Color(0.92, 0.9, 0.82)))
	var warm: Color = Color(1.0, 0.45, 0.15) if hot else Color(0.95, 0.72, 0.3)
	n.draw_string(font, Vector2(x + 6.0, y + 24.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lit_color(warm))


## The room outline: thin dark steel so the painted walls meet each other cleanly.
static func draw_frame(n: Node2D, rp: Rect2) -> void:
	n.draw_rect(rp, Color(0.1, 0.105, 0.12), false, 5.0)


## Water pouring down a hatch.
static func draw_ladder_flow(n: Node2D, ship: Ship, world: ShipWorld, li: int, ppm: float, t: float) -> void:
	var l: Link = ship.links[li]
	var flow: float = world.hazards.link_flow_ml_s[li] / Room.ML_PER_M3
	if flow <= 0.0:
		return
	var lower: Room = ship.rooms[l.b]
	var top_y: float = ship.rooms[l.a].floor_y() * ppm
	var bottom_y: float = lower.floor_y() * ppm - minf(lower.level_m() * ppm, lower.rect.size.y * ppm)
	var w: float = clampf(flow * 40.0, 3.0, 20.0)
	n.draw_rect(Rect2(l.x * ppm - w * 0.5, top_y, w, bottom_y - top_y), lit_color(Color(0.12, 0.38, 0.5), 0.5))
	for i: int in range(3):
		var f: float = fposmod(t * 1.6 + float(i) * 0.33, 1.0)
		n.draw_line(Vector2(l.x * ppm + (float(i) - 1.0) * w * 0.25, top_y), Vector2(l.x * ppm + (float(i) - 1.0) * w * 0.25, top_y + (bottom_y - top_y) * f), lit_color(Color(0.45, 0.7, 0.78), 0.7), 1.5)


## Name tags and HP pips for every living crew member, stacked so no two tags overlap.
static func draw_tags(n: Node2D, ship: Ship, sprites: Array[CrewSprite], ppm: float, font: Font) -> void:
	var order: Array[int] = []
	for i: int in range(sprites.size()):
		if ship.crew[i].alive:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return sprites[a].position.x < sprites[b].position.x)
	var placed: Array[Rect2] = []
	for i: int in order:
		var c: CrewMember = ship.crew[i]
		var spr: CrewSprite = sprites[i]
		var tw: float = font.get_string_size(c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
		var tag_w: float = maxf(tw, 34.0)
		var rect := Rect2(spr.position.x - tag_w * 0.5, spr.position.y + spr.head_top_px() - 24.0, tag_w, 19.0)
		var guard: int = 0
		var moved: bool = true
		while moved and guard < 8:
			moved = false
			guard += 1
			for p: Rect2 in placed:
				if p.grow(1.0).intersects(rect):
					rect.position.y = p.position.y - rect.size.y - 1.0
					moved = true
		placed.append(rect)
		n.draw_rect(rect, Color(0.02, 0.02, 0.03, 0.6))
		n.draw_string(font, rect.position + Vector2(4.0, 10.0), c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, lit_color(Color(0.95, 0.93, 0.85)))
		var frac: float = clampf(c.hp / CrewMember.MAX_HP, 0.0, 1.0)
		var pips: int = 5
		var lit_n: int = ceili(frac * float(pips) - 0.001)
		var col: Color = Color(0.35, 0.85, 0.4) if frac > 0.6 else (Color(0.95, 0.75, 0.2) if frac > 0.3 else Color(0.95, 0.25, 0.2))
		var pw: float = (rect.size.x - 6.0) / float(pips)
		for k: int in range(pips):
			var pr := Rect2(rect.position.x + 3.0 + pw * float(k), rect.position.y + 13.0, pw - 1.5, 3.0)
			n.draw_rect(pr, lit_color(col) if k < lit_n else Color(0.25, 0.25, 0.28, 0.7))
