class_name ShipPick
extends Node2D
## Clicking the cutaway itself (a child of the player's ShipView, so it shares the ship's pixels):
##  - a click on a door or hatch shuts or opens it, a click on a room's vent button purges it (or stops);
##  - a click on a crew figure selects it, Shift adds or removes one;
##  - a drag that starts on empty floor draws a box and selects the figures inside it;
##  - a click on a room sends every selected crew member there (one "assign" command each);
##  - Esc, or a click on empty space outside the ship, clears the selection.
## Every order is a plain command pushed on the sim, like the bots' (replays stay plain commands). The
## view only remembers who is selected; the first of them is the card selection (cards.selected_id).

const DRAG_PX: float = 6.0  ## Screen pixels the mouse must travel before a press becomes a box.

var m: Main
var ids: Array[String] = []  ## The selected crew, first is the primary (the one the crew cards show).
var cleared: bool = false  ## Esc or an empty click: nobody selected until the next pick.
var box: Rect2 = Rect2()  ## The drag box in ship pixels, while dragging.
var _down: bool = false
var _dragging: bool = false
var _start: Vector2 = Vector2.ZERO  ## Ship pixels.
var _start_screen: Vector2 = Vector2.ZERO
var _shift: bool = false
var _sim: Sim = null
var _internal: bool = false
var _hand: bool = false


static func of(main: Main) -> ShipPick:
	for n: Node in main.view.get_children():
		if n is ShipPick:
			return n as ShipPick
	var p := ShipPick.new()
	p.setup(main)
	main.view.add_child(p)
	return p


func setup(main: Main) -> void:
	m = main
	z_index = 20
	material = ArtLib.unshaded()
	modulate = Color(1.8, 1.8, 1.8, 1.0)
	if m.screen != null:
		m.screen.cards.crew_selected.connect(_on_card)


func _on_card(id: String) -> void:
	if _internal:
		return
	ids.assign([id])
	cleared = false


## The selected crew ids now (live ones; the card's crew member when nothing else is picked).
func current() -> Array[String]:
	if m.run == null:
		return []
	var s: Sim = m.run.sim
	if s != _sim:
		_sim = s
		ids.clear()
		cleared = false
	if cleared:
		return []
	var out: Array[String] = []
	for id: String in ids:
		var c: CrewMember = s.ship.crew_by_id(id)
		if c != null and c.alive:
			out.append(id)
	if out.is_empty():
		var c2: CrewMember = m.screen.selected_crew()
		if c2 != null:
			out.append(c2.id)
	return out


## Every frame (Main._process): the rings on the figures.
func sync() -> void:
	m.view.selected_crew_id = ""
	m.view.selected_ids = current()


func clear() -> void:
	ids.clear()
	cleared = true
	_cancel()


func select_ids(list: Array[String]) -> void:
	ids.assign(list)
	cleared = ids.is_empty()
	if not ids.is_empty():
		_internal = true
		m.screen.cards.select(ids[0])
		_internal = false


func _local(screen_pos: Vector2) -> Vector2:
	return m.view.get_global_transform_with_canvas().affine_inverse() * screen_pos


func _ship() -> Ship:
	return m.run.sim.ship


## The wanted state once the orders already queued are counted (so two clicks before a step flip twice).
func _wanted(kind: String, key: String, id: String, now: bool) -> bool:
	var want: bool = now
	for cmd: Dictionary in m.run.sim._pending:
		if str(cmd.get("type", "")) == kind and str(cmd.get(key, "")) == id:
			want = bool(cmd.get("open", want))
	return want


