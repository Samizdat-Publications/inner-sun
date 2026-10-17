class_name AlertsStrip
extends Control
## The slim strip along the bottom (52 px): every current problem as a large chip, worst first, pulsing. Fires, breaches,
## flooding, rooms running hot, systems failed or damaged, a worn or broken bit, coolant low or empty,
## a low hull. Each alert that belongs to a room names it. Nothing wrong shows a calm line instead.
##
## Mount (main.gd, on the HUD CanvasLayer, 1920x1080 design space):
##   var alerts: AlertsStrip = AlertsStrip.build(layer, sim)
##   alerts.bind(new_sim)
## `AlertsStrip.compute(sim)` is the pure part (tests and bots can read it).

const DESIGN_RECT: Rect2 = Rect2(0, 1028, 1920, 52)
const CRITICAL: int = 70
const HEAT_MARGIN_C: float = 15.0
const DEFAULT_HEAT_C: float = 85.0
const FLOOD_MIN: float = 0.03
const BIT_WORN: float = 0.7
const COOLANT_LOW: int = 4
const HULL_LOW: float = 0.34
const DRILL_ROOM_DEEP_M: float = 1.2  ## Crew skip rooms deeper than 1.4 m on their own (crew_ai).
const CHIP_H: float = 38.0
const ALERT_FONT: int = 24
const MINER_SEV: int = 60  ## The away miner outside (a bit alert is 40 to 86).
const FAULT_LOOK_M: float = 6.0  ## Fault rock this close ahead raises the bracing alert.

var sim: Sim = null
var alerts: Array[Dictionary] = []
var _t: float = 0.0
var _pacer: RedrawPacer = RedrawPacer.new()  ## Redraws at most 60 times a second.


static func build(parent: Control, p_sim: Sim) -> AlertsStrip:
	var p := AlertsStrip.new()
	p.position = DESIGN_RECT.position
	p.size = DESIGN_RECT.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.bind(p_sim)
	return p


func bind(p_sim: Sim) -> void:
	sim = p_sim
	alerts = compute(sim) if sim != null else ([] as Array[Dictionary])
	queue_redraw()


