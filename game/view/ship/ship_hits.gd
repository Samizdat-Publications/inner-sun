class_name ShipHits
extends RefCounted
## Where things sit in the cutaway, in the ship view's own pixels (ship meters times ppm, origin the
## ship's top-left), and which one a point lands on: a door, a hatch rim, a room's vent button, a crew
## figure. Pure geometry, no nodes: the clicks (ShipPick) and the drawing (RoomVent, RoomArt) share it.

const VENT_PX: float = 28.0  ## The vent button's side at 80 px per meter.
const FIGURE_M: float = 1.8
const FIGURE_HALF_M: float = 0.3


static func foot_lift(ppm: float) -> float:
	return RoomArt.GRATING_ART_H * 0.7 * ppm / ArtLib.ART_PPM


## A door's click box: its sprite (the closed art's proportions), standing on the room's floor.
static func door_rect(ship: Ship, l: Link, ppm: float) -> Rect2:
	var r: Room = ship.rooms[l.a]
	var k: float = ppm / ArtLib.ART_PPM
	var floor_h: float = RoomArt.GRATING_ART_H * k
	var h: float = l.height_m * ppm
	var w: float = 0.35 * ppm
	var tex: Texture2D = ArtLib.lit("ship", "door_closed")
	if tex != null:
		w = tex.get_size().x * h / tex.get_size().y
	w = maxf(w, 0.4 * ppm)
	var bottom: float = r.rect.end.y * ppm - floor_h * 0.45
	return Rect2(l.x * ppm - w * 0.5, bottom - h, w, h)


## The rim sprite's size in view pixels (the lid is drawn over the same box).
static func rim_size(l: Link, ppm: float) -> Vector2:
	var k: float = ppm / ArtLib.ART_PPM
	var tex: Texture2D = ArtLib.lit("ship", "hatch_rim")
	if tex != null:
		return tex.get_size() * k
	return Vector2(l.span_m * ppm, 0.22 * ppm)


## A hatch's click box: its rim sprite, a few px larger.
static func hatch_rect(ship: Ship, l: Link, ppm: float) -> Rect2:
	var r: Room = ship.rooms[l.a]
	var k: float = ppm / ArtLib.ART_PPM
	var floor_h: float = RoomArt.GRATING_ART_H * k
	var foot: float = r.rect.end.y * ppm - floor_h * 0.55
	var sz: Vector2 = rim_size(l, ppm)
	return Rect2(l.x * ppm - sz.x * 0.5 - 4.0, foot - sz.y - 4.0, sz.x + 8.0, sz.y + 8.0)


## Whether a room's vent button sits at the top right (true) or top left: opposite its label chip.
static func vent_on_right(ship: Ship, r: Room, ppm: float) -> bool:
	return not RoomFx.label_on_right(ship, r, ppm, 130.0)


static func vent_rect(ship: Ship, r: Room, ppm: float) -> Rect2:
	var side: float = VENT_PX * ppm / 80.0
	var rp := Rect2(r.rect.position * ppm, r.rect.size * ppm)
	var x: float = rp.end.x - side - 8.0 if vent_on_right(ship, r, ppm) else rp.position.x + 8.0
	return Rect2(x, rp.position.y + 8.0, side, side)


## A crew figure's click box, feet at c.pos.
static func figure_rect(c: CrewMember, ppm: float) -> Rect2:
	var feet: Vector2 = c.pos * ppm + Vector2(0.0, -foot_lift(ppm))
	return Rect2(feet.x - FIGURE_HALF_M * ppm, feet.y - FIGURE_M * ppm, FIGURE_HALF_M * 2.0 * ppm, FIGURE_M * ppm + 4.0)


## The link a point lands on as {"link": index, "what": "door" | "hatch"}, or {}.
static func link_at(ship: Ship, p: Vector2, ppm: float) -> Dictionary:
	for l: Link in ship.links:
		var rect: Rect2 = hatch_rect(ship, l, ppm) if l.kind == Link.Kind.HATCH else door_rect(ship, l, ppm)
		if rect.has_point(p):
			return {"link": l.index, "what": "hatch" if l.kind == Link.Kind.HATCH else "door"}
	return {}


## The room whose vent button the point lands on, or -1.
static func vent_at(ship: Ship, p: Vector2, ppm: float) -> int:
	for r: Room in ship.rooms:
		if vent_rect(ship, r, ppm).grow(3.0).has_point(p):
			return r.index
	return -1


## The live, aboard crew member whose figure the point lands on (the nearest if figures overlap), or "".
static func crew_at(ship: Ship, p: Vector2, ppm: float) -> String:
	var best: String = ""
	var best_d: float = INF
	for c: CrewMember in ship.crew:
		if not c.alive or c.away:
			continue
		var rect: Rect2 = figure_rect(c, ppm)
		if rect.has_point(p):
			var d: float = absf(p.x - rect.get_center().x)
			if d < best_d:
				best_d = d
				best = c.id
	return best


## Ids of the live, aboard crew whose figure's centre is inside the box (view pixels).
static func crew_in(ship: Ship, box: Rect2, ppm: float) -> Array[String]:
	var out: Array[String] = []
	for c: CrewMember in ship.crew:
		if c.alive and not c.away and box.has_point(figure_rect(c, ppm).get_center()):
			out.append(c.id)
	return out
