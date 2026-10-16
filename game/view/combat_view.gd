class_name CombatView
extends Node2D
## The fight in the world view. While sim.combat is active it shows the rival tower (a second
## ShipView on sim.enemy, placed at the combat geometry offset), a band of rock between the hulls,
## rounds in flight along their paths (tracers for borer rounds, a heavy shell for charges, a sweeping
## beam for the thermal lance), impact flashes, bracing shells around each hull, a "BLOCKED" pop and a
## shield flash when bracing soaks a hit, a miss streak when evaded, and reticles on targeted rooms.
## It only reads the sim: effects come from sim.events and sim.combat.shots_view(). Clean-up is
## automatic when the fight ends. The world stays: a field of the painted rock tiles (the same tile
## and a warm strata tint as the drilled rock, with darker bands) is laid under everything in the
## fight's rectangle, beyond the drilled grid too, lit by both towers' floodlights, so the towers sit
## in rock and not in a void. The rival is a different tower: oxide-red hull, red marker lights,
## colder lamps and a name plate. This node follows the player ShipView's position, so everything is
## drawn in the player's ship space (pixels = meters * ppm).
##
## Main: setup(sim, view, ppm, rock_present); each frame set `armed` (the weapon being aimed) and
## `cam_zoom` (text stays readable when the camera zooms out); `enemy_room_at_mouse()` for clicks.

const TRACER_M: float = 0.9
const IMPACT_S: float = 0.5
const POP_S: float = 1.0
const SHELL_COLOR: Color = Color(0.35, 0.78, 1.0)
const PLAYER_SHOT: Color = Color(1.0, 0.82, 0.40)
const ENEMY_SHOT: Color = Color(1.0, 0.30, 0.22)
const MARGIN_PX: float = 56.0
const FILL_CHUNK: int = 512
const FILL_Z: int = -20  ## Over the apron (-21), level with the drilled rock, which it never overlaps.
const FILL_TINT: Color = Color(1.9, 1.62, 1.42)
const GLOW_COLOR: Color = Color(1.0, 0.84, 0.68)
const HALO_COLOR: Color = Color(0.14, 0.09, 0.055)


## A node that draws through a callback (one small canvas item per layer).
class Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var sim: Sim
var ppm: float = 80.0
var player_view: ShipView
var enemy_view: ShipView = null
var armed: int = -1
var cam_zoom: float = 1.0
var rock_present: Callable = Callable()
var _world: ShipWorld = null
var _band: Layer
var _fills: Layer  ## Glowing fills (shell flash, aiming highlights): additive, plain colours.
var _unshaded: CanvasItemMaterial
var _fill: Node2D = null
var _fx: Array[Dictionary] = []
var _landed: Array[Dictionary] = []
var _prev: Dictionary = {}
var _seen: int = 0
var _flash: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])  ## Shield flash, player then enemy.
var _t: float = 0.0


func setup(p_sim: Sim, p_view: ShipView, p_ppm: float, p_rock_present: Callable) -> void:
	sim = p_sim
	player_view = p_view
	ppm = p_ppm
	rock_present = p_rock_present
	z_index = 30
	_unshaded = CanvasItemMaterial.new()
	_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _unshaded
	_band = Layer.new()
	_band.fn = _draw_band
	_band.z_index = -9
	_band.material = _unshaded
	add_child(_band)
	_band.visible = false
	_fills = Layer.new()
	_fills.fn = _draw_fills
	_fills.z_index = 29
	var add := CanvasItemMaterial.new()
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fills.material = add
	add_child(_fills)


## Follow a new sim (a new run).
func rebind(p_sim: Sim) -> void:
	sim = p_sim
	_clear()


func active() -> bool:
	return sim != null and sim.combat.active and sim.enemy != null and enemy_view != null


# Geometry ---------------------------------------------------------------------------------------

func _origin_px() -> Vector2:
	return sim.combat.enemy_origin * ppm


