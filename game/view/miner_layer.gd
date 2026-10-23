class_name MinerLayer
extends Node2D
## The away miner in the world, in segment space (this node sits at the origin of the rock, like
## RockView and StructureLayer). It only READS the sim (`sim.drill.miner`) and follows `sim.events` by
## index; the one thing it asks for is the MinerCard's `armed` flag, to draw the aim.
##  - the aim: while the card is armed, a dashed range ring around the drill head (drawn only where it
##    falls inside the world view, like the blast ring), a circle under the mouse (green when
##    DrillMiner.target_ok says "", else red with the reason) and a dashed line from the head to it;
##  - the figure (from "exit" on, until the climb back in): legs, body, a harness band in the crew
##    member's colour, a helmet with a lamp, a pick that swings while they dig, and a small tag over
##    the head with the haul so far ("+12 ore +2 gems"); a red flash and a floating "-45" when they are
##    hurt, a pulsing "!" while a rockfall is coming;
##  - the headlamp: exactly one PointLight2D (the rock is one canvas item that meets every light), on
##    only while the miner is out; chips and sparks at the cell being dug.
## The figure layer is unshaded (lifted by the inverse of the ambient so the colours show as drawn); the
## effects layer is additive and needs the x1.9 boost (HANDOFF, glow).

const FIG_M: float = 1.6  ## The figure's height in meters.
const BOOST: float = 1.9
const LAMP_RADIUS_M: float = 4.5
const HURT_S: float = 0.6
const FLOAT_S: float = 1.3
const FLOAT_RISE_PX: float = 70.0
const SUIT: Color = Color(0.58, 0.54, 0.44)
const SUIT_DARK: Color = Color(0.36, 0.33, 0.27)
const HELMET: Color = Color(0.95, 0.74, 0.18)
const OUTLINE: Color = Color(0.03, 0.03, 0.04, 0.95)
const OK_COL: Color = Color(0.25, 0.55, 0.30, 0.9)  ## Additive layer: the x1.9 boost makes these a clear green and red.
const NO_COL: Color = Color(0.55, 0.18, 0.12, 0.9)

## One drawing node that draws through a callback.
class Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var sim: Sim = null
var card: MinerCard = null
var ppm: float = 80.0
var aim_override: Vector2 = Vector2(-1.0, -1.0)  ## Dev only (--aim): use this point instead of the mouse.
var lamp: PointLight2D = null
var lamp_energy: float = 0.0  ## Where the lamp is now (tests).
var floats: Array[Dictionary] = []  ## {text, pos (meters), age, color}
var _seen: int = 0
var _t: float = 0.0
var _walk_t: float = 0.0
var _hurt_age: float = 99.0
var _face: float = 1.0
var _last_pos: Vector2 = Vector2.ZERO
var _moving: bool = false
var _was_live: bool = false
var _fig: Layer = null
var _fx: Layer = null
var _chips: CPUParticles2D = null


func setup(p_sim: Sim, p_card: MinerCard, p_ppm: float) -> void:
	ppm = p_ppm
	z_index = 0
	_fx = Layer.new()
	_fx.fn = _draw_fx
	_fx.material = ArtLib.additive_unshaded()
	_fx.modulate = Color(BOOST, BOOST, BOOST, 1.0)
	_fx.z_index = 31
	add_child(_fx)
	_fig = Layer.new()
	_fig.fn = _draw_figure
	_fig.material = ArtLib.unshaded()
	# Unshaded and plain: dividing by the canvas modulate blows the colours out to white (HANDOFF), so the
	# figure is drawn in the colours it should show.
	_fig.modulate = Color(1.35, 1.35, 1.35, 1.0)
	_fig.z_index = 33
	add_child(_fig)
	_chips = CrownDebris.make_chips(Vector2(1.0, 0.0), 0.0)
	_chips.amount = 16
	_chips.lifetime = 0.55
	_chips.one_shot = false
	_chips.explosiveness = 0.0
	_chips.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	_chips.direction = Vector2(0, -1)
	_chips.spread = 120.0
	_chips.initial_velocity_min = 70.0
	_chips.initial_velocity_max = 210.0
	_chips.scale_amount_min = 1.0
	_chips.scale_amount_max = 2.0
	_chips.z_index = 32
	_chips.modulate = Color(1.7, 1.45, 1.05, 1.0)
	_chips.emitting = false
	add_child(_chips)
	lamp = PointLight2D.new()
	lamp.texture = RockView.light_texture(128, 0.0, 0.5, 0.35)
	lamp.texture_scale = ppm * LAMP_RADIUS_M * 2.0 / 128.0 / 0.4
	lamp.color = Color(1.0, 0.92, 0.75)
	lamp.energy = 0.0
	lamp.height = 120.0
	lamp.range_item_cull_mask = RockView.LIGHT_MASK
	lamp.enabled = false
	add_child(lamp)
	bind(p_sim, p_card)


