class_name WeaponCards
extends Control
## The combat console above the alerts strip, shown only during a fight: one card per player weapon
## (name, power need and whether it is powered, charge bar, ammo for charges, current target room)
## and a FLEE button with its progress. Click a card, or press F1 to F3, to arm that weapon; the next
## left click on an enemy room (Main does the click) aims it. Right click a card clears its target.
## Escape disarms. Every action is a command: {"type": "target", "weapon": slot, "room": id} and
## {"type": "flee"}; nothing else changes.
##
## Mount (RunScreen, on the HUD CanvasLayer, 1920x1080 design space):
##   var weapons: WeaponCards = WeaponCards.build(layer, sim)
##   weapons.armed     # the armed weapon slot, -1 for none
##   weapons.bind(new_sim)
## `WeaponCards.flee_status(sim)` is the pure part (tests and bots can read it).

const DESIGN_RECT: Rect2 = Rect2(300.0, 888.0, 1240.0, 92.0)
const MARGIN: float = 8.0
const FLEE_W: float = 340.0
const KEYS: Array[Key] = [KEY_F1, KEY_F2, KEY_F3]
const SLOT_COLORS: Array[Color] = [Color(1.0, 0.70, 0.28), Color(0.45, 0.85, 1.0), Color(0.75, 0.95, 0.45)]

var sim: Sim = null
var armed: int = -1
var keys_enabled: bool = true
var _t: float = 0.0
var _hover: int = -2  ## A slot, -1 for the flee button, -2 for nothing.
var _charge_shown: PackedFloat32Array = PackedFloat32Array()


static func build(parent: Control, p_sim: Sim) -> WeaponCards:
	var p := WeaponCards.new()
	p.position = DESIGN_RECT.position
	p.size = DESIGN_RECT.size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	armed = -1
	_hover = -2
	_charge_shown = PackedFloat32Array()
	visible = false
	queue_redraw()


func in_fight() -> bool:
	return sim != null and sim.combat.active and sim.enemy != null


func disarm() -> void:
	armed = -1


## Why the player cannot dig out right now ("" if they can), plus the flee progress.
static func flee_status(s: Sim) -> Dictionary:
	var need: int = roundi(s.db.tune("combat.flee_drill_bars"))
	var why: String = ""
	if s.systems.drill_bars(s.player) < need:
		why = "NEEDS %d DRILL BARS" % need
	elif not s.systems.is_manned(s.player, s.ship.room_with_system("helm")):
		why = "NEEDS SOMEONE AT THE HELM"
	var fleeing: bool = s.combat.flee_ticks >= 0
	return {"allowed": why.is_empty(), "why": why, "fleeing": fleeing,
		"done_s": s.combat.flee_s(), "total_s": s.combat.flee_total_s()}


## The rectangle of weapon card i of n, in this control's own coordinates.
static func card_rect(i: int, n: int) -> Rect2:
	var room: float = DESIGN_RECT.size.x - FLEE_W - MARGIN * 3.0
	var w: float = minf(300.0, (room - MARGIN * float(maxi(0, n - 1))) / float(maxi(1, n)))
	return Rect2(MARGIN + float(i) * (w + MARGIN), MARGIN, w, DESIGN_RECT.size.y - MARGIN * 2.0)


static func flee_rect() -> Rect2:
	return Rect2(DESIGN_RECT.size.x - FLEE_W - MARGIN, MARGIN, FLEE_W, DESIGN_RECT.size.y - MARGIN * 2.0)


## -1 for the flee button, the slot for a card, -2 for neither.
func hit(p: Vector2) -> int:
	if sim == null:
		return -2
	if flee_rect().has_point(p):
		return -1
	var n: int = sim.combat.player_side.size()
	for i: int in range(n):
		if card_rect(i, n).has_point(p):
			return i
	return -2


func arm(slot: int) -> void:
	if not in_fight() or slot < 0 or slot >= sim.combat.player_side.size():
		return
	armed = -1 if armed == slot else slot


func _gui_input(event: InputEvent) -> void:
	if not in_fight():
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_hover = hit(mm.position)
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var h: int = hit(mb.position)
	if h == -1 and mb.button_index == MOUSE_BUTTON_LEFT:
		var st: Dictionary = flee_status(sim)
		if bool(st["allowed"]) and not bool(st["fleeing"]):
			sim.push({"type": "flee"})
		accept_event()
	elif h >= 0:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			arm(h)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			sim.push({"type": "target", "weapon": h, "room": ""})
			if armed == h:
				armed = -1
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or not keys_enabled or not in_fight():
		return
	if k.physical_keycode == KEY_ESCAPE and armed >= 0:
		armed = -1
		get_viewport().set_input_as_handled()
		return
	var slot: int = KEYS.find(k.physical_keycode)
	if slot >= 0 and slot < sim.combat.player_side.size():
		arm(slot)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -2


