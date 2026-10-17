class_name DouseLayer
extends Node2D
## The DOUSE button on every burning room of the player's tower, and the coolant spray when it works.
## A child of the ShipView (ship-local pixels). The buttons are drawn at a fixed size on screen (they
## are scaled by the inverse of the camera zoom), click them or press F for the worst fire; either way
## it is one command, {"type": "douse", "room": id}. A button that cannot work says why, with the sim's
## own reason from `Systems.douse_ready`. The spray follows the "doused" event.
##
## Main asks `room_at(screen_point)` before it treats a left click as a crew order.

const BTN_W: float = 176.0
const BTN_H: float = 34.0
const FIRE_MIN: float = 0.05  ## Rooms burning less than this get no button (the sim's own floor).
const REASONS: Dictionary = {
	"not now": "COOLING DOWN", "no coolant": "NO COOLANT", "venting": "VENTING",
	"no such room": "", "no fire": "",
}

var sim: Sim = null
var view: ShipView = null
var ppm: float = 80.0
var _t: float = 0.0
var _seen: int = 0
var _sprays: Dictionary = {}  ## room index -> CPUParticles2D
var _pacer: RedrawPacer = RedrawPacer.new()
var _was_burning: bool = false


func setup(p_sim: Sim, p_view: ShipView, p_ppm: float) -> void:
	view = p_view
	ppm = p_ppm
	z_index = 40
	material = ArtLib.unshaded()
	# The dark ambient still multiplies unshaded items: lift by its inverse (as PickupLayer does).
	modulate = Color(1.0 / RockView.AMBIENT.r, 1.0 / RockView.AMBIENT.g, 1.0 / RockView.AMBIENT.b, 1.0)
	bind(p_sim)


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_seen = sim.events.size() if sim != null else 0
	queue_redraw()


## The burning rooms of the player's tower, worst fire first (room ids).
static func burning(s: Sim) -> Array[String]:
	var rooms: Array[Room] = []
	for r: Room in s.ship.rooms:
		if r.fire > FIRE_MIN:
			rooms.append(r)
	rooms.sort_custom(func(a: Room, b: Room) -> bool:
		if a.fire != b.fire:
			return a.fire > b.fire
		return a.index < b.index)
	var out: Array[String] = []
	for r: Room in rooms:
		out.append(r.id)
	return out


## The worst fire's room id, or "".
static func worst(s: Sim) -> String:
	var all: Array[String] = burning(s)
	return all[0] if not all.is_empty() else ""


## Why a douse cannot be ordered, in words for the button ("" when it can).
static func reason_text(s: Sim, why: String) -> String:
	if why.is_empty():
		return ""
	if why == "power coolant":
		var key: String = AlertsStrip.power_key(s.ship, s.ship.room_with_system("coolant"))
		return "POWER COOLANT (%s)" % key if not key.is_empty() else "POWER COOLANT"
	if why == "not now":
		return "COOLING DOWN %d S" % ceili(float(s.systems.douse_cooldown_ticks) / Sim.TICK_HZ)
	return str(REASONS.get(why, why.to_upper()))


## The button of a room in ship-local pixels, drawn `k` times larger than the ship's scale (k is the
## inverse of the camera zoom, so it keeps its size on screen).
static func button_rect(room_px: Rect2, k: float) -> Rect2:
	var w: float = BTN_W * k
	var h: float = BTN_H * k
	return Rect2(room_px.get_center().x - w * 0.5, room_px.position.y + 10.0 * k, w, h)


func _zoom() -> float:
	return maxf(0.2, get_viewport().get_canvas_transform().get_scale().x)


## The room whose DOUSE button is under a screen point, or "". The reason is not checked here.
func room_at(screen_pos: Vector2) -> String:
	if sim == null or view == null:
		return ""
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_pos
	var k: float = 1.0 / _zoom()
	for id: String in burning(sim):
		var ri: int = sim.ship.room_index(id)
		if button_rect(view.room_rect_px(sim.ship.rooms[ri]), k).has_point(local):
			return id
	return ""


func _process(delta: float) -> void:
	_t += delta
	if sim == null:
		return
	var n: int = sim.events.size()
	if n < _seen:
		_seen = 0
	for i: int in range(_seen, n):
		var e: Dictionary = sim.events[i]
		if str(e.get("kind", "")) == "doused":
			_spray(str(e.get("room", "")))
	_seen = n
	if not burning(sim).is_empty() or _was_burning:
		if _pacer.due():
			queue_redraw()
	_was_burning = not burning(sim).is_empty()


func _spray(room_id: String) -> void:
	var ri: int = sim.ship.room_index(room_id)
	if ri < 0 or view == null:
		return
	var rp: Rect2 = view.room_rect_px(sim.ship.rooms[ri])
	var p: CPUParticles2D = _sprays.get(ri) as CPUParticles2D
	if p == null:
		p = _make_spray()
		add_child(p)
		_sprays[ri] = p
	p.position = Vector2(rp.get_center().x, rp.position.y + 8.0)
	p.emission_rect_extents = Vector2(rp.size.x * 0.4, 3.0)
	p.restart()
	p.emitting = true


func _make_spray() -> CPUParticles2D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.35, 0.55, 0.62, 0.95))
	ramp.set_color(1, Color(0.18, 0.26, 0.32, 0.0))
	ramp.add_point(0.5, Color(0.28, 0.42, 0.5, 0.7))
	var p := CPUParticles2D.new()
	p.texture = ShipView.radial_texture(20)
	p.material = ArtLib.additive_unshaded()
	p.amount = 110
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.25
	p.emitting = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0, 1)
	p.spread = 35.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2
	p.color_ramp = ramp
	return p


func _draw() -> void:
	if sim == null or view == null:
		return
	var ids: Array[String] = burning(sim)
	if ids.is_empty():
		return
	var k: float = 1.0 / _zoom()
	var font: Font = UiTheme.mono()
	for idx: int in range(ids.size()):
		var ri: int = sim.ship.room_index(ids[idx])
		var rect: Rect2 = button_rect(view.room_rect_px(sim.ship.rooms[ri]), k)
		var why: String = sim.systems.douse_ready(sim, ids[idx])
		var ok: bool = why.is_empty()
		var pulse: float = UiTheme.pulse(_t, 2.4)
		var fill: Color = Color(0.10, 0.22, 0.30).lerp(Color(0.14, 0.34, 0.44), pulse) if ok else Color(0.20, 0.07, 0.06)
		var edge: Color = Color(0.45, 0.85, 1.0) if ok else UiTheme.ALARM
		draw_rect(rect, fill, true)
		draw_rect(rect, edge, false, 3.0 * k)
		var label: String = ("DOUSE (F)" if idx == 0 else "DOUSE") if ok else reason_text(sim, why)
		var fs: int = maxi(8, roundi(17.0 * k))
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var pos := Vector2(rect.get_center().x - w * 0.5, rect.position.y + rect.size.y * 0.5 + float(fs) * 0.34)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT if ok else Color(1.0, 0.7, 0.6))