## Follow a (new) sim from its current end.
func bind(p_sim: Sim, p_card: MinerCard) -> void:
	sim = p_sim
	card = p_card
	_seen = sim.events.size() if sim != null else 0
	floats.clear()
	_hurt_age = 99.0
	_moving = false
	if lamp != null:
		lamp.enabled = false
		lamp_energy = 0.0
	if _chips != null:
		_chips.emitting = false


# Pure helpers (tests read these) -----------------------------------------------------------------

## The harness colour of a crew member (the same accent the crew markers use).
static func harness_color(index: int) -> Color:
	return CrewMarks.ACCENTS[maxi(0, index) % CrewMarks.ACCENTS.size()]


## The tag over the miner's head ("+12 ore +2 gems"), "" when the haul is empty.
static func tag_text(haul: PackedInt32Array) -> String:
	return MinerCard.haul_text(haul, false)


## True while the miner is swinging at a solid cell (chips and sparks fly).
static func digging_solid(d: DrillSim) -> bool:
	var m: DrillMiner = d.miner
	if not m.active or (m.phase != "dig" and m.phase != "vein"):
		return false
	return m.next_cell >= 0 and m.next_cell < d.grid.size() and d.grid[m.next_cell] != 0


## The centre of a cell in segment meters.
static func cell_center(d: DrillSim, cell: int) -> Vector2:
	return Vector2(float(cell % d.cols) + 0.5, float(cell / d.cols) + 0.5) * d.cell_m


# Following the sim -------------------------------------------------------------------------------

var frozen: bool = false: set = set_frozen  ## The visible pause: no time passes in this node's animations.


func set_frozen(on: bool) -> void:
	if frozen == on:
		return
	frozen = on
	WorldFreeze.apply(self, on)


func _process(delta: float) -> void:
	_update(WorldFreeze.dt(frozen, delta))
	if frozen:
		WorldFreeze.apply(self, true)


func _update(delta: float) -> void:
	_t += delta
	if sim == null:
		return
	var n: int = sim.events.size()
	if n < _seen:
		_seen = 0
	for i: int in range(_seen, n):
		_on_event(sim.events[i])
	_seen = n
	var d: DrillSim = sim.drill
	var m: DrillMiner = d.miner
	var out: bool = m.is_out()
	_hurt_age += delta
	for f: Dictionary in floats:
		f["age"] = float(f["age"]) + delta
	floats = floats.filter(func(f: Dictionary) -> bool: return float(f["age"]) < FLOAT_S)
	if out:
		_moving = m.pos.distance_squared_to(_last_pos) > 0.0000001
		if _moving:
			_walk_t += delta * 9.0
		_last_pos = m.pos
		var look: float = (MinerLayer.cell_center(d, m.next_cell).x if m.next_cell >= 0 else m.target.x) - m.pos.x
		if absf(look) > 0.05:
			_face = 1.0 if look > 0.0 else -1.0
	lamp.enabled = out
	if out:
		var flicker: float = 1.0 + 0.05 * sin(_t * 7.1) + 0.03 * sin(_t * 17.3)
		lamp_energy = 0.75 * flicker
		lamp.energy = lamp_energy
		lamp.position = m.pos * ppm + Vector2(_face * 0.05, -0.92) * (FIG_M * ppm)
	else:
		lamp_energy = 0.0
	var solid: bool = digging_solid(d)
	_chips.emitting = solid
	if solid:
		_chips.position = MinerLayer.cell_center(d, m.next_cell) * ppm
	var armed: bool = card != null and card.armed and d.active
	var live: bool = out or armed or not floats.is_empty() or _hurt_age < HURT_S
	if live or _was_live:
		_fx.queue_redraw()
		_fig.queue_redraw()
	_was_live = live


