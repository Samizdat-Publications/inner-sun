class_name DigCallouts
extends Control
## Short messages over the top of the world area for the dig verbs, from the sim's events:
##  - a "ROCKFALL IN 1.2 S" chip from the warning ("rockfall_warn") until the impact;
##  - on the impact ("rockfall"): "BRACING HELD" (green) or "ROCKFALL: HULL -1, <ROOM> DAMAGED" (red);
##  - "BLAST: 14 CELLS, +6 ORE" after a blast, "DOUSED: <ROOM>" and "FIRE OUT" after a douse;
##  - the sim's reason when an order was refused ("bad_command" for a blast or a douse).
## Follows `sim.events` by index (read only) and ages the messages by real seconds, like DigLog.
##
## Mount (RunScreen, on the HUD layer, above the dig tally):  DigCallouts.build(layer, sim)

const POS_Y: float = 142.0
const ENV_CHIP_Y: float = 186.0
const LIFE_S: float = 3.0
const MAX_LINES: int = 3
const FONT: int = 22

var sim: Sim = null
var lines: Array[Dictionary] = []  ## {text, kind ("good" | "bad" | "info"), age}
var _seen: int = 0
var _t: float = 0.0
var _pacer: RedrawPacer = RedrawPacer.new()


static func build(parent: Control, p_sim: Sim) -> DigCallouts:
	var c := DigCallouts.new()
	c.position = Vector2.ZERO
	c.size = Vector2(1920, 1080)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.bind(p_sim)
	return c


func bind(p_sim: Sim) -> void:
	sim = p_sim
	lines.clear()
	_seen = sim.events.size() if sim != null else 0
	queue_redraw()


## The message an event makes: {"text", "kind"} or {} when it says nothing here. Pure (tests read it).
static func message_for(s: Sim, e: Dictionary) -> Dictionary:
	match str(e.get("kind", "")):
		"rockfall":
			if bool(e.get("absorbed", false)):
				return {"text": "BRACING HELD", "kind": "good"}
			var hull: int = int(e.get("hull", 0))
			var rn: String = _room_name(s, str(e.get("room", "")))
			var text: String = "ROCKFALL: HULL -%d" % hull if hull > 0 else "ROCKFALL"
			if not rn.is_empty():
				text += ", %s DAMAGED" % rn
			return {"text": text, "kind": "bad"}
		"blast":
			var bits: PackedStringArray = PackedStringArray(["%d CELLS" % int(e.get("cells", 0))])
			var ore: int = int(e.get("ore", 0))
			var gems: int = int(e.get("gems", 0))
			if ore > 0:
				bits.append("+%d ORE" % ore)
			if gems > 0:
				bits.append("+%d GEMS" % gems)
			if bool(e.get("drained", false)):
				bits.append("POCKET DRAINED")
			if bool(e.get("burned", false)):
				bits.append("GAS BURNED OFF")
			return {"text": "BLAST: " + ", ".join(bits), "kind": "info"}
		"doused":
			var dn: String = _room_name(s, str(e.get("room", "")))
			return {"text": "DOUSED: %s" % dn if not dn.is_empty() else "DOUSED", "kind": "good"}
		"fire_out":
			if str(e.get("by", "")) == "douse":
				return {"text": "FIRE OUT", "kind": "good"}
			if str(e.get("by", "")) == "purge":
				var pn: String = _room_name(s, str(e.get("room", "")))
				return {"text": "PURGED: %s" % pn if not pn.is_empty() else "PURGED", "kind": "good"}
		"env_entered":
			var en: String = env_name(s, str(e.get("env", "")))
			if not en.is_empty():
				return {"text": en, "kind": "info"}
		"bad_command":
			var t: String = str(e.get("type", ""))
			var why: String = str(e.get("why", ""))
			if t == "blast":
				return {"text": "BLAST REFUSED: " + (BlastCard.reason_text(s, why) if why != "out of range" else "OUT OF RANGE"), "kind": "bad"}
			if t == "douse":
				var rt: String = DouseLayer.reason_text(s, why)
				return {"text": "DOUSE REFUSED: " + (rt if not rt.is_empty() else why.to_upper()), "kind": "bad"}
	return {}


static func _room_name(s: Sim, id: String) -> String:
	var ri: int = s.ship.room_index(id)
	return s.ship.rooms[ri].name.to_upper() if ri >= 0 else ""