func _rect_px(of_enemy: bool) -> Rect2:
	var v: ShipView = enemy_view if of_enemy else player_view
	var o: Vector2 = _origin_px() if of_enemy else Vector2.ZERO
	return Rect2(o, v.ship_size_m() * ppm)


## Both hulls plus a margin, in the world's pixel space (the player's view position added), for the
## camera to frame.
func bounds_px() -> Rect2:
	if not active():
		return Rect2()
	var r: Rect2 = _rect_px(false).merge(_rect_px(true)).grow(MARGIN_PX)
	r.position += player_view.position
	return r


func enemy_room_at_mouse() -> int:
	return enemy_room_at(get_viewport().get_mouse_position())


## The enemy room under a screen (viewport) position, or -1. A click uses its own event position, so
## the answer never depends on when the polled mouse position was last updated.
func enemy_room_at(screen_pos: Vector2) -> int:
	if not active():
		return -1
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_pos
	var p: Vector2 = (local - _origin_px()) / ppm
	return sim.enemy.ship.room_at(p + Vector2(0, 0.06), -1)


func _room_center_px(of_enemy: bool, room_id: String) -> Vector2:
	var ship: Ship = sim.enemy.ship if of_enemy else sim.ship
	var ri: int = ship.room_index(room_id)
	if ri < 0:
		return _rect_px(of_enemy).get_center()
	return ship.rooms[ri].rect.get_center() * ppm + (_origin_px() if of_enemy else Vector2.ZERO)


## Lit-looking colour for unshaded drawing: CanvasModulate darkens everything, so divide it out
## (k above 1.0 blooms in the glow pass).
static func hdr(c: Color, k: float = 1.0) -> Color:
	var a: Color = RockView.AMBIENT
	return Color(c.r * k / a.r, c.g * k / a.g, c.b * k / a.b, c.a)


# Life cycle -------------------------------------------------------------------------------------

func _clear() -> void:
	if enemy_view != null:
		enemy_view.queue_free()
		enemy_view = null
	if _fill != null:
		_fill.queue_free()
		_fill = null
	if player_view != null and not player_view.is_drilling():
		player_view.set_floodlights(false)
	_world = null
	_fx.clear()
	_landed.clear()
	_prev.clear()
	_flash[0] = 0.0
	_flash[1] = 0.0
	_band.visible = false
	if sim != null:
		_seen = sim.events.size()
	queue_redraw()
	_band.queue_redraw()


func _spawn_enemy() -> void:
	_world = sim.enemy
	enemy_view = ShipView.new()
	enemy_view.setup(sim, sim.enemy, ppm)
	get_parent().add_child(enemy_view)
	# The fight's own rock field replaces the enemy's stand-in rock; both towers' floodlights light it.
	enemy_view.set_backdrop_visible(false)
	enemy_view.set_floodlights(true)
	player_view.set_floodlights(true)
	enemy_view.position = player_view.position + _origin_px()
	_build_fill()
	_fx.clear()
	_landed.clear()
	_prev.clear()
	_seen = sim.events.size()
	_band.visible = true