func _on_event(e: Dictionary) -> void:
	var d: DrillSim = sim.drill
	match str(e.get("kind", "")):
		"miner_hurt":
			_hurt_age = 0.0
			_add_float("-%d" % roundi(float(e.get("hp", 0.0))), d.miner.pos + Vector2(0.0, -FIG_M), Color(1.0, 0.3, 0.25))
		"miner_lost":
			_add_float("LOST", d.miner.pos + Vector2(0.0, -FIG_M * 1.1), Color(1.0, 0.3, 0.25))
		"miner_back":
			var txt: String = MinerCard.haul_text(_haul_of(e), false)
			if not txt.is_empty():
				_add_float(txt, DrillMiner.head(d) + Vector2(0.0, 0.2), Color(0.7, 1.0, 0.75))


func _haul_of(e: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(RunState.RESOURCES.size())
	var h: Dictionary = e.get("haul", {})
	for i: int in range(RunState.RESOURCES.size()):
		out[i] = int(h.get(RunState.RESOURCES[i], 0))
	return out


func _add_float(text: String, at_m: Vector2, col: Color) -> void:
	if floats.size() >= 8:
		floats.remove_at(0)
	floats.append({"text": text, "pos": at_m, "age": 0.0, "color": col})


func _zoom() -> float:
	return maxf(0.2, get_viewport().get_canvas_transform().get_scale().x)


# The figure --------------------------------------------------------------------------------------

func _limb(n: Node2D, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	n.draw_line(a, b, OUTLINE, w + 4.0 * _k)
	n.draw_line(a, b, col, w)


var _k: float = 1.0

func _draw_figure(n: Node2D) -> void:
	if sim == null:
		return
	var d: DrillSim = sim.drill
	var m: DrillMiner = d.miner
	if not m.is_out():
		return
	_k = 1.0 / _zoom()
	var h: float = FIG_M * ppm
	var f: float = _face
	var feet: Vector2 = m.pos * ppm
	var c: CrewMember = sim.ship.crew_by_id(m.crew_id)
	var accent: Color = harness_color(c.index if c != null else 0)
	var hurt: float = clampf(1.0 - _hurt_age / HURT_S, 0.0, 1.0)
	var suit: Color = SUIT.lerp(Color(1.0, 0.2, 0.15), hurt * 0.8)
	var dark: Color = SUIT_DARK.lerp(Color(0.8, 0.1, 0.08), hurt * 0.8)
	var digging: bool = m.active and (m.phase == "dig" or m.phase == "vein")
	var bob: float = absf(sin(_walk_t)) * 0.02 * h if _moving else 0.0
	var hip: Vector2 = feet + Vector2(0.0, -0.46 * h - bob)
	var sh: Vector2 = feet + Vector2(f * 0.01 * h, -0.80 * h - bob)
	# Legs: they scissor while walking, stand apart while digging.
	var sw: float = sin(_walk_t) * 0.13 * h if _moving else 0.0
	var stance: float = 0.07 * h
	_limb(n, hip, feet + Vector2(-stance + sw, 0.0), 0.075 * h, dark)
	_limb(n, hip, feet + Vector2(stance - sw, 0.0), 0.075 * h, dark)
	# Body and the harness band across it.
	var torso := Rect2(Vector2(-0.11 * h, -0.82 * h - bob) + feet, Vector2(0.22 * h, 0.38 * h))
	n.draw_rect(torso.grow(2.0 * _k), OUTLINE, true)
	n.draw_rect(torso, suit, true)
	n.draw_colored_polygon(PackedVector2Array([
		torso.position + Vector2(0.0, 0.02 * h), torso.position + Vector2(0.07 * h, 0.0),
		torso.end + Vector2(0.0, -0.02 * h), torso.end + Vector2(-0.07 * h, 0.0)]), accent)
	n.draw_rect(Rect2(torso.position + Vector2(0.0, 0.31 * h), Vector2(torso.size.x, 0.05 * h)), accent, true)
	# Head and helmet with its lamp.
	var head: Vector2 = feet + Vector2(f * 0.015 * h, -0.91 * h - bob)
	n.draw_circle(head, 0.085 * h + 2.0 * _k, OUTLINE)
	n.draw_circle(head, 0.085 * h, Color(0.82, 0.66, 0.52).lerp(Color(1.0, 0.3, 0.25), hurt * 0.6))
	n.draw_arc(head, 0.098 * h, PI, TAU, 14, OUTLINE, 0.06 * h + 3.0 * _k)
	n.draw_arc(head, 0.098 * h, PI, TAU, 14, HELMET, 0.06 * h)
	n.draw_circle(head + Vector2(f * 0.095 * h, -0.02 * h), 0.028 * h, Color(1.0, 0.98, 0.85))
	# The arm and the pick: swings at the cell being dug, rests over the shoulder otherwise.
	var ang: float = -1.9 if f > 0.0 else PI + 1.9
	if digging and m.next_cell >= 0:
		var to_cell: Vector2 = cell_center(d, m.next_cell) * ppm - sh
		ang = to_cell.angle() - 0.9 + 1.5 * (0.5 + 0.5 * sin(_t * 11.0))
	var elbow: Vector2 = sh + Vector2.from_angle(ang) * 0.24 * h
	var tip: Vector2 = sh + Vector2.from_angle(ang) * 0.46 * h
	_limb(n, sh, elbow, 0.06 * h, suit)
	_limb(n, elbow - Vector2.from_angle(ang) * 0.08 * h, tip, 0.03 * h, Color(0.45, 0.32, 0.2))
	var side: Vector2 = Vector2.from_angle(ang + PI * 0.5) * 0.09 * h
	_limb(n, tip - side, tip + side, 0.035 * h, Color(0.75, 0.78, 0.82))
	_draw_tag(n, m, feet, h)


func _draw_tag(n: Node2D, m: DrillMiner, feet: Vector2, h: float) -> void:
	var font: Font = UiTheme.mono()
	var fs: int = maxi(8, roundi(21.0 * _k))
	var top: float = feet.y - h - 24.0 * _k
	var text: String = tag_text(m.haul)
	if not text.is_empty():
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(feet.x - w * 0.5, top)
		n.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, roundi(5.0 * _k)), Color(0.02, 0.02, 0.03, 0.95))
		n.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.55))
		top -= 26.0 * _k
	if m.rockfall_ticks > 0:
		var p: float = 0.5 + 0.5 * sin(_t * 16.0)
		var bang: String = "!"
		var bs: int = roundi(46.0 * _k * (0.9 + 0.2 * p))
		var bw: float = font.get_string_size(bang, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
		var bpos := Vector2(feet.x - bw * 0.5, top - 4.0 * _k)
		n.draw_string_outline(font, bpos, bang, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, maxi(3, roundi(7.0 * _k)), Color(0.05, 0.0, 0.0, 0.95))
		n.draw_string(font, bpos, bang, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(1.0, 0.28 + 0.4 * p, 0.2))
	# Floating texts (damage, the haul coming home).
	for f: Dictionary in floats:
		var t: float = clampf(float(f["age"]) / FLOAT_S, 0.0, 1.0)
		var col: Color = f["color"] as Color
		var txt: String = str(f["text"])
		var fsz: int = maxi(8, roundi(26.0 * _k))
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var at: Vector2 = (f["pos"] as Vector2) * ppm + Vector2(-tw * 0.5, -FLOAT_RISE_PX * _k * (1.0 - pow(1.0 - t, 2.0)))
		var a: float = 1.0 - smoothstep(0.55, 1.0, t)
		n.draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, maxi(2, roundi(5.0 * _k)), Color(0.02, 0.02, 0.03, 0.9 * a))
		n.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(col.r, col.g, col.b, a))


