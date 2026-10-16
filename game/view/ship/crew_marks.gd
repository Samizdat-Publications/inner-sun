class_name CrewMarks
extends Node2D
## What makes a crew member pop out of the room art (critic 004: "crew members are dark smudges
## against dark, noisy backgrounds"): a soft backlight halo behind the figure, a bright uniform
## accent (a chest harness in a colour of its own), and a pulsing ring on the floor and a bracket
## around the figure when selected. Drawn unshaded and additive, so the colors are what shows.
## The figure's centre is `h * 0.5` above the node's origin (the crew member's feet).

const ACCENTS: Array[Color] = [
	Color(1.0, 0.62, 0.12), Color(0.2, 0.85, 1.0), Color(0.55, 1.0, 0.3), Color(1.0, 0.3, 0.7), Color(1.0, 0.95, 0.3),
]
const ENEMY_ACCENT: Color = Color(1.0, 0.25, 0.18)

var height_px: float = 144.0
var accent: Color = ACCENTS[0]
var selected: bool = false
var alive: bool = true
var face: float = 1.0
var _halo: Sprite2D
var _draw_node: _Marks
var _t: float = 0.0


## The additive layer that draws the harness, the ring and the bracket.
class _Marks extends Node2D:
	var owner_marks: CrewMarks

	func _draw() -> void:
		if owner_marks != null:
			owner_marks._paint(self)


func setup(h_px: float, index: int, enemy: bool) -> void:
	height_px = h_px
	accent = ENEMY_ACCENT if enemy else ACCENTS[index % ACCENTS.size()]
	_halo = Sprite2D.new()
	_halo.texture = ShipView.radial_texture(64)
	_halo.material = ArtLib.additive_unshaded()
	_halo.position = Vector2(0.0, -h_px * 0.52)
	_halo.scale = Vector2(h_px * 0.0125, h_px * 0.0215)
	_halo.z_index = -1
	add_child(_halo)
	_draw_node = _Marks.new()
	_draw_node.owner_marks = self
	_draw_node.material = ArtLib.additive_unshaded()
	_draw_node.z_index = 3
	add_child(_draw_node)


func update(delta: float, p_selected: bool, p_alive: bool, p_face: float) -> void:
	_t += delta
	selected = p_selected
	alive = p_alive
	face = p_face
	_halo.visible = alive
	var pulse: float = 0.5 + 0.5 * sin(_t * 4.5)
	var k: float = 0.95 + (0.3 + 0.15 * pulse if selected else 0.0)
	_halo.modulate = Color(accent.r * k, accent.g * k, accent.b * k, 1.0)
	_draw_node.queue_redraw()


func _paint(n: Node2D) -> void:
	if not alive:
		return
	var h: float = height_px
	var pulse: float = 0.5 + 0.5 * sin(_t * 4.5)
	# The harness: a bright strap across the chest with a buckle, on the torso whichever way it faces.
	var chest: float = -h * 0.66
	var w: float = h * 0.17
	n.draw_rect(Rect2(-w * 0.5, chest, w, h * 0.045), Color(accent.r, accent.g, accent.b, 0.95))
	n.draw_rect(Rect2(-w * 0.12 + face * w * 0.12, chest - h * 0.006, w * 0.24, h * 0.057), Color(1.0, 1.0, 1.0, 0.9))
	if selected:
		var rx: float = h * (0.36 + 0.03 * pulse)
		var ry: float = rx * 0.26
		var pts := PackedVector2Array()
		for i: int in range(33):
			var a: float = TAU * float(i) / 32.0
			pts.append(Vector2(cos(a) * rx, sin(a) * ry - 2.0))
		n.draw_polyline(pts, Color(accent.r, accent.g, accent.b, 0.9), 4.0)
		n.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.45), 1.5)
		var arm: float = h * 0.1
		var half_w: float = h * 0.25
		var top: float = -h * 1.06
		var col := Color(accent.r, accent.g, accent.b, 0.55 + 0.35 * pulse)
		for sx: float in [-1.0, 1.0]:
			n.draw_line(Vector2(sx * half_w, top), Vector2(sx * half_w, top + arm), col, 3.0)
			n.draw_line(Vector2(sx * half_w, top), Vector2(sx * (half_w - arm), top), col, 3.0)
			n.draw_line(Vector2(sx * half_w, -2.0), Vector2(sx * half_w, -2.0 - arm), col, 3.0)