## The rock field under the fight: painted tiles over the fight rectangle plus a wide margin, in
## world pixel space, covering everything outside the drilled grid (the grid draws its own rock, and
## is narrower than the fight). Unshaded and pre-brightened to read like dim rock under the
## floodlights: the lit apron around the grid is dropped by Godot's per-item light limit out there,
## so a lit fill stayed black. Dark strata bands and a warm halo behind each tower sit on top.
func _build_fill() -> void:
	if _fill != null:
		_fill.queue_free()
	_fill = Node2D.new()
	_fill.z_index = FILL_Z
	get_parent().add_child(_fill)
	var area: Rect2 = bounds_px().grow(ppm * 30.0)
	var grid := Rect2()
	if rock_present.is_valid() and bool(rock_present.call()) and sim.drill.cols > 0:
		grid = Rect2(0.0, 0.0, float(sim.drill.cols) * sim.drill.cell_m * ppm, float(sim.drill.rows) * sim.drill.cell_m * ppm)
	if grid.size == Vector2.ZERO:
		_fill_rect(area)
	else:
		_fill_rect(Rect2(area.position, Vector2(grid.position.x - area.position.x, area.size.y)))
		_fill_rect(Rect2(grid.end.x, area.position.y, area.end.x - grid.end.x, area.size.y))
		_fill_rect(Rect2(grid.position.x, area.position.y, grid.size.x, grid.position.y - area.position.y))
		_fill_rect(Rect2(grid.position.x, grid.end.y, grid.size.x, area.end.y - grid.end.y))
	var bands := Layer.new()
	bands.material = _unshaded
	bands.fn = func(n: Node2D) -> void: _draw_strata(n, area)
	_fill.add_child(bands)
	var halo: GradientTexture2D = ShipView.radial_texture(128)
	var soft: ImageTexture = RockView.light_texture(128, 0.0, 0.45, 0.45)
	var mid: Vector2 = bounds_px().get_center()
	var spots: Array[Vector2] = [player_view.position + _rect_px(false).get_center(),
		player_view.position + _rect_px(true).get_center(), mid]
	for at: Vector2 in spots:
		var g := Sprite2D.new()
		g.texture = halo
		g.material = ArtLib.additive_unshaded()
		g.position = at
		var d: float = ppm * 26.0 * 2.0 / 128.0
		g.scale = Vector2(d, d)
		g.modulate = HALO_COLOR
		_fill.add_child(g)
		# The lit rock of the drilled grid keeps its light from the same spots.
		var l := PointLight2D.new()
		l.texture = soft
		var radius: float = ppm * 24.0
		l.texture_scale = radius * 2.0 / 128.0 / 0.4
		l.position = at
		l.color = GLOW_COLOR
		l.energy = 0.9
		l.height = 150.0
		l.range_item_cull_mask = RockView.LIGHT_MASK
		_fill.add_child(l)


## Tile one rectangle (world pixels) with chunked sprites, keeping the world's tile phase.
func _fill_rect(r: Rect2) -> void:
	if r.size.x <= 1.0 or r.size.y <= 1.0:
		return
	var tex: Texture2D = RockTiles.canvas_tile("dense")
	var k: float = RockTiles.TILE_M * ppm / float(RockTiles.TILE_PX)
	var tile_w: float = float(RockTiles.TILE_PX) * k
	var step: float = float(FILL_CHUNK)
	var y: float = r.position.y
	while y < r.end.y:
		var h: float = minf(step, r.end.y - y)
		var x: float = r.position.x
		while x < r.end.x:
			var w: float = minf(step, r.end.x - x)
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			sp.region_enabled = true
			# Phase of the world tiling, kept positive: a region that starts below zero does not wrap.
			sp.region_rect = Rect2(Vector2(fposmod(x, tile_w), fposmod(y, tile_w)) / k, Vector2(w, h) / k)
			sp.scale = Vector2(k, k)
			sp.position = Vector2(x, y)
			sp.self_modulate = FILL_TINT
			sp.material = ArtLib.unshaded()
			_fill.add_child(sp)
			x += step
		y += step


## Darker strata bands across the fill, wavy and in a fixed order from a small integer hash.
func _draw_strata(n: Node2D, area: Rect2) -> void:
	var h: int = 104729
	var y: float = area.position.y
	while y < area.end.y:
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var th: float = ppm * (1.2 + float(h % 40) / 10.0)
		var a: float = 0.05 + float((h >> 8) % 20) / 100.0
		var pts := PackedVector2Array()
		var steps: int = 24
		for i: int in range(steps + 1):
			var x: float = area.position.x + area.size.x * float(i) / float(steps)
			pts.append(Vector2(x, y + ppm * 0.5 * sin(x * 0.004 + float(h % 7))))
		for i: int in range(steps, -1, -1):
			pts.append(Vector2(pts[i].x, pts[i].y + th))
		n.draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, a))
		y += th + ppm * (1.0 + float((h >> 4) % 30) / 10.0)


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_update(delta)
	PerfRecorder.span(PerfRecorder.SPAN_COMBAT, Time.get_ticks_usec() - t0)