func _process(delta: float) -> void:
	_t += delta
	var fight: bool = in_fight()
	if visible != fight:
		visible = fight
		if not fight:
			armed = -1
	if not fight:
		return
	var n: int = sim.combat.player_side.size()
	if _charge_shown.size() != n:
		_charge_shown.resize(n)
	var wv: Array[Dictionary] = sim.combat.weapons_view(sim, false)
	for i: int in range(n):
		_charge_shown[i] = move_toward(_charge_shown[i], float(wv[i]["charge_s"]), 18.0 * delta)
	if armed >= n:
		armed = -1
	queue_redraw()


func _draw() -> void:
	if not in_fight():
		return
	UiTheme.draw_panel(self, Rect2(Vector2.ZERO, size), "", false)
	var wv: Array[Dictionary] = sim.combat.weapons_view(sim, false)
	var table: Dictionary = sim.db.table("weapons")
	for i: int in range(wv.size()):
		_draw_card(i, wv.size(), wv[i], table)
	_draw_flee()


func _draw_card(i: int, n: int, w: Dictionary, table: Dictionary) -> void:
	var r: Rect2 = card_rect(i, n)
	var def: Dictionary = table.get(str(w["id"]), {})
	var powered: bool = bool(w["powered"])
	var is_armed: bool = armed == i
	var slot_col: Color = SLOT_COLORS[i % SLOT_COLORS.size()]
	var charge: float = float(w["charge_s"])
	var cmax: float = maxf(0.01, float(w["charge_max_s"]))
	var ready: bool = charge >= cmax - 0.001
	var ammo_res: String = str(def.get("ammo", ""))
	var ammo_have: int = sim.run.get_res(ammo_res) if not ammo_res.is_empty() else 0
	var dry: bool = not ammo_res.is_empty() and ammo_have <= 0
	var p: float = UiTheme.pulse(_t, 2.4)
	var fill: Color = UiTheme.STEEL_LIGHT if (is_armed or _hover == i) else UiTheme.STEEL
	draw_rect(r, fill, true)
	var edge: Color = UiTheme.BRASS_DARK
	if is_armed:
		edge = UiTheme.AMBER.lerp(Color(1, 1, 1), 0.35 * p)
	elif not powered:
		edge = Color(0.55, 0.16, 0.12)
	elif ready and not dry:
		edge = UiTheme.CRT_DIM.lerp(UiTheme.CRT, p)
	draw_rect(r, edge, false, 3.0 if is_armed else 2.0)
	draw_rect(Rect2(r.position, Vector2(6.0, r.size.y)), slot_col if powered else UiTheme.AMBER_DIM, true)
	# Header: key badge, name, power chip.
	var x0: float = r.position.x + 16.0
	var badge := Rect2(x0, r.position.y + 7.0, 30.0, 20.0)
	draw_rect(badge, UiTheme.STEEL_DEEP, true)
	draw_rect(badge, UiTheme.BRASS_DARK, false, 1.0)
	UiTheme.text(self, badge.position + Vector2(0, 16), "F%d" % (i + 1), 14, UiTheme.BRASS_LIGHT, null, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)
	UiTheme.text(self, Vector2(x0 + 38.0, r.position.y + 24.0), str(w["name"]).to_upper(), 17, UiTheme.AMBER if powered else UiTheme.AMBER_DIM)
	var need: int = int(def.get("power", 1))
	var chip: String = "PWR %d" % need if powered else "NEEDS %d" % need
	UiTheme.text(self, Vector2(r.end.x - 90.0, r.position.y + 24.0), chip, 15, UiTheme.CRT if powered else UiTheme.ALARM, null, HORIZONTAL_ALIGNMENT_RIGHT, 80.0)
	# Charge bar.
	var bar := Rect2(x0, r.position.y + 34.0, r.size.x - 30.0, 14.0)
	draw_rect(bar, UiTheme.STEEL_DEEP, true)
	var frac: float = clampf(_charge_shown[i] / cmax, 0.0, 1.0) if i < _charge_shown.size() else 0.0
	var bar_col: Color = UiTheme.AMBER if powered else Color(0.35, 0.34, 0.33)
	if ready and powered and not dry:
		bar_col = UiTheme.CRT.lerp(Color(0.8, 1.0, 0.85), 0.4 * p)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), bar_col, true)
	draw_rect(bar, UiTheme.BRASS_DARK, false, 1.0)
	var bar_text: String = "NO CHARGES" if dry else "READY" if ready else ("%.0f / %.0f s" % [charge, cmax] if powered else "NO POWER")
	UiTheme.text(self, bar.position + Vector2(0, 12), bar_text, 12, UiTheme.STEEL_DEEP if frac > 0.5 else UiTheme.TEXT, null, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x)
	# Target line and ammo.
	var base_y: float = r.position.y + 70.0
	var target_id: String = str(w["target"])
	if is_armed and target_id.is_empty():
		UiTheme.text(self, Vector2(x0, base_y), "CLICK AN ENEMY ROOM", 14, UiTheme.AMBER.lerp(Color(1, 1, 1), 0.3 * p))
	elif is_armed:
		UiTheme.text(self, Vector2(x0, base_y), "AIMING...  CLICK A ROOM", 14, UiTheme.AMBER.lerp(Color(1, 1, 1), 0.3 * p))
	elif target_id.is_empty():
		UiTheme.text(self, Vector2(x0, base_y), "NO TARGET", 14, UiTheme.TEXT_DIM)
	else:
		var ri: int = sim.enemy.ship.room_index(target_id)
		var rn: String = sim.enemy.ship.rooms[ri].name.to_upper() if ri >= 0 else target_id.to_upper()
		UiTheme.text(self, Vector2(x0, base_y), "TARGET", 12, UiTheme.TEXT_DIM)
		UiTheme.text(self, Vector2(x0 + 58.0, base_y), rn, 15, slot_col)
	if not ammo_res.is_empty():
		var ax: float = r.end.x - 58.0
		UiTheme.icon(self, "charges", Vector2(ax, base_y - 5.0), 18.0, Color(1, 1, 1) if not dry else Color(0.5, 0.3, 0.3))
		UiTheme.text(self, Vector2(ax + 14.0, base_y), "x%d" % ammo_have, 16, UiTheme.ALARM if dry else UiTheme.TEXT)


