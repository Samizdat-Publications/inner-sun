class_name PowerPanel
extends Control
## The power board: the reactor's bars (in use, free, lost) and one row per powered system. Click a
## bar to set that system to that many bars (click the last lit bar to drop one), right click or
## scroll to change by one, or press the row's key (Q W E R T Y): the key adds a bar, Shift plus the
## key takes one away. Every change is {"type": "power", "room": id, "bars": n} through sim.push.
## Shows who stands at a station (crew mark) and the bracing layers.
##
## Bar looks (shape as well as color): lit = solid amber, idle = hollow, damaged = dark with a red
## cross, heat-failed = hatched orange outline.
##
## Mount (main.gd, on the HUD CanvasLayer, 1920x1080 design space):
##   var power: PowerPanel = PowerPanel.build(layer, sim)
##   power.bind(new_sim)
## Set `keys_enabled = false` while an overlay is open. Needs the keys Q W E R T Y unused elsewhere.

const WIDTH: float = 340.0
const ROW_H: float = 92.0
const ROW_TOP: float = 160.0
const KEYS: Array[Key] = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
const KEY_NAMES: Array[String] = ["Q", "W", "E", "R", "T", "Y"]
## What each system does now, in a few words under its bars (UI text, by system id).
const JOBS: Dictionary = {
	"helm": "turn and side cut",
	"bracing": "soaks rockfalls and hits",
	"weapons": "guns and blast charges",
	"drill": "speed, heat, noise",
	"coolant": "cooling, pumps, douse",
}

var sim: Sim = null
var keys_enabled: bool = true
var _t: float = 0.0
var _pacer: RedrawPacer = RedrawPacer.new()  ## Redraws at most 60 times a second.
var _rows: Array[int] = []  ## Room indices of the powered systems, in ship order.
var _shown: Dictionary = {}  ## room index -> eased lit bars (float).
var _used_shown: float = 0.0
var _hover_room: int = -1
var _hover_bar: int = -1
var _pend: Dictionary = {}  ## room index -> {"bars": wanted bars, "tick": sim tick of the push}.


static func build(parent: Control, p_sim: Sim) -> PowerPanel:
	var p := PowerPanel.new()
	p.position = Vector2(0, 90)
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_shown.clear()
	_pend.clear()
	_rows = powered_rooms(sim.ship) if sim != null else ([] as Array[int])
	size = Vector2(WIDTH, ROW_TOP + float(_rows.size()) * ROW_H + 140.0)
	snap()
	queue_redraw()


func snap() -> void:
	if sim == null:
		return
	for ri: int in _rows:
		_shown[ri] = float(sim.ship.rooms[ri].sys_power)
	_used_shown = float(sim.systems.allocated(sim.player))


## Rooms that take power: a system that is neither none nor the reactor, with capacity.
static func powered_rooms(ship: Ship) -> Array[int]:
	var out: Array[int] = []
	for r: Room in ship.rooms:
		if r.system != "none" and r.system != "reactor" and r.sys_max > 0:
			out.append(r.index)
	return out


## The rectangle of bar `i` of a row with `n` bars (panel space).
static func bar_rect(row: int, i: int, n: int) -> Rect2:
	var avail: float = WIDTH - 36.0
	var gap: float = 4.0
	var w: float = minf(52.0, (avail - gap * float(n - 1)) / float(maxi(1, n)))
	return Rect2(18.0 + float(i) * (w + gap), ROW_TOP + float(row) * ROW_H + 32.0, w, 34.0)


## Which (row, bar) is at a panel-space point, or Vector2i(-1, -1).
func hit(p: Vector2) -> Vector2i:
	if sim == null:
		return Vector2i(-1, -1)
	for row: int in range(_rows.size()):
		var n: int = sim.ship.rooms[_rows[row]].sys_max
		for i: int in range(n):
			if bar_rect(row, i, n).grow(2.0).has_point(p):
				return Vector2i(row, i)
	return Vector2i(-1, -1)


## The bars a click on bar `i` asks for, given what is lit now.
static func target_bars(lit: int, i: int) -> int:
	return i if i + 1 == lit else i + 1