# The effects: aim, lamp halo, sparks, flash ----------------------------------------------------------

func _draw_fx(n: Node2D) -> void:
	if sim == null:
		return
	var d: DrillSim = sim.drill
	var k: float = 1.0 / _zoom()
	if card != null and card.armed and d.active:
		_draw_aim(n, d, k)
	var m: DrillMiner = d.miner
	if not m.is_out():
		return
	var h: float = FIG_M * ppm
	var feet: Vector2 = m.pos * ppm
	var lamp_at: Vector2 = feet + Vector2(_face * 0.11, -0.93) * h
	n.draw_circle(lamp_at, 0.045 * h, Color(0.30, 0.27, 0.18, 0.5))
	n.draw_circle(lamp_at, 0.02 * h, Color(0.5, 0.47, 0.38, 0.9))
	if _hurt_age < HURT_S:
		var a: float = 1.0 - _hurt_age / HURT_S
		n.draw_circle(feet + Vector2(0.0, -0.5 * h), 0.55 * h, Color(0.25, 0.03, 0.02, 0.45 * a))
	if m.rockfall_ticks > 0:
		var p: float = 0.5 + 0.5 * sin(_t * 16.0)
		n.draw_arc(feet + Vector2(0.0, -0.5 * h), 0.75 * h, 0.0, TAU, 32, Color(0.4, 0.1, 0.05, 0.35 + 0.3 * p), 3.0 * k)
	if digging_solid(d):
		var at: Vector2 = cell_center(d, m.next_cell) * ppm
		var s: int = int(_t * 24.0)
		for i: int in range(7):
			var ang: float = RockView._hash(s, i, 21) * TAU
			var len_px: float = (6.0 + RockView._hash(s, i, 22) * 22.0) * k * 1.4
			n.draw_line(at, at + Vector2.from_angle(ang) * len_px, Color(0.55, 0.4, 0.2, 0.8), 2.0 * k)
		n.draw_circle(at, 7.0 * k, Color(0.5, 0.33, 0.15, 0.45))