func _update(delta: float) -> void:
	_t += delta
	if sim == null or player_view == null:
		return
	var fight: bool = sim.combat.active and sim.enemy != null
	if fight and (enemy_view == null or _world != sim.enemy):
		if enemy_view != null:
			enemy_view.queue_free()
			enemy_view = null
		_spawn_enemy()
	elif not fight and enemy_view != null:
		_clear()
	position = player_view.position
	if enemy_view == null:
		return
	_track_landed()
	_consume_events()
	_landed.clear()
	for i: int in range(_flash.size()):
		_flash[i] = maxf(0.0, _flash[i] - delta * 2.4)
	var i: int = 0
	while i < _fx.size():
		_fx[i]["age"] = float(_fx[i]["age"]) + delta
		if float(_fx[i]["age"]) >= float(_fx[i]["life"]):
			_fx.remove_at(i)
		else:
			i += 1
	queue_redraw()
	_band.queue_redraw()
	_fills.queue_redraw()


## Rounds that were in flight last frame and are gone now have landed: remember where and which way,
## so a block or a miss can show at the right place.
func _track_landed() -> void:
	var cur: Dictionary = {}
	for s: Dictionary in sim.combat.shots_view():
		if str(s["kind"]) == "beam":
			continue
		var a: Vector2 = s["start"]
		var b: Vector2 = s["end"]
		var key: String = "%.2f,%.2f>%.2f,%.2f" % [a.x, a.y, b.x, b.y]
		var e: Dictionary = cur.get(key, {"n": 0, "start": a, "end": b})
		e["n"] = int(e["n"]) + 1
		cur[key] = e
	for key: String in _prev.keys():
		var before: Dictionary = _prev[key]
		var now: int = int(cur[key]["n"]) if cur.has(key) else 0
		for k: int in range(int(before["n"]) - now):
			_landed.append({"start": before["start"], "end": before["end"]})
	_prev = cur


func _landed_for(enemy_struck: bool) -> Dictionary:
	var r: Rect2 = Rect2(sim.combat.enemy_origin, enemy_view.ship_size_m()).grow(0.6)
	for i: int in range(_landed.size()):
		var end: Vector2 = _landed[i]["end"]
		if r.has_point(end) == enemy_struck:
			var l: Dictionary = _landed[i]
			_landed.remove_at(i)
			return l
	return {}


func _consume_events() -> void:
	while _seen < sim.events.size():
		var e: Dictionary = sim.events[_seen]
		_seen += 1
		var enemy_tag: bool = str(e.get("side", "player")) == "enemy"
		match str(e["kind"]):
			"room_hit":
				_add("impact", _room_center_px(enemy_tag, str(e["room"])), IMPACT_S, {"big": int(e.get("damage", 1)) >= 2})
			"weapon_fired":
				var ship: Ship = sim.enemy.ship if enemy_tag else sim.ship
				var wr: int = ship.room_with_system("weapons")
				if wr >= 0:
					_add("muzzle", _room_center_px(enemy_tag, ship.rooms[wr].id), 0.3, {"enemy": enemy_tag})
			"bracing_absorbed":
				var at: Vector2 = _hit_point(enemy_tag, true)
				_flash[1 if enemy_tag else 0] = 1.0
				_add("block", at, POP_S, {"enemy": enemy_tag})
			"beam_blocked":
				_flash[1 if enemy_tag else 0] = 1.0
				_add("block", _room_center_px(enemy_tag, str(e["room"])), POP_S, {"enemy": enemy_tag})
			"shot_missed":
				var landed: Dictionary = _landed_for(enemy_tag)
				var dir: Vector2 = Vector2(1, 0) if enemy_tag == sim.combat.enemy_on_right else Vector2(-1, 0)
				if not landed.is_empty():
					var d: Vector2 = (landed["end"] as Vector2) - (landed["start"] as Vector2)
					if d.length() > 0.01:
						dir = d.normalized()
				_add("miss", _room_center_px(enemy_tag, str(e["room"])), 0.8, {"dir": dir})