func _draw_flee() -> void:
	var r: Rect2 = flee_rect()
	var st: Dictionary = flee_status(sim)
	var allowed: bool = bool(st["allowed"])
	var fleeing: bool = bool(st["fleeing"])
	var p: float = UiTheme.pulse(_t, 2.0)
	var hov: bool = _hover == -1
	draw_rect(r, UiTheme.STEEL_LIGHT if (hov and allowed and not fleeing) else UiTheme.STEEL_DARK, true)
	var edge: Color = UiTheme.BRASS_DARK
	if fleeing:
		edge = UiTheme.AMBER if allowed else UiTheme.ALARM
	elif allowed:
		edge = UiTheme.CRT_DIM.lerp(UiTheme.CRT, 0.5 + 0.5 * p)
	draw_rect(r, edge, false, 2.0)
	UiTheme.hazard_stripes(self, Rect2(r.position.x + 6.0, r.position.y + 6.0, 10.0, r.size.y - 12.0))
	var x0: float = r.position.x + 28.0
	var title: String = "DIGGING OUT" if fleeing else "FLEE"
	var col: Color = UiTheme.AMBER if (allowed or fleeing) else UiTheme.AMBER_DIM
	UiTheme.text(self, Vector2(x0, r.position.y + 28.0), title, 22, col)
	if fleeing:
		var bar := Rect2(x0, r.position.y + 40.0, r.size.x - 44.0, 14.0)
		var frac: float = clampf(float(st["done_s"]) / maxf(0.01, float(st["total_s"])), 0.0, 1.0)
		draw_rect(bar, UiTheme.STEEL_DEEP, true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), UiTheme.CRT if allowed else UiTheme.ALARM, true)
		draw_rect(bar, UiTheme.BRASS_DARK, false, 1.0)
		var line: String = "%.0f / %.0f s" % [float(st["done_s"]), float(st["total_s"])]
		UiTheme.text(self, Vector2(x0, r.position.y + 72.0), line if allowed else "STALLED: " + str(st["why"]), 14, UiTheme.TEXT if allowed else UiTheme.ALARM)
	elif allowed:
		UiTheme.text(self, Vector2(x0, r.position.y + 50.0), "CLICK TO DIG OUT", 15, UiTheme.CRT)
		UiTheme.text(self, Vector2(x0, r.position.y + 70.0), "TAKES %.0f s, DRILL AND HELM MANNED" % float(st["total_s"]), 12, UiTheme.TEXT_DIM)
	else:
		UiTheme.text(self, Vector2(x0, r.position.y + 50.0), "NOT ALLOWED", 15, UiTheme.ALARM)
		UiTheme.text(self, Vector2(x0, r.position.y + 70.0), str(st["why"]), 13, UiTheme.TEXT_DIM)