## The aim: a dashed ring of the miner's range around the drill head (only where it is inside the world
## view), a circle where the click would land and a dashed line from the head to it.
func _draw_aim(n: Node2D, d: DrillSim, k: float) -> void:
	var head: Vector2 = DrillMiner.head(d) * ppm
	var range_px: float = d.miner.range_m * ppm
	var pulse: float = 0.65 + 0.25 * sin(_t * 4.0)
	var col := Color(0.25, 0.55, 0.30, pulse)
	var to_screen: Transform2D = n.get_global_transform_with_canvas()
	var view: Rect2 = RunScreen.WORLD_RECT.grow(-6.0)
	var seg: int = 120
	for i: int in range(seg):
		if i % 2 == 1:
			continue
		var a0: float = float(i) / float(seg) * TAU
		var a1: float = float(i + 1) / float(seg) * TAU
		var p0: Vector2 = to_screen * (head + Vector2(cos(a0), sin(a0)) * range_px)
		var p1: Vector2 = to_screen * (head + Vector2(cos(a1), sin(a1)) * range_px)
		if view.has_point(p0) and view.has_point(p1):
			n.draw_arc(head, range_px, a0, a1, 3, col, 5.0 * k)
	var at: Vector2 = _aim_point()
	if at.x < 0.0:
		return
	var crew: String = card.crew_id() if card != null else ""
	var why: String = DrillMiner.target_ok(d, sim, crew, at)
	var ok: bool = why.is_empty()
	var tc: Color = OK_COL if ok else NO_COL
	var rad: float = maxf(0.5, d.cell_m) * ppm
	n.draw_arc(at * ppm, rad, 0.0, TAU, 32, tc, 3.0 * k)
	n.draw_circle(at * ppm, rad, Color(tc.r, tc.g, tc.b, 0.12))
	n.draw_line(at * ppm - Vector2(10, 0) * k, at * ppm + Vector2(10, 0) * k, tc, 2.0 * k)
	n.draw_line(at * ppm - Vector2(0, 10) * k, at * ppm + Vector2(0, 10) * k, tc, 2.0 * k)
	n.draw_dashed_line(head, at * ppm, Color(tc, 0.45), 2.0 * k, 10.0 * k)
	var txt: String = MinerCard.reason_text(why, d.miner.range_m) if not ok else aim_value_text(d, sim, at)
	n.draw_string(UiTheme.mono(), at * ppm + Vector2(rad + 8.0 * k, 5.0 * k), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, roundi(20.0 * k)), tc)


## What a click here would bring home: "~12 ORE +2 GEMS", "BARREN: STRAIGHT BACK", plus "GAS ON THE
## WAY" or "WATER ON THE WAY" (MinerRoute.estimate; Stewart could not tell veins from bare rock).
static func aim_value_text(d: DrillSim, s: Sim, at: Vector2) -> String:
	var e: Dictionary = MinerRoute.estimate(d, at, roundi(s.db.tune("miner.vein_max_cells")), roundi(s.db.tune("miner.yield_pct")))
	var ore: int = int(e["ore"])
	var gems: int = int(e["gems"])
	var parts := PackedStringArray()
	if ore > 0:
		parts.append("~%d ORE" % ore)
	if gems > 0:
		parts.append("+%d GEMS" % gems if ore > 0 else "~%d GEMS" % gems)
	var txt: String = " ".join(parts) if not parts.is_empty() else "BARREN: STRAIGHT BACK"
	var hz: String = str(e["hazard"])
	if not hz.is_empty():
		txt += ", %s ON THE WAY" % hz.to_upper()
	return txt


## The mouse in segment meters (or the dev override), or (-1, -1) when the mouse is not over the world.
func _aim_point() -> Vector2:
	if aim_override.x >= 0.0:
		return aim_override
	var vp: Viewport = get_viewport()
	var mp: Vector2 = vp.get_mouse_position()
	if not RunScreen.WORLD_RECT.has_point(mp):
		return Vector2(-1.0, -1.0)
	return (get_global_transform_with_canvas().affine_inverse() * mp) / ppm