## Every current alert, worst first: {"sev": int, "kind": String, "text": String, "room": String}.
static func compute(s: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var defs: Dictionary = s.db.table("systems")
	for r: Room in s.ship.rooms:
		var rn: String = r.name.to_upper()
		if r.fire > 0.05:
			_add(out, 100, "fire", "FIRE: %s" % rn, r.id)
		if r.breach_m2 > 0.0:
			_add(out, 90, "breach", "BREACH: %s" % rn, r.id)
		var cap: float = float(maxi(1, r.capacity_ml))
		var flood: float = float(r.water_ml) / cap
		if flood >= FLOOD_MIN:
			_add(out, 95 if flood >= 0.5 else 80, "flood", "FLOODING: %s %d%%" % [rn, roundi(flood * 100.0)], r.id)
		var def: Dictionary = defs.get(r.system, {})
		var limit: float = float(def.get("fail_c", DEFAULT_HEAT_C + HEAT_MARGIN_C)) - HEAT_MARGIN_C
		if r.temp_c() >= limit and not r.sys_failed:
			_add(out, 60, "heat", "%s %d C" % [rn, roundi(r.temp_c())], r.id)
		if r.sys_failed:
			_add(out, 75, "failed", "%s OFFLINE: %s %d C" % [str(def.get("name", r.system)).to_upper(), rn, roundi(r.temp_c())], r.id)
		elif r.sys_max > 0 and r.intact_bars() < r.sys_max:
			_add(out, 55, "damaged", "%s DAMAGED %d/%d: %s" % [str(def.get("name", r.system)).to_upper(), r.intact_bars(), r.sys_max, rn], r.id)
	var drill_ri: int = s.ship.room_with_system("drill")
	if drill_ri >= 0 and s.ship.rooms[drill_ri].level_m() > DRILL_ROOM_DEEP_M:
		_add(out, 93, "flood", "DRILL ROOM FLOODING: crew won't wade in on their own. Select one (1-3) and click the drill room.", s.ship.rooms[drill_ri].id)
	if s.run.mode == "run" and s.run.phase == "drill" and not s.run.target_node.is_empty():
		var kind: String = str(s.run.node(s.run.target_node).get("type", ""))
		if kind == "fight" or kind == "gate":
			_add(out, 65, "ahead", "HOSTILE AHEAD: power weapons (E) before you arrive", "")
		elif kind == "hazard":
			_add(out, 62, "ahead", "HAZARD AHEAD", "")
	var stop: Dictionary = drill_stop(s)
	if not str(stop.get("alert", "")).is_empty():
		_add(out, int(stop["sev"]), str(stop["kind"]), str(stop["alert"]), "")
	if s.drill.active and s.drill.miner.is_out():
		var mc: CrewMember = s.ship.crew_by_id(s.drill.miner.crew_id)
		if mc != null:
			_add(out, MINER_SEV, "miner", "MINER OUTSIDE: %s %d" % [mc.name.to_upper(), roundi(mc.hp)], "")
	var fault_m: float = fault_ahead_m(s, FAULT_LOOK_M)
	if fault_m >= 0.0 and s.systems.bracing_layers(s.player) <= 0:
		var bkey: String = power_key(s.ship, s.ship.room_with_system("bracing"))
		_add(out, 58, "fault", "FAULT ROCK AHEAD: power bracing (%s)" % bkey if not bkey.is_empty() else "FAULT ROCK AHEAD: power bracing", "")
	var coolant: int = s.run.get_res("coolant")
	if s.run.mode != "run":
		coolant = COOLANT_LOW + 1  # Scenarios do not bill coolant: no supply alerts there.
	if coolant <= 0:
		_add(out, 72, "coolant", "COOLANT EMPTY", "")
	elif coolant <= COOLANT_LOW:
		_add(out, 45, "coolant", "COOLANT LOW: %d" % coolant, "")
	var hull: int = s.run.get_res("hull")
	if float(hull) <= float(s.ship.hull_max) * HULL_LOW:
		_add(out, 88, "hull", "HULL LOW: %d/%d" % [hull, s.ship.hull_max], "")
	for i: int in range(out.size()):
		out[i]["order"] = i
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["sev"]) != int(b["sev"]):
			return int(a["sev"]) > int(b["sev"])
		return int(a["order"]) < int(b["order"]))
	return out


