class_name RoomWater
extends RefCounted
## Flood water that reads as water (critic 004: "a bright blue placeholder box"). Murky groundwater:
## silty olive-brown, darker with depth, with a surface that sloshes with the tower's motion (a tilt
## from ShipView's spring plus waves that grow while the drill shakes the hull), suspended silt that
## drifts, a few bubbles, and foam where a breach pours in. Drawn unshaded like the other hazards, so
## the colors are written as they should look (the drawing node carries the boost).

const SILT: Color = Color(0.30, 0.29, 0.15)
const DEEP: Color = Color(0.07, 0.08, 0.045)
const CREST: Color = Color(0.74, 0.72, 0.5)
const FOAM: Color = Color(0.93, 0.92, 0.8)
const MIN_LEVEL_PX: float = 16.0
const MAX_TILT: float = 0.14  ## Surface slope at full slosh (px of height per px of width).


static func color(c: Color, a: float = 1.0) -> Color:
	return Color(c.r, c.g, c.b, a)


## The surface height offset (px, negative = up) at pixel column `x` inside the room.
static func wave(rp: Rect2, x: float, t: float, slosh: float, agit: float, index: int) -> float:
	var tilt: float = clampf(slosh, -1.0, 1.0) * MAX_TILT * (x - rp.get_center().x)
	var amp: float = 1.4 + 5.0 * clampf(agit, 0.0, 1.0)
	var swell: float = amp * (0.6 * sin(t * 2.1 + x * 0.045 + float(index)) + 0.4 * sin(t * 3.4 - x * 0.1))
	var chop: float = agit * 1.6 * sin(t * 17.0 + x * 0.31)
	return tilt + swell + chop


static func draw(n: Node2D, r: Room, rp: Rect2, ppm: float, t: float, slosh: float, agit: float, left: bool) -> void:
	if r.water_ml <= 0:
		return
	var fill: float = clampf(float(r.water_ml) / maxf(float(r.capacity_ml), 1.0), 0.0, 1.0)
	var lvl: float = clampf(maxf(r.level_m() * ppm, MIN_LEVEL_PX), 0.0, rp.size.y)
	var top: float = rp.end.y - lvl
	var steps: int = 36
	var crest := PackedVector2Array()
	for k: int in range(steps + 1):
		var x: float = rp.position.x + rp.size.x * float(k) / float(steps)
		var y: float = clampf(top + wave(rp, x, t, slosh, agit, r.index), rp.position.y + 2.0, rp.end.y - 3.0)
		crest.append(Vector2(x, y))
	var body := PackedVector2Array(crest)
	body.append(Vector2(rp.end.x, rp.end.y))
	body.append(Vector2(rp.position.x, rp.end.y))
	# A faint wash over the room so even a puddle reads, then the murky body.
	n.draw_rect(rp, color(Color(0.1, 0.11, 0.05), 0.05 + 0.12 * sqrt(fill)))
	var depth_k: float = clampf(lvl / maxf(rp.size.y, 1.0), 0.0, 1.0)
	# Murky: shallow water shows what is under it, deep water hides the machinery.
	n.draw_colored_polygon(body, color(SILT, 0.5 + 0.42 * sqrt(depth_k)))
	# Darker with depth: bands stacked from the floor up, each a little more opaque than the last.
	for i: int in range(8):
		var f: float = float(i + 1) / 8.0
		var hh: float = lvl * f
		var band := PackedVector2Array()
		band.append(Vector2(rp.position.x, rp.end.y - hh))
		band.append(Vector2(rp.end.x, rp.end.y - hh))
		band.append(Vector2(rp.end.x, rp.end.y))
		band.append(Vector2(rp.position.x, rp.end.y))
		n.draw_colored_polygon(band, color(DEEP, 0.04 + (0.06 + 0.1 * depth_k) * (1.0 - f)))
	_surface(n, crest)
	_ripples(n, rp, crest, t, r.index)
	_silt(n, rp, lvl, t, r.index)
	if r.breach_m2 > 0.0:
		_foam(n, rp, crest, t, left, clampf(r.breach_m2 * 30.0, 0.35, 1.0))