## A left press on the ship. True when it was used (so no other order considers it).
func press(mb: InputEventMouseButton) -> bool:
	var s: Sim = m.run.sim
	var p: Vector2 = _local(mb.position)
	var hit: Dictionary = ShipHits.link_at(_ship(), p, Main.PPM)
	if not hit.is_empty():
		var l: Link = _ship().links[int(hit["link"])]
		s.push({"type": "door", "link": l.id, "open": not _wanted("door", "link", l.id, l.open)})
		return true
	var vr: int = ShipHits.vent_at(_ship(), p, Main.PPM)
	if vr >= 0:
		var room: Room = _ship().rooms[vr]
		s.push({"type": "purge", "room": room.id, "open": not _wanted("purge", "room", room.id, s.hazards.is_purged(vr))})
		return true
	var fig: String = ShipHits.crew_at(_ship(), p, Main.PPM)
	if not fig.is_empty():
		var now: Array[String] = current()
		if mb.shift_pressed:
			if fig in now:
				now.erase(fig)
			else:
				now.append(fig)
			select_ids(now)
		else:
			select_ids([fig])
		return true
	if _ship().room_at(p / Main.PPM + Vector2(0, 0.06), -1) >= 0:
		_down = true
		_dragging = false
		_start = p
		_start_screen = mb.position
		_shift = mb.shift_pressed
		return true
	# Empty space outside the ship: let the combat view's enemy rooms keep their clicks, else clear.
	if m.combat_view.active() and m.combat_view.enemy_room_at(mb.position) >= 0:
		return false
	if RunScreen.WORLD_RECT.has_point(mb.position) and not mb.shift_pressed:
		clear()
		return true
	return false


## The mouse moved: grow the box, and the pointing hand over anything clickable.
func motion(ev: InputEventMouseMotion) -> void:
	if _down:
		if (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_cancel()
		else:
			if not _dragging and ev.position.distance_to(_start_screen) >= DRAG_PX:
				_dragging = true
			if _dragging:
				var q: Vector2 = _local(ev.position)
				box = Rect2(_start, Vector2.ZERO).expand(q)
				queue_redraw()
	var p: Vector2 = _local(ev.position)
	var on: bool = (not _down) and (not ShipHits.link_at(_ship(), p, Main.PPM).is_empty() or ShipHits.vent_at(_ship(), p, Main.PPM) >= 0 or not ShipHits.crew_at(_ship(), p, Main.PPM).is_empty())
	if on != _hand:
		_hand = on
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND if on else DisplayServer.CURSOR_ARROW)


## The left button came up: a box selects, a plain click sends the selected crew to that room.
func release(mb: InputEventMouseButton) -> bool:
	if not _down:
		return false
	var was_drag: bool = _dragging
	var start: Vector2 = _start
	var shift: bool = _shift
	_cancel()
	if was_drag:
		var inside: Array[String] = ShipHits.crew_in(_ship(), Rect2(start, Vector2.ZERO).expand(_local(mb.position)), Main.PPM)
		if shift:
			for id: String in current():
				if not id in inside:
					inside.append(id)
		select_ids(inside)
		if inside.is_empty():
			clear()
		return true
	var room: int = _ship().room_at(start / Main.PPM + Vector2(0, 0.06), -1)
	if room >= 0:
		for id: String in current():
			var c: CrewMember = _ship().crew_by_id(id)
			if c != null and c.alive and not c.away:
				m.run.sim.push({"type": "assign", "crew": id, "room": _ship().rooms[room].id})
	return true


## Dev only (MainPoke): show a drag box over `rect` (ship pixels) and select the figures in it.
func demo_box(rect: Rect2) -> void:
	box = rect
	_dragging = true
	select_ids(ShipHits.crew_in(_ship(), rect, Main.PPM))
	queue_redraw()


func _cancel() -> void:
	_down = false
	_dragging = false
	box = Rect2()
	queue_redraw()


func _draw() -> void:
	if not _dragging or box.size == Vector2.ZERO:
		return
	var k: float = 1.0 / maxf(0.2, get_global_transform_with_canvas().get_scale().x)
	draw_rect(box, Color(1.0, 0.72, 0.2, 0.16), true)
	draw_rect(box, Color(1.0, 0.8, 0.3, 0.95), false, 2.5 * k)
	var tick: float = 10.0 * k
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		draw_rect(Rect2(corner - Vector2(tick, tick) * 0.5, Vector2(tick, tick)), Color(1.0, 0.9, 0.5, 1.0), true)