## The bars a row will have once the queued order applies, or -1 when nothing is queued. An order
## stays pending until the sim steps past the tick it was pushed on or its value is reached.
func pending_bars(ri: int) -> int:
	if sim == null or not _pend.has(ri):
		return -1
	var p: Dictionary = _pend[ri]
	if int(p["tick"]) != sim.tick or int(p["bars"]) == sim.ship.rooms[ri].sys_power:
		_pend.erase(ri)
		return -1
	return int(p["bars"])


## What the row is heading for: its queued order, or what the sim last granted it.
func wanted_bars(ri: int) -> int:
	var p: int = pending_bars(ri)
	return p if p >= 0 else sim.ship.rooms[ri].sys_power


func set_bars(row: int, bars: int) -> void:
	if sim == null or row < 0 or row >= _rows.size():
		return
	var ri: int = _rows[row]
	var r: Room = sim.ship.rooms[ri]
	# The reactor has only so many bars: count what the other rows are heading for.
	var others: int = 0
	for oi: int in _rows:
		if oi != ri:
			others += wanted_bars(oi)
	var room_left: int = maxi(0, sim.systems.reactor_output(sim.player) - others)
	var granted: int = mini(clampi(bars, 0, r.intact_bars()), room_left)
	_pend[ri] = {"bars": granted, "tick": sim.tick}
	sim.push({"type": "power", "room": r.id, "bars": clampi(bars, 0, r.sys_max)})


func change_bars(row: int, delta: int) -> void:
	if sim == null or row < 0 or row >= _rows.size():
		return
	set_bars(row, wanted_bars(_rows[row]) + delta)


func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		var h: Vector2i = hit(mm.position)
		_hover_room = h.x
		_hover_bar = h.y
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var h2: Vector2i = hit(mb.position)
	if h2.x < 0:
		return
	var room: Room = sim.ship.rooms[_rows[h2.x]]
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			set_bars(h2.x, target_bars(wanted_bars(room.index), h2.y))
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_DOWN:
			change_bars(h2.x, -1)
		MOUSE_BUTTON_WHEEL_UP:
			change_bars(h2.x, 1)
	accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not keys_enabled or sim == null or not takes_orders(sim):
		return
	var row: int = KEYS.find(k.physical_keycode)
	if row < 0 or row >= _rows.size():
		return
	change_bars(row, -1 if k.shift_pressed else 1)
	get_viewport().set_input_as_handled()


## Power orders are allowed while the world runs and while a dossier is open (options need power).
static func takes_orders(s: Sim) -> bool:
	return s.run.world_running() or s.run.phase == "dialog"


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_room = -1
		_hover_bar = -1


func _process(delta: float) -> void:
	_t += delta
	if sim != null:
		for ri: int in _rows:
			_shown[ri] = move_toward(float(_shown.get(ri, 0.0)), float(sim.ship.rooms[ri].sys_power), 9.0 * delta)
		_used_shown = move_toward(_used_shown, float(sim.systems.allocated(sim.player)), 9.0 * delta)
	if _pacer.due():
		queue_redraw()


func _draw() -> void:
	UiTheme.draw_panel(self, Rect2(Vector2.ZERO, size), "POWER")
	if sim == null:
		return
	_draw_reactor()
	var sys_defs: Dictionary = sim.db.table("systems")
	for row: int in range(_rows.size()):
		_draw_row(row, sys_defs)
	_draw_bracing()
	_draw_legend()


func _draw_reactor() -> void:
	var ri: int = sim.ship.room_with_system("reactor")
	UiTheme.bold_text(self, Vector2(18, 62), "REACTOR", 20, UiTheme.AMBER)
	if ri < 0:
		return
	var r: Room = sim.ship.rooms[ri]
	var out: int = sim.systems.reactor_output(sim.player)
	var used: int = sim.systems.allocated(sim.player)
	var n: int = maxi(1, r.sys_max)
	var avail: float = WIDTH - 36.0
	var gap: float = 3.0
	var w: float = minf(30.0, (avail - gap * float(n - 1)) / float(n))
	for i: int in range(n):
		var rect := Rect2(18.0 + float(i) * (w + gap), 72.0, w, 32.0)
		var kind: String = "off"
		if i < used:
			kind = "on"
		elif i < out:
			kind = "free"
		elif i >= r.intact_bars():
			kind = "damaged"
		elif r.sys_failed:
			kind = "hot"
		var a: float = 1.0
		if kind == "on":
			a = clampf(_used_shown - float(i), 0.0, 1.0) * 0.6 + 0.4
		_draw_bar(rect, kind, a)
	UiTheme.bold_text(self, Vector2(18, 132), "IN USE %d" % used, 20, UiTheme.AMBER)
	UiTheme.bold_text(self, Vector2(160, 132), "FREE %d" % maxi(0, out - used), 20, UiTheme.CRT if out > used else UiTheme.TEXT_DIM)
	UiTheme.text(self, Vector2(WIDTH - 178, 62), "OUTPUT %d" % out, 19, UiTheme.TEXT if out > 0 else UiTheme.ALARM, null, HORIZONTAL_ALIGNMENT_RIGHT, 160.0)
	draw_line(Vector2(18, 146), Vector2(WIDTH - 18, 146), UiTheme.BRASS_DARK, 1.0)