func _hit_point(enemy_struck: bool, consume: bool) -> Vector2:
	var l: Dictionary = _landed_for(enemy_struck) if consume else {}
	if not l.is_empty():
		return (l["end"] as Vector2) * ppm
	var r: Rect2 = _rect_px(enemy_struck)
	return r.get_center()


func _add(kind: String, pos: Vector2, life: float, extra: Dictionary) -> void:
	var f: Dictionary = {"kind": kind, "pos": pos, "age": 0.0, "life": life}
	f.merge(extra)
	_fx.append(f)


# Drawing ----------------------------------------------------------------------------------------

func _draw() -> void:
	if not active():
		return
	_draw_shells()
	_draw_plate()
	_draw_targets()
	_draw_shots()
	_draw_fx()


## The rock between the hulls: a dark band with strata and cracks, behind the ships.
func _draw_band(n: Node2D) -> void:
	if not active():
		return
	var a: Rect2 = _rect_px(false)
	var b: Rect2 = _rect_px(true)
	var left: Rect2 = a if a.position.x < b.position.x else b
	var right: Rect2 = b if a.position.x < b.position.x else a
	var x0: float = left.end.x
	var x1: float = right.position.x
	var y0: float = -ppm * 3.0
	var y1: float = maxf(a.end.y, b.end.y) + ppm * 3.0
	var h: int = 7919
	for i: int in range(14):
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var y: float = y0 + float(h % int(y1 - y0))
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var xs: float = x0 + float(h % maxi(1, int(x1 - x0 - 120.0)))
		var len: float = 120.0 + float(h % 300)
		n.draw_line(Vector2(xs, y), Vector2(minf(xs + len, x1), y + float(h % 9) - 4.0), hdr(Color(0.5, 0.42, 0.34, 0.07)), 2.0)
	# Cracks near the hulls where the rounds will pass.
	for i: int in range(9):
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var cx: float = x0 + float(h % maxi(1, int(x1 - x0)))
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var cy: float = y0 + float(h % int(y1 - y0))
		var pts := PackedVector2Array([Vector2(cx, cy), Vector2(cx + 22.0, cy + 30.0), Vector2(cx + 8.0, cy + 58.0), Vector2(cx + 30.0, cy + 90.0)])
		n.draw_polyline(pts, hdr(Color(0.0, 0.0, 0.0, 0.6)), 2.0)


static func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for c: int in range(4):
		for s: int in range(7):
			var ang: float = (float(c) * 0.5 + float(s) / 12.0 - 0.25) * PI
			pts.append(corners[c] + Vector2(cos(ang), sin(ang)) * rad)
	pts.append(pts[0])
	return pts