## Why the drill is stopped or crawling while a segment runs, said loudly enough to act on:
## {"sev", "kind", "alert" (the chip text, empty when another alert already names it), "notice" (the
## line over the world, empty when it needs no shouting)}, or {} while the drill cuts normally.
static func drill_stop(s: Sim) -> Dictionary:
	var d: DrillSim = s.drill
	if not d.active or s.run.phase != "drill":
		return {}
	if d.parked and d.miner.is_out():  # Parked on purpose: nothing else (power, a bit) is the reason it is not cutting.
		var mc: CrewMember = s.ship.crew_by_id(d.miner.crew_id)
		var who: String = mc.name.to_upper() if mc != null else "THE MINER"
		return {"sev": MINER_SEV, "kind": "miner", "alert": "", "notice": "PARKED: %s IS OUTSIDE. G recalls." % who}
	var ri: int = s.ship.room_with_system("drill")
	if ri < 0:
		return {}
	var r: Room = s.ship.rooms[ri]
	var bits: int = s.run.get_res("bits")
	if s.run.mode != "run":
		bits = maxi(bits, 1)  # Scenarios hand out bits freely.
	if d.bit_change_left_s > 0.0:
		return {"sev": 40, "kind": "bit", "alert": "FITTING NEW BIT: %d s" % ceili(d.bit_change_left_s), "notice": ""}
	if r.sys_failed:
		var def: Dictionary = s.db.table("systems").get("drill", {})
		var cool_key: String = power_key(s.ship, s.ship.room_with_system("coolant"))
		return {"sev": 75, "kind": "failed", "alert": "", "notice": "DRILL OVERHEATED (%d C): it restarts below %d C. Power COOLANT AND PUMPS (%s) to cool it faster." % [
				roundi(r.temp_c()), roundi(float(def.get("recover_c", 95.0))), cool_key]}
	if r.sys_max > 0 and r.intact_bars() == 0:
		return {"sev": 75, "kind": "damaged", "alert": "", "notice": "DRILL WRECKED: crew repair it on their own. Send one in to hurry (1-3, then click the drill room)."}
	if r.sys_power <= 0:
		var key: String = power_key(s.ship, ri)
		var notice: String = "DRILL HAS NO POWER. Press %s or click the DRILL bars on the power panel." % key
		if s.systems.free_bars(s.player) <= 0:
			notice += " The reactor is full: free a bar first (Shift plus another system's key)."
		return {"sev": 87, "kind": "power", "alert": "DRILL HAS NO POWER: press %s" % key, "notice": notice}
	if d.bit_broken:
		var crawl: int = roundi(s.db.tune("drill.broken_bit_factor") * 100.0)
		if bits > 0:
			return {"sev": 86, "kind": "bit", "alert": "BIT BROKEN: press B (%d spare)" % bits,
					"notice": "BIT BROKEN: the drill crawls at %d%% speed. Press B to fit a new one (%d spare)." % [crawl, bits]}
		return {"sev": 86, "kind": "bit", "alert": "BIT BROKEN: no spares",
				"notice": "BIT BROKEN and no spare bits: the drill crawls at %d%% speed. Buy bits at a trading post." % crawl}
	if d.at_wall:
		return {"sev": 84, "kind": "wall", "alert": "AT THE WALL: steer down (S)",
				"notice": "AT THE WALL: the drill is pressed against the side of the segment and cannot go on. Press S to steer straight down."}
	if d.bit_wear >= BIT_WORN:
		return {"sev": 50, "kind": "bit", "alert": "BIT WORN %d%%: B fits a new one" % roundi(d.bit_wear * 100.0), "notice": ""}
	return {}


## How far ahead (meters, along the heading, up to `look_m`) the drill meets fault rock, or -1.0 when
## the way is clear or the segment has none. Samples the footprint's leading edges as it would move.
static func fault_ahead_m(s: Sim, look_m: float) -> float:
	var d: DrillSim = s.drill
	if not d.active or s.run.phase != "drill" or not bool(d.survey.get("faults", false)):
		return -1.0
	var rad: float = deg_to_rad(d.heading_deg)
	var f := Vector2(sin(rad) * d.side_scale, cos(rad)).normalized()
	var step: float = d.cell_m
	var t: float = 0.0
	while t <= look_m:
		var pos: Vector2 = d.ship_pos + f * t
		var xs: Array[float] = [pos.x, pos.x + d.ship_size.x * 0.5, pos.x + d.ship_size.x]
		var ys: Array[float] = [pos.y + d.ship_size.y, pos.y + d.ship_size.y * 0.5]
		for yy: float in ys:
			for xx: float in xs:
				if _unstable_at(d, xx, yy):
					return t
		t += step
	return -1.0


static func _unstable_at(d: DrillSim, x: float, y: float) -> bool:
	var c: int = int(floor(x / d.cell_m))
	var r: int = int(floor(y / d.cell_m))
	if c < 0 or r < 0 or c >= d.cols or r >= d.rows:
		return false
	return d.unstable_of[d.grid[r * d.cols + c]] == 1


## The power panel key (Q W E R T Y) of a system's room, or "" when it has no row.
static func power_key(ship: Ship, ri: int) -> String:
	var row: int = PowerPanel.powered_rooms(ship).find(ri)
	if ri < 0 or row < 0 or row >= PowerPanel.KEY_NAMES.size():
		return ""
	return PowerPanel.KEY_NAMES[row]


