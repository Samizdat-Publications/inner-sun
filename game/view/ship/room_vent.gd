class_name RoomVent
extends Node2D
## A room's purge vent: the small button in a top corner (a grille with an arrow out to the bore, a
## click on it purges the room, see ShipPick), and while the vent is open a cold grey-blue draught
## pulled across the room toward it with a PURGING tag under the room name. A child of the room's
## RoomArt, so it draws in room pixels. Unshaded, so the colors are as written. View only: it reads
## HazardSim.is_purged and never changes anything.

const COLD: Color = Color(0.62, 0.8, 0.95)
const BUTTON_OFF: Color = Color(0.74, 0.62, 0.36)
const STREAKS: int = 9

var _ship: Ship
var _room: Room
var _ppm: float = 80.0
var _t: float = 0.0
var _purged: bool = false
var _last_purged: bool = false
var _font: Font


func setup(ship: Ship, r: Room, p_ppm: float) -> void:
	_ship = ship
	_room = r
	_ppm = p_ppm
	_font = ThemeDB.fallback_font
	z_index = 13
	material = ArtLib.unshaded()
	modulate = Color(1.7, 1.7, 1.7, 1.0)


func update(t: float, hz: HazardSim) -> void:
	_t = t
	_purged = hz != null and hz.is_purged(_room.index)
	if _purged or _purged != _last_purged:
		queue_redraw()
	_last_purged = _purged


## The button in room pixels.
func button() -> Rect2:
	var r: Rect2 = ShipHits.vent_rect(_ship, _room, _ppm)
	return Rect2(r.position - _room.rect.position * _ppm, r.size)


func _draw() -> void:
	var b: Rect2 = button()
	var size: Vector2 = _room.rect.size * _ppm
	if _purged:
		_draw_draught(b, size)
	_draw_button(b, _purged)
	if _purged:
		_draw_tag(size)


static func _draw_button_on(n: Node2D, b: Rect2, on: bool) -> void:
	var edge: Color = COLD if on else BUTTON_OFF
	if on:
		n.draw_circle(b.get_center(), b.size.x * 0.95, Color(COLD.r, COLD.g, COLD.b, 0.16))
		n.draw_circle(b.get_center(), b.size.x * 0.68, Color(COLD.r, COLD.g, COLD.b, 0.22))
	n.draw_rect(b, Color(0.03, 0.05, 0.07, 0.9), true)
	n.draw_rect(b, edge, false, 2.0)
	var inner: Rect2 = b.grow(-5.0)
	var slats: int = 4
	for i: int in range(slats):
		var y: float = inner.position.y + inner.size.y * (float(i) + 0.5) / float(slats)
		n.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(edge.r, edge.g, edge.b, 0.95 if on else 0.7), 2.0)
	# The arrow out: a small chevron on the grille, pointing up and out to the bore.
	var c: Vector2 = b.get_center()
	var a: float = b.size.x * 0.2
	var tri := PackedVector2Array([c + Vector2(0.0, -a * 1.1), c + Vector2(a, a * 0.5), c + Vector2(-a, a * 0.5)])
	n.draw_colored_polygon(tri, Color(1.0, 1.0, 1.0, 0.9) if on else Color(edge.r, edge.g, edge.b, 0.45))


func _draw_button(b: Rect2, on: bool) -> void:
	_draw_button_on(self, b, on)


## Soft particles drifting from across the room into the vent, with short trails, over a faint chill.
func _draw_draught(b: Rect2, size: Vector2) -> void:
	var target: Vector2 = b.get_center()
	draw_rect(Rect2(Vector2.ZERO, size), Color(COLD.r, COLD.g, COLD.b, 0.12), true)
	for i: int in range(STREAKS):
		var sx: float = size.x * (0.08 + 0.84 * fposmod(float(i) * 0.618034, 1.0))
		var sy: float = size.y * (0.22 + 0.62 * fposmod(float(i) * 0.381966 + 0.17, 1.0))
		var f: float = fposmod(_t * 0.5 + float(i) / float(STREAKS), 1.0)
		var e: float = f * f
		var at: Vector2 = Vector2(sx, sy).lerp(target, e)
		var back: Vector2 = Vector2(sx, sy).lerp(target, maxf(0.0, e - 0.12))
		var a: float = sin(PI * f) * 0.85
		draw_line(back, at, Color(COLD.r, COLD.g, COLD.b, a * 0.7), 3.0)
		draw_circle(at, 4.5, Color(COLD.r, COLD.g, COLD.b, a * 0.35))
		draw_circle(at, 2.2, Color(0.85, 0.95, 1.0, a))


## "PURGING" in small caps on the label's side, under the room name chip.
func _draw_tag(size: Vector2) -> void:
	var text: String = "PURGING"
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
	var right: bool = not ShipHits.vent_on_right(_ship, _room, _ppm)
	var x: float = size.x - w - 8.0 if right else 8.0
	var y: float = 8.0 + 38.0 + 3.0
	draw_rect(Rect2(x, y, w, 18.0), Color(0.02, 0.03, 0.04, 0.78), true)
	draw_rect(Rect2(x, y, 3.0, 18.0), COLD, true)
	draw_string(_font, Vector2(x + 8.0, y + 13.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.93, 1.0))