## The rival's name plate above its hull, kept the same size on screen as the camera zooms.
func _draw_plate() -> void:
	var r: Rect2 = _rect_px(true)
	var title: String = "HOSTILE  " + sim.enemy.ship.name.to_upper()
	var px: int = _text_px(22)
	var f: Font = UiTheme.mono()
	var tw: float = f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pad: float = float(px) * 0.6
	var box := Rect2(r.get_center().x - tw * 0.5 - pad, r.position.y - float(px) * 3.6, tw + pad * 2.0, float(px) * 1.7)
	draw_rect(box, Color(0.04, 0.01, 0.01, 0.82), true)
	draw_rect(box, hdr(Color(1.0, 0.22, 0.16, 0.95), 0.5), false, maxf(2.0, float(px) * 0.12))
	draw_rect(Rect2(box.position.x, box.position.y, float(px) * 0.35, box.size.y), hdr(Color(1.0, 0.25, 0.18), 0.5), true)
	draw_string(f, Vector2(box.position.x + pad, box.position.y + float(px) * 1.2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, hdr(Color(1.0, 0.82, 0.76), 0.33))


## Bracing layers as shells around each hull; spent ones are faint, a block flashes them all.
func _draw_shells() -> void:
	for side: int in range(2):
		var of_enemy: bool = side == 1
		var world: ShipWorld = sim.enemy if of_enemy else sim.player
		var layers: int = sim.systems.bracing_layers(world)
		var most: int = sim.systems.max_layers(world)
		var fl: float = _flash[side]
		var rect: Rect2 = _rect_px(of_enemy)
		for i: int in range(most):
			var grow: float = 14.0 + float(i) * 12.0
			var live: bool = i < layers
			var shimmer: float = 0.85 + 0.15 * sin(_t * 2.2 + float(i) * 1.3 + float(side))
			var a: float = (0.42 * shimmer if live else 0.07) + fl * 0.55
			var shell: Rect2 = rect.grow(grow)
			var pts: PackedVector2Array = _rounded(shell, 26.0 + grow)
			draw_polyline(pts, hdr(Color(SHELL_COLOR, clampf(a, 0.0, 1.0)), 0.55 + fl * 0.5), 3.0 if live else 1.5, true)


func _draw_targets() -> void:
	var wv: Array[Dictionary] = sim.combat.weapons_view(sim, false)
	var ship: Ship = sim.enemy.ship
	for i: int in range(wv.size()):
		var tid: String = str(wv[i]["target"])
		if tid.is_empty():
			continue
		var ri: int = ship.room_index(tid)
		if ri < 0:
			continue
		var c: Vector2 = ship.rooms[ri].rect.get_center() * ppm + _origin_px()
		var col: Color = WeaponCards.SLOT_COLORS[i % WeaponCards.SLOT_COLORS.size()]
		var ready: bool = float(wv[i]["charge_s"]) >= float(wv[i]["charge_max_s"]) - 0.001
		var pulse: float = 0.5 + 0.5 * sin(_t * (9.0 if ready else 3.0))
		var rad: float = 30.0 + 6.0 * pulse + float(i) * 14.0
		var cc: Color = hdr(col, 1.0 + (0.3 if ready else 0.0))
		draw_arc(c, rad, 0.0, TAU, 40, cc, 3.0, true)
		for k: int in range(4):
			var d := Vector2.from_angle(float(k) * PI * 0.5 + _t * 0.5)
			draw_line(c + d * (rad - 10.0), c + d * (rad + 12.0), cc, 3.0)
		_label(c + Vector2(-60.0, -rad - 8.0), "F%d" % (i + 1), 18, col, 120.0)
	if armed < 0:
		return
	var mouse: int = enemy_room_at_mouse()
	for r: Room in ship.rooms:
		var rr := Rect2(r.rect.position * ppm + _origin_px(), r.rect.size * ppm)
		var over: bool = r.index == mouse
		var col2: Color = WeaponCards.SLOT_COLORS[armed % WeaponCards.SLOT_COLORS.size()]
		draw_rect(rr.grow(-5.0), hdr(Color(col2, 1.0 if over else 0.45), 1.2 if over else 1.0), false, 4.0 if over else 2.0)
		if over:
			UiTheme.text(self, rr.position + Vector2(0, -10.0), r.name.to_upper(), _text_px(20), hdr(Color(1, 0.95, 0.8)), null, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)


## Centred text with a dark outline, kept under the glow threshold so it stays readable.
func _label(pos: Vector2, text: String, base_px: int, color: Color, width: float = 300.0) -> void:
	var px: int = _text_px(base_px)
	var f: Font = UiTheme.mono()
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, px, maxi(3, px / 5), Color(0, 0, 0, color.a))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, px, hdr(color, 0.95))


func _text_px(base: int) -> int:
	return int(roundf(float(base) / maxf(0.2, cam_zoom)))


func _draw_shots() -> void:
	for s: Dictionary in sim.combat.shots_view():
		var enemy_shot: bool = str(s["from"]) == "enemy"
		var team: Color = ENEMY_SHOT if enemy_shot else PLAYER_SHOT
		var a: Vector2 = (s["start"] as Vector2) * ppm
		var b: Vector2 = (s["end"] as Vector2) * ppm
		var prog: float = float(s["progress"])
		match str(s["kind"]):
			"beam":
				_draw_beam(a, b, prog, team, enemy_shot)
			"charge":
				_draw_charge((s["pos"] as Vector2) * ppm, (b - a).normalized(), a, team)
			_:
				_draw_tracer((s["pos"] as Vector2) * ppm, (b - a).normalized(), a, team)


