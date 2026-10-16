class_name AlertsStrip
extends Control
## The strip along the bottom: every current problem as a chip, worst first, pulsing. Fires, breaches,
## flooding, rooms running hot, systems failed or damaged, a worn or broken bit, coolant low or empty,
## a low hull. Each alert that belongs to a room names it. Nothing wrong shows a calm line instead.
##
## Mount (main.gd, on the HUD CanvasLayer, 1920x1080 design space):
##   var alerts: AlertsStrip = AlertsStrip.build(layer, sim)
##   alerts.bind(new_sim)
## `AlertsStrip.compute(sim)` is the pure part (tests and bots can read it).

const DESIGN_RECT: Rect2 = Rect2(0, 984, 1920, 96)
const CRITICAL: int = 70
const HEAT_MARGIN_C: float = 15.0
const DEFAULT_HEAT_C: float = 85.0
const FLOOD_MIN: float = 0.03
const BIT_WORN: float = 0.7
const COOLANT_LOW: int = 4
const HULL_LOW: float = 0.34
const CHIP_H: float = 34.0

var sim: Sim = null
var alerts: Array[Dictionary] = []
var _t: float = 0.0


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
	if s.drill.active:
		if s.drill.bit_broken:
			_add(out, 78, "bit", "BIT BROKEN", "")
		elif s.drill.bit_wear >= BIT_WORN:
			_add(out, 50, "bit", "BIT WORN %d%%" % roundi(s.drill.bit_wear * 100.0), "")
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


static func _add(out: Array[Dictionary], sev: int, kind: String, text: String, room: String) -> void:
	out.append({"sev": sev, "kind": kind, "text": text, "room": room})


func _process(delta: float) -> void:
	_t += delta
	if sim != null:
		alerts = compute(sim)
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
	var lamp := Vector2(46, size.y * 0.5)
	var lamp_col: Color = UiTheme.CRT_DIM
	if worst >= CRITICAL:
		lamp_col = UiTheme.ALARM.lerp(Color(1, 0.7, 0.6), UiTheme.pulse(_t, 2.2))
	elif worst > 0:
		lamp_col = UiTheme.AMBER
	else:
		lamp_col = UiTheme.CRT
	draw_circle(lamp, 17.0, UiTheme.STEEL_DEEP)
	draw_circle(lamp, 13.0, lamp_col)
	draw_circle(lamp + Vector2(-4, -4), 4.0, Color(1, 1, 1, 0.45))
	UiTheme.text(self, Vector2(76, size.y * 0.5 - 4.0), "ALERTS", 17, UiTheme.AMBER)
	UiTheme.text(self, Vector2(76, size.y * 0.5 + 16.0), "%d ACTIVE" % alerts.size(), 14, UiTheme.TEXT_DIM)
	if alerts.is_empty():
		UiTheme.glow_text(self, Vector2(220, size.y * 0.5 + 7.0), "ALL SYSTEMS NOMINAL", 22, UiTheme.CRT_DIM.lerp(UiTheme.CRT, 0.55))
		return
	var x0: float = 220.0
	var x: float = x0
	var row: int = 0
	var shown: int = 0
	for a: Dictionary in alerts:
		var label: String = str(a["text"])
		var w: float = UiTheme.text_width(label, 19) + 58.0
		if x + w > size.x - 40.0:
			if row == 1:
				break
			row += 1
			x = x0
		_draw_chip(Rect2(x, 12.0 + float(row) * (CHIP_H + 8.0), w, CHIP_H), a)
		x += w + 12.0
		shown += 1
	if shown < alerts.size():
		UiTheme.text(self, Vector2(size.x - 160.0, size.y - 14.0), "+%d MORE" % (alerts.size() - shown), 17, UiTheme.AMBER)


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
	UiTheme.icon(self, icon_for(str(a["kind"])), rect.position + Vector2(30, rect.size.y * 0.5), 20.0)
	UiTheme.text(self, Vector2(rect.position.x + 48.0, rect.position.y + 24.0), str(a["text"]), 19, UiTheme.TEXT if crit else UiTheme.BRASS_LIGHT)