static func _surface(n: Node2D, crest: PackedVector2Array) -> void:
	n.draw_polyline(crest, color(Color(0.7, 0.68, 0.45), 0.28), 6.0)
	n.draw_polyline(crest, color(Color(0.62, 0.6, 0.4), 0.95), 2.5)
	var under := PackedVector2Array()
	for p: Vector2 in crest:
		under.append(Vector2(p.x, p.y + 6.0))
	n.draw_polyline(under, color(Color(0.45, 0.43, 0.25), 0.4), 2.0)


## Small bright ripples running along the surface line.
static func _ripples(n: Node2D, rp: Rect2, crest: PackedVector2Array, t: float, index: int) -> void:
	var cols: int = crest.size() - 1
	for i: int in range(7):
		var f: float = fposmod(t * 0.11 * (1.0 + 0.3 * float(i % 3)) + float(i) * 0.143 + float(index) * 0.17, 1.0)
		var k: int = clampi(roundi(f * float(cols)), 1, cols - 1)
		var p: Vector2 = crest[k]
		var half: float = 5.0 + 4.0 * float(i % 3)
		var a: float = 0.55 * sin(f * PI)
		n.draw_line(Vector2(p.x - half, p.y + 3.0), Vector2(p.x + half, p.y + 3.0), color(Color(0.95, 0.93, 0.7), a), 2.0)


## Silt drifting in the water and a few slow bubbles.
static func _silt(n: Node2D, rp: Rect2, lvl: float, t: float, index: int) -> void:
	if lvl < 18.0:
		return
	for i: int in range(9):
		var f: float = fposmod(t * 0.07 + float(i) * 0.113 + float(index) * 0.29, 1.0)
		var x: float = rp.position.x + rp.size.x * fposmod(float(i) * 0.41 + 0.17 * float(index) + 0.05 * sin(t * 0.6 + float(i)), 1.0)
		var y: float = rp.end.y - f * (lvl - 6.0)
		n.draw_circle(Vector2(x, y), 1.6 + float(i % 3), color(Color(0.5, 0.46, 0.3), 0.3))
	for i: int in range(4):
		var f2: float = fposmod(t * 0.3 + float(i) * 0.27 + float(index) * 0.31, 1.0)
		var bx: float = rp.position.x + rp.size.x * fposmod(float(i) * 0.37 + 0.11 * float(index), 1.0)
		n.draw_arc(Vector2(bx + 3.0 * sin(t * 2.0 + float(i)), rp.end.y - f2 * (lvl - 8.0)), 2.4, 0.0, TAU, 10, color(FOAM, 0.5 * (1.0 - f2)), 1.0)


## Foam where the breach jet lands (the near wall) and a trail of froth spreading out along the surface.
static func _foam(n: Node2D, rp: Rect2, crest: PackedVector2Array, t: float, left: bool, k: float) -> void:
	var dir: float = 1.0 if left else -1.0
	var wall_x: float = rp.position.x + 8.0 if left else rp.end.x - 8.0
	for i: int in range(9):
		var f: float = fposmod(t * 0.9 + float(i) / 9.0, 1.0)
		var x: float = wall_x + dir * (14.0 + f * rp.size.x * 0.4 * k)
		var idx: int = clampi(roundi((x - rp.position.x) / rp.size.x * float(crest.size() - 1)), 0, crest.size() - 1)
		var y: float = crest[idx].y - 1.0 + 1.5 * sin(t * 7.0 + float(i) * 2.1)
		var rad: float = (7.0 - 4.0 * f) * (0.6 + 0.4 * k)
		n.draw_circle(Vector2(x, y), rad, color(FOAM, 0.85 * (1.0 - f * 0.8)))
		n.draw_circle(Vector2(x + dir * 5.0, y + 3.0), rad * 0.6, color(FOAM, 0.5 * (1.0 - f)))
	# The churn right at the wall: bright and constant.
	var wi: int = 1 if left else crest.size() - 2
	for j: int in range(3):
		var jx: float = wall_x + dir * (4.0 + 7.0 * float(j))
		n.draw_circle(Vector2(jx, crest[wi].y + 2.0 * sin(t * 9.0 + float(j))), 9.0 - 2.0 * float(j), color(FOAM, 0.9))