func _draw_tracer(head: Vector2, dir: Vector2, from: Vector2, team: Color) -> void:
	var tail: Vector2 = head - dir * TRACER_M * ppm
	if (head - from).length() < TRACER_M * ppm:
		tail = from
	draw_line(tail, head, hdr(Color(team, 0.18), 1.1), 14.0, true)
	draw_line(tail, head, hdr(Color(team, 0.55), 1.2), 7.0, true)
	for k: int in range(5):
		var f0: float = float(k) / 5.0
		var f1: float = float(k + 1) / 5.0
		draw_line(tail.lerp(head, f0), tail.lerp(head, f1), hdr(Color(1.0, 0.97, 0.85, f1), 1.3), 3.0, true)
	draw_circle(head, 7.0, hdr(Color(team, 0.5), 1.3))
	draw_circle(head, 4.0, hdr(Color(1.0, 1.0, 0.92), 1.4))


func _draw_charge(head: Vector2, dir: Vector2, from: Vector2, team: Color) -> void:
	for k: int in range(7):
		var back: float = 14.0 + float(k) * 13.0
		var p: Vector2 = head - dir * back
		if (p - from).dot(dir) < 0.0:
			break
		var smoke: float = 0.30 * (1.0 - float(k) / 7.0)
		draw_circle(p + Vector2(0, sin(_t * 9.0 + float(k)) * 3.0), 6.0 + float(k) * 1.3, hdr(Color(0.65, 0.6, 0.55, smoke)))
	draw_circle(head, 20.0, hdr(Color(team, 0.22), 1.1))
	draw_circle(head, 11.0, hdr(Color(0.62, 0.58, 0.52)))
	draw_arc(head, 11.0, 0.0, TAU, 24, hdr(Color(team, 1.0), 1.2), 3.0, true)
	var spin: Vector2 = Vector2.from_angle(_t * 8.0) * 9.0
	draw_line(head - spin, head + spin, hdr(Color(0.2, 0.17, 0.15)), 3.0)
	var fuse: Vector2 = head - dir * 15.0
	var flick: float = 0.8 + 0.4 * sin(_t * 47.0)
	draw_circle(fuse, 6.0 * flick, hdr(Color(1.0, 0.6, 0.2), 1.5))
	draw_circle(fuse, 3.0, hdr(Color(1.0, 1.0, 0.8), 1.5))


func _draw_beam(a: Vector2, b: Vector2, prog: float, team: Color, enemy_shot: bool) -> void:
	var from_c: Vector2 = _weapons_center_px(enemy_shot)
	var sweep: float = clampf(prog * 4.0, 0.0, 1.0)
	var head: Vector2 = a.lerp(b, sweep)
	var fade: float = 1.0 - clampf((prog - 0.45) / 0.55, 0.0, 1.0)
	var pulse: float = 0.85 + 0.15 * sin(_t * 60.0)
	draw_line(from_c, a, hdr(Color(team, 0.35 * fade), 1.0), 3.0, true)
	draw_line(a, head, hdr(Color(team, 0.25 * fade), 1.2), 30.0 * pulse, true)
	draw_line(a, head, hdr(Color(team, 0.65 * fade), 1.3), 15.0 * pulse, true)
	draw_line(a, head, hdr(Color(1.0, 0.95, 0.85, fade), 1.5), 6.0, true)
	draw_circle(a, 14.0 * fade, hdr(Color(team, 0.6 * fade), 1.4))
	draw_circle(head, 20.0 * fade + 4.0, hdr(Color(1.0, 0.9, 0.6, 0.7 * fade), 1.5))