func _draw_row(row: int, sys_defs: Dictionary) -> void:
	var r: Room = sim.ship.rooms[_rows[row]]
	var def: Dictionary = sys_defs.get(r.system, {})
	var y: float = ROW_TOP + float(row) * ROW_H
	# Key badge, name, count and station mark.
	var badge := Rect2(18, y + 2, 26, 26)
	draw_rect(badge, UiTheme.STEEL_DEEP, true)
	draw_rect(badge, UiTheme.BRASS, false, 1.0)
	UiTheme.text(self, Vector2(badge.position.x, y + 22), KEY_NAMES[row] if row < KEY_NAMES.size() else "", 18, UiTheme.BRASS_LIGHT, null, HORIZONTAL_ALIGNMENT_CENTER, 26.0)
	var failed: bool = r.sys_failed
	var dim: bool = r.intact_bars() <= 0
	var name_col: Color = UiTheme.TEXT_DIM if dim else (UiTheme.FIRE if failed else UiTheme.TEXT)
	UiTheme.text(self, Vector2(52, y + 22), str(def.get("name", r.system)).to_upper(), 18, name_col)
	UiTheme.bold_text(self, Vector2(WIDTH - 78, y + 23), "%d/%d" % [r.effective_bars(), r.sys_max], 24, UiTheme.AMBER if r.effective_bars() > 0 else UiTheme.TEXT_DIM, null, HORIZONTAL_ALIGNMENT_RIGHT, 60.0)
	var wants_crew: bool = bool(def.get("needs_crew", false)) or float(def.get("manned_bonus", 0.0)) > 0.0
	if wants_crew:
		var manned: bool = sim.systems.is_manned(sim.player, r.index)
		var c: Color = UiTheme.CRT if manned else Color(0.35, 0.37, 0.37)
		if not manned and bool(def.get("needs_crew", false)) and r.sys_power > 0:
			c = UiTheme.ALARM.lerp(Color(0.35, 0.37, 0.37), UiTheme.pulse(_t, 1.4))
		UiTheme.icon(self, "crew", Vector2(238, y + 15), 20.0, c)
	var n: int = r.sys_max
	var lit: float = float(_shown.get(r.index, float(r.sys_power)))
	var intact: int = r.intact_bars()
	var pend: int = pending_bars(r.index)
	for i: int in range(n):
		var rect: Rect2 = bar_rect(row, i, n)
		var kind: String = "off"
		var a: float = 1.0
		if i >= intact:
			kind = "damaged"
		elif failed and i < r.sys_power:
			kind = "hot"
		elif float(i) < lit:
			kind = "on"
			a = clampf(lit - float(i), 0.0, 1.0) * 0.6 + 0.4
		if pend >= 0 and i < intact:
			# A queued order: bars about to light blink outlined, bars about to drop blink dim.
			if i < pend and i >= r.sys_power:
				kind = "pend_on"
				a = 0.35 + 0.65 * UiTheme.pulse(_t, 2.4)
			elif i >= pend and i < r.sys_power:
				kind = "pend_off"
				a = 0.35 + 0.65 * UiTheme.pulse(_t, 2.4)
		_draw_bar(rect, kind, a)
		if _hover_room == row and i <= _hover_bar:
			draw_rect(rect.grow(1.0), Color(1, 1, 1, 0.16), true)
			draw_rect(rect.grow(1.0), UiTheme.BRASS_LIGHT, false, 1.0)
	var job: String = str(JOBS.get(r.system, ""))
	if not job.is_empty():
		UiTheme.text(self, Vector2(18, y + 84.0), job, 14, UiTheme.TEXT_DIM)
	if failed:
		var flick: float = 0.65 + 0.35 * UiTheme.pulse(_t, 2.4)
		UiTheme.icon(self, "flame", Vector2(262, y + 15), 20.0, Color(1, 1, 1, flick))


