class_name ShipView
extends Node2D
## Builds and updates the cutaway from the sim's state: painted rooms (RoomArt), hull plating, the
## drill crown, ladders, painted crew (CrewSprite), water, fire, heat and the lights that make it
## read. Godot lets one canvas item take only about 15 lights, so everything is split into small
## per-room, per-crew and per-strip nodes (each only meets nearby lights) and idle lights are
## disabled, not dimmed. Ship space is meters with y down; this node's origin is the ship's top-left.
## Draw order (z): rock -10, wall -5, floor -4, props -3, lamp -2, heat 0, ladders 1, doors and hatch
## rims 2, room frame 3, water 3 (under the crew), hull 3, fire (RoomFire: scorch -2, haze 4, flames 5), crew 6 (limbs 4 to 8), labels 12, tags 14.

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
var _fire: RoomFire = RoomFire.new()
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
var selected_ids: Array[String] = []  ## Set by ShipPick: every selected crew member gets the ring.


func setup(p_sim: Sim, p_world: ShipWorld, p_ppm: float) -> void:
	sim = p_sim
	world = p_world
	ppm = p_ppm
	_font = ThemeDB.fallback_font
	_enemy = sim != null and world != sim.player
	_radial = ShipView.radial_texture(256)
	_foot_lift = RoomArt.GRATING_ART_H * 0.7 * ppm / ArtLib.ART_PPM
	ShipViewBuild.rock(self)
	_build_rooms()
	_build_ladders()
	ShipViewBuild.hull(self)
	ShipViewBuild.occluders(self)
	_build_lights()
	_fire.build(self, world.ship, ppm, _foot_lift, _radial)
	ShipViewBuild.sprays(self)
	ShipViewCrown.build(self)
	_build_crew()
	_build_tags()
	if _enemy:
		_fn(4, func(n: Node2D) -> void: ShipViewBuild.draw_rust(self, n), 1, 1.7)
		_fn(4, func(n: Node2D) -> void: ShipViewBuild.draw_markers(self, n), 2, 2.0)


## Follow a new sim with the same ship layout (a new run of the same ship): the nodes stay.
func rebind(p_sim: Sim, p_world: ShipWorld) -> void:
	sim = p_sim
	world = p_world
	_fire.reset()
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


func _build_rooms() -> void:
	var ship: Ship = world.ship
	for r: Room in ship.rooms:
		var art := RoomArt.new()
		art.build(ship, r, ppm)
		add_child(art)
		_room_art.append(art)
		if _enemy:
			art.modulate = Color(0.9, 0.96, 1.1)
		else:
			art.set_vents(world)
		var ri: int = r.index
		_fn(0, func(n: Node2D) -> void: RoomFx.draw_heat(n, world.ship.rooms[ri], room_rect_px(world.ship.rooms[ri]), _time), 2, 2.0)
		_fn(3, func(n: Node2D) -> void: RoomFx.draw_frame(n, room_rect_px(world.ship.rooms[ri])))
		var left: bool = r.rect.get_center().x < ship_size_m().x * 0.5
		_fn(3, func(n: Node2D) -> void: RoomWater.draw(n, world.ship.rooms[ri], room_rect_px(world.ship.rooms[ri]), ppm, _time, _slosh, _agit, left), 1, 1.8)
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


func _build_lights() -> void:
	for r: Room in world.ship.rooms:
		var rp: Rect2 = room_rect_px(r)
		var bulb: Vector2 = rp.position + RoomArt.lamp_point(rp, ppm)
		_lamps.append(_light(bulb + Vector2(0, ppm * 0.1), ENEMY_LAMP if _enemy else Color(1.0, 0.84, 0.62), LAMP_ENERGY, rp.size.x * 0.85, true, 200.0))
		_alarms.append(_light(Vector2(rp.position.x + ppm * 0.4, rp.position.y + ppm * 0.3), Color(1.0, 0.1, 0.06), 0.0, rp.size.x * 0.9, true, 160.0))


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


var frozen: bool = false: set = set_frozen  ## The visible pause: no time passes in this node's animations.


func set_frozen(on: bool) -> void:
	if frozen == on:
		return
	frozen = on
	WorldFreeze.apply(self, on)


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_update(WorldFreeze.dt(frozen, delta))
	if frozen:
		WorldFreeze.apply(self, true)
	PerfRecorder.span(PerfRecorder.SPAN_SHIP, Time.get_ticks_usec() - t0)


func _update(delta: float) -> void:
	_time += delta
	if delta > 0.0:
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
		_sprays[i].emitting = r.breach_m2 > 0.0
		_sprays[i].speed_scale = clampf(0.8 + r.breach_m2 * 8.0, 0.8, 1.6)
		var lamp_k: float = 1.0 - clampf(r.level_m() / r.rect.size.y, 0.0, 0.7)
		_lamps[i].energy = LAMP_ENERGY * lamp_k
		_room_art[i].update(ship, r, _time, lamp_k, world.hazards)
	_fire.update(ship, _time, delta)
	for c: CrewMember in ship.crew:
		var spr: CrewSprite = _crew[c.index]
		spr.crew = c
		spr.selected = c.alive and (c.id == selected_crew_id or c.id in selected_ids)
		spr.station_system = ship.rooms[c.room].system if c.room >= 0 and c.room < ship.rooms.size() else "none"
		spr.position = c.pos * ppm + Vector2(0.0, -_foot_lift)
		spr.update(delta, _time)
		spr.visible = not c.away  # The away miner is drawn outside by MinerLayer, not in the drill room.
		_crew_lights[c.index].position = (c.pos + Vector2(0, -1.0)) * ppm
		_crew_lights[c.index].enabled = c.alive and not c.away
	if _drill != null:
		_process_drilling()
	for n: FnDraw in _redraw:
		n.queue_redraw()