func _weapons_center_px(of_enemy: bool) -> Vector2:
	var ship: Ship = sim.enemy.ship if of_enemy else sim.ship
	var wr: int = ship.room_with_system("weapons")
	if wr < 0:
		return _rect_px(of_enemy).get_center()
	return ship.rooms[wr].rect.get_center() * ppm + (_origin_px() if of_enemy else Vector2.ZERO)


func _draw_fx() -> void:
	for f: Dictionary in _fx:
		var k: float = float(f["age"]) / float(f["life"])
		var p: Vector2 = f["pos"]
		match str(f["kind"]):
			"impact":
				var big: bool = bool(f.get("big", false))
				var r: float = (60.0 if big else 42.0) * (0.3 + k)
				draw_circle(p, r * 0.8, hdr(Color(1.0, 0.7, 0.3, 0.55 * (1.0 - k)), 1.5))
				draw_circle(p, r * 0.4, hdr(Color(1.0, 0.98, 0.85, 0.9 * (1.0 - k)), 1.6))
				draw_arc(p, r, 0.0, TAU, 32, hdr(Color(1.0, 0.55, 0.2, 1.0 - k), 1.4), 4.0 * (1.0 - k) + 1.0, true)
				for s: int in range(8):
					var d := Vector2.from_angle(float(s) * TAU / 8.0 + 0.4)
					draw_line(p + d * r * 0.5, p + d * r * (0.9 + 0.5 * k), hdr(Color(1.0, 0.85, 0.5, 1.0 - k), 1.4), 2.0)
			"muzzle":
				draw_circle(p, 26.0 * (1.0 - k) + 4.0, hdr(Color(ENEMY_SHOT if bool(f["enemy"]) else PLAYER_SHOT, 0.6 * (1.0 - k)), 1.4))
			"block":
				var col: Color = hdr(Color(SHELL_COLOR, 1.0 - k), 1.0)
				draw_arc(p, 30.0 + 80.0 * k, 0.0, TAU, 36, col, 5.0 * (1.0 - k) + 1.0, true)
				draw_circle(p, 20.0 * (1.0 - k), hdr(Color(0.8, 0.95, 1.0, 0.6 * (1.0 - k)), 0.9))
				var rise: float = 50.0 * k / maxf(0.3, cam_zoom)
				_label(p + Vector2(-150.0, -40.0 - rise), "BLOCKED", 30, Color(0.75, 0.95, 1.0, clampf(2.2 - 2.2 * k, 0.0, 1.0)))
			"miss":
				var dir: Vector2 = f["dir"]
				var len: float = 260.0 * minf(1.0, k * 2.5)
				var base: Vector2 = p - dir * 30.0
				draw_line(base, base + dir * len, hdr(Color(1.0, 1.0, 0.9, (1.0 - k) * 0.9), 1.3), 4.0 * (1.0 - k) + 1.0, true)
				draw_line(base + Vector2(0, 8), base + Vector2(0, 8) + dir * len * 0.7, hdr(Color(1.0, 0.9, 0.6, (1.0 - k) * 0.5)), 2.0, true)
				_label(p + Vector2(-100.0, -46.0 - 30.0 * k), "MISS", 24, Color(1.0, 0.95, 0.8, 1.0 - k), 200.0)


func _draw_fills(n: Node2D) -> void:
	if not active():
		return
	for side: int in range(2):
		var fl: float = _flash[side]
		if fl <= 0.0:
			continue
		var pts: PackedVector2Array = _rounded(_rect_px(side == 1).grow(14.0), 40.0)
		pts.remove_at(pts.size() - 1)
		n.draw_colored_polygon(pts, Color(SHELL_COLOR, 0.55 * fl))
	if armed < 0:
		return
	var mouse: int = enemy_room_at_mouse()
	var col: Color = WeaponCards.SLOT_COLORS[armed % WeaponCards.SLOT_COLORS.size()]
	for r: Room in sim.enemy.ship.rooms:
		var rr := Rect2(r.rect.position * ppm + _origin_px(), r.rect.size * ppm)
		n.draw_rect(rr.grow(-5.0), Color(col, 0.7 if r.index == mouse else 0.12), true)