static func _add(out: Array[Dictionary], sev: int, kind: String, text: String, room: String) -> void:
	out.append({"sev": sev, "kind": kind, "text": text, "room": room})


func _process(delta: float) -> void:
	_t += delta
	if sim != null:
		alerts = compute(sim)
	if _pacer.due():
		queue_redraw()


static func icon_for(kind: String) -> String:
	match kind:
		"fire", "heat":
			return "flame"
		"flood", "breach":
			return "drop"
		"bit":
			return "bits"
		"coolant":
			return "coolant"
		"hull":
			return "hull"
	return "warn"


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	UiTheme.draw_panel(self, rect, "", false)
	var worst: int = int(alerts[0]["sev"]) if not alerts.is_empty() else 0
	# The lamp on the left.
	var lamp := Vector2(36, size.y * 0.5)
	var lamp_col: Color = UiTheme.CRT_DIM
	if worst >= CRITICAL:
		lamp_col = UiTheme.ALARM.lerp(Color(1, 0.7, 0.6), UiTheme.pulse(_t, 2.2))
	elif worst > 0:
		lamp_col = UiTheme.AMBER
	else:
		lamp_col = UiTheme.CRT
	draw_circle(lamp, 15.0, UiTheme.STEEL_DEEP)
	draw_circle(lamp, 11.0, lamp_col)
	draw_circle(lamp + Vector2(-3, -3), 3.5, Color(1, 1, 1, 0.45))
	if alerts.is_empty():
		UiTheme.glow_text(self, Vector2(66, size.y * 0.5 + 7.0), "ALL SYSTEMS NOMINAL", 20, UiTheme.CRT_DIM.lerp(UiTheme.CRT, 0.55))
		return
	UiTheme.bold_text(self, Vector2(64, size.y * 0.5 + 7.0), "ALERTS %d" % alerts.size(), 20, UiTheme.AMBER)
	var x0: float = 200.0
	var x: float = x0
	var shown: int = 0
	for a: Dictionary in alerts:
		var label: String = str(a["text"])
		var w: float = UiTheme.text_width(label, ALERT_FONT) + 66.0
		if x + w > size.x - 150.0 and shown > 0:
			break
		_draw_chip(Rect2(x, (size.y - CHIP_H) * 0.5, w, CHIP_H), a)
		x += w + 12.0
		shown += 1
	if shown < alerts.size():
		UiTheme.bold_text(self, Vector2(size.x - 140.0, size.y * 0.5 + 8.0), "+%d MORE" % (alerts.size() - shown), 22, UiTheme.AMBER)


func _draw_chip(rect: Rect2, a: Dictionary) -> void:
	var sev: int = int(a["sev"])
	var crit: bool = sev >= CRITICAL
	var p: float = UiTheme.pulse(_t, 2.0 if crit else 0.9)
	var fill: Color = Color(0.30, 0.07, 0.06).lerp(Color(0.55, 0.10, 0.08), p) if crit else Color(0.22, 0.15, 0.05).lerp(Color(0.30, 0.20, 0.06), p)
	var edge: Color = UiTheme.ALARM if crit else UiTheme.AMBER
	draw_rect(rect, fill, true)
	if crit:
		UiTheme.hazard_stripes(self, Rect2(rect.position.x, rect.position.y, 12.0, rect.size.y))
	draw_rect(rect, edge.lerp(Color(1, 1, 1), 0.25 * p) if crit else edge, false, 2.0)
	UiTheme.icon(self, icon_for(str(a["kind"])), rect.position + Vector2(32, rect.size.y * 0.5), 24.0)
	UiTheme.bold_text(self, Vector2(rect.position.x + 54.0, rect.position.y + 28.0), str(a["text"]), ALERT_FONT, UiTheme.TEXT if crit else UiTheme.BRASS_LIGHT)