func _draw_bar(rect: Rect2, kind: String, a: float) -> void:
	match kind:
		"on":
			draw_rect(rect, Color(UiTheme.AMBER, a), true)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), Color(1, 1, 1, 0.22 * a), true)
			draw_rect(rect, UiTheme.BRASS_LIGHT, false, 1.0)
		"free":
			draw_rect(rect, Color(UiTheme.CRT, 0.85), true)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), Color(1, 1, 1, 0.25), true)
			draw_rect(rect, UiTheme.CRT, false, 1.0)
		"pend_on":
			draw_rect(rect, Color(UiTheme.AMBER, 0.28 * a), true)
			draw_rect(rect, Color(UiTheme.BRASS_LIGHT, a), false, 3.0)
		"pend_off":
			draw_rect(rect, Color(UiTheme.AMBER, 0.55 * (1.0 - a) + 0.1), true)
			draw_rect(rect, Color(UiTheme.ALARM, a), false, 3.0)
		"damaged":
			draw_rect(rect, Color(0.10, 0.04, 0.04), true)
			draw_rect(rect, Color(UiTheme.ALARM, 0.8), false, 1.0)
			draw_line(rect.position + Vector2(3, 3), rect.end - Vector2(3, 3), UiTheme.ALARM, 2.0)
			draw_line(Vector2(rect.end.x - 3, rect.position.y + 3), Vector2(rect.position.x + 3, rect.end.y - 3), UiTheme.ALARM, 2.0)
		"hot":
			draw_rect(rect, Color(0.17, 0.08, 0.03), true)
			var h: float = rect.size.y - 2.0
			var x: float = rect.position.x - h
			while x < rect.end.x:
				var p0 := Vector2(x, rect.end.y - 1.0)
				var p1 := Vector2(x + h, rect.position.y + 1.0)
				if p0.x < rect.position.x + 1.0:
					p0 = Vector2(rect.position.x + 1.0, p0.y - (rect.position.x + 1.0 - x))
				if p1.x > rect.end.x - 1.0:
					p1 = Vector2(rect.end.x - 1.0, p1.y + (x + h - (rect.end.x - 1.0)))
				if p1.x > p0.x:
					draw_line(p0, p1, Color(UiTheme.FIRE, 0.85), 2.0)
				x += 7.0
			draw_rect(rect, UiTheme.FIRE, false, 1.5)
		_:
			draw_rect(rect, UiTheme.STEEL_DEEP, true)
			draw_rect(rect, UiTheme.AMBER_DIM, false, 1.0)


func _draw_bracing() -> void:
	var y: float = ROW_TOP + float(_rows.size()) * ROW_H + 8.0
	draw_line(Vector2(18, y - 4), Vector2(WIDTH - 18, y - 4), UiTheme.BRASS_DARK, 1.0)
	UiTheme.bold_text(self, Vector2(18, y + 24), "BRACING LAYERS", 19, UiTheme.AMBER)
	var layers: int = sim.systems.bracing_layers(sim.player)
	var most: int = maxi(layers, sim.systems.max_layers(sim.player))
	for i: int in range(most):
		var c := Vector2(32.0 + float(i) * 38.0, y + 56.0)
		if i < layers:
			UiTheme.icon(self, "shield", c, 32.0)
		else:
			UiTheme.icon(self, "shield", c, 32.0, Color(0.22, 0.24, 0.26))
	if most == 0:
		UiTheme.text(self, Vector2(18, y + 60.0), "NONE", 18, UiTheme.TEXT_DIM)


func _draw_legend() -> void:
	var y: float = size.y - 20.0
	var x: float = 18.0
	var items: Array[String] = ["on", "off", "damaged", "hot"]
	var names: Array[String] = ["LIT", "IDLE", "DOWN", "HOT"]
	for i: int in range(items.size()):
		_draw_bar(Rect2(x, y - 13.0, 16.0, 15.0), items[i], 1.0)
		UiTheme.text(self, Vector2(x + 21.0, y), names[i], 14, UiTheme.TEXT)
		x += 78.0