## An environment's name in capitals ("ROCKFALL SEAM"), "" for none.
static func env_name(s: Sim, id: String) -> String:
	if id.is_empty():
		return ""
	return str((s.db.table("environments").get(id, {}) as Dictionary).get("name", id)).to_upper()


## "ROCKFALL IN 1.2 S" while one is on its way, else "".
static func warn_text(s: Sim) -> String:
	var ticks: int = s.drill.verbs.rockfall_ticks
	if not s.drill.active or ticks <= 0:
		return ""
	return "ROCKFALL IN %.1f S" % (float(ticks) / Sim.TICK_HZ)


func push_line(text: String, kind: String) -> void:
	lines.push_front({"text": text, "kind": kind, "age": 0.0})
	while lines.size() > MAX_LINES:
		lines.pop_back()


func _process(delta: float) -> void:
	_t += delta
	if sim == null:
		return
	var n: int = sim.events.size()
	if n < _seen:
		_seen = 0
	for i: int in range(_seen, n):
		var m: Dictionary = message_for(sim, sim.events[i])
		if not m.is_empty():
			push_line(str(m["text"]), str(m["kind"]))
	_seen = n
	for l: Dictionary in lines:
		l["age"] = float(l["age"]) + delta
	lines = lines.filter(func(l: Dictionary) -> bool: return float(l["age"]) < LIFE_S)
	if _pacer.due():
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	_draw_env_chip()
	var cx: float = RunScreen.WORLD_RECT.get_center().x
	var y: float = POS_Y
	var warn: String = warn_text(sim)
	if not warn.is_empty():
		var p: float = UiTheme.pulse(_t, 3.0)
		var w: float = UiTheme.text_width(warn, 26) + 70.0
		var r := Rect2(cx - w * 0.5, y, w, 40.0)
		draw_rect(r, Color(0.35, 0.07, 0.05).lerp(Color(0.6, 0.12, 0.08), p), true)
		UiTheme.hazard_stripes(self, Rect2(r.position.x, r.position.y, 12.0, r.size.y))
		draw_rect(r, UiTheme.ALARM.lerp(Color(1, 1, 1), 0.3 * p), false, 3.0)
		UiTheme.icon(self, "warn", r.position + Vector2(34.0, r.size.y * 0.5), 24.0)
		UiTheme.bold_text(self, Vector2(r.position.x + 54.0, r.position.y + 29.0), warn, 26, UiTheme.TEXT)
		y += 48.0
	for l: Dictionary in lines:
		var a: float = clampf((LIFE_S - float(l["age"])) / 0.7, 0.0, 1.0) * clampf(float(l["age"]) / 0.08, 0.0, 1.0)
		var text: String = str(l["text"])
		var col: Color = UiTheme.CRT if str(l["kind"]) == "good" else (UiTheme.ALARM if str(l["kind"]) == "bad" else UiTheme.AMBER)
		var w2: float = UiTheme.text_width(text, FONT) + 36.0
		var r2 := Rect2(cx - w2 * 0.5, y, w2, 34.0)
		draw_rect(r2, Color(0.03, 0.04, 0.05, 0.86 * a), true)
		draw_rect(r2, Color(col, a), false, 2.0)
		UiTheme.bold_text(self, Vector2(r2.position.x + 18.0, r2.position.y + 25.0), text, FONT, Color(col.lerp(UiTheme.TEXT, 0.35), a))
		y += 40.0


## The environment in force, a small chip under the enemy panel's row at the world area's left, until it ends.
func _draw_env_chip() -> void:
	var run: RunState = sim.run
	if run.env_id.is_empty():
		return
	var text: String = "IN FORCE: " + env_name(sim, run.env_id)
	var w: float = UiTheme.text_width(text, 17) + 52.0
	var r := Rect2(RunScreen.WORLD_RECT.position.x + 12.0, ENV_CHIP_Y, w, 32.0)
	draw_rect(r, Color(0.03, 0.04, 0.05, 0.88), true)
	draw_rect(r, Color(UiTheme.AMBER, 0.85), false, 1.5)
	SurveyMarks.draw_env(self, r.position + Vector2(19.0, 16.0), run.env_id)
	UiTheme.bold_text(self, Vector2(r.position.x + 38.0, r.position.y + 23.0), text, 17, UiTheme.AMBER)
