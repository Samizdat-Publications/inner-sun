class_name StructureBanner
extends Control
## The break-in banner: when the drill cuts into a buried structure ("structure_entered") a plaque with
## its label drops over the top of the world area, with a TOPSIDE line under it when the radio table
## has one for the trigger "structure". It stays SHOW_S seconds of real time; the clock stops while an
## overlay covers the world (the trader's store or the event's dossier opens in the same tick), so the
## banner is still there when the player comes back to the drill.
## Follows `sim.events` by index (read only).
##
## Mount (RunScreen, on the HUD layer):  StructureBanner.build(layer, sim)

const SHOW_S: float = 5.0
const POS_Y: float = 212.0
const WIDTH: float = 700.0
const TRIGGER: String = "structure"
const WARM: Color = Color(1.0, 0.72, 0.36)

var sim: Sim = null
var hide_when: Callable = Callable()  ## Returns true while an overlay covers the world.
var label: String = ""
var radio: String = ""
var age: float = 99.0
var _seen: int = 0
var _t: float = 0.0
var _pacer: RedrawPacer = RedrawPacer.new()


static func build(parent: Control, p_sim: Sim) -> StructureBanner:
	var b := StructureBanner.new()
	b.position = Vector2.ZERO
	b.size = Vector2(1920, 1080)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	b.bind(p_sim)
	return b


func bind(p_sim: Sim) -> void:
	sim = p_sim
	label = ""
	radio = ""
	age = 99.0
	_seen = sim.events.size() if sim != null else 0
	queue_redraw()


## The TOPSIDE line for a break-in: the radio lines with trigger "structure", one picked by a hash of
## the structure and segment ids (no random numbers in the view). "" when there is none. Pure.
static func radio_line(s: Sim, structure: String, segment: String) -> String:
	var texts := PackedStringArray()
	var radios: Dictionary = s.db.table("radio")
	var ids: Array = radios.keys()
	ids.sort()
	for id: Variant in ids:
		var entry: Dictionary = radios[id]
		for ln: Variant in entry.get("lines", []):
			var line: Dictionary = ln
			if str(line.get("trigger", "")) == TRIGGER and not str(line.get("text", "")).is_empty():
				texts.append(str(line["text"]))
	if texts.is_empty():
		return ""
	return texts[absi((structure + "/" + segment).hash()) % texts.size()]


## Split `text` into lines no wider than `width` px at `size`, on spaces (at most `max_lines`, the rest cut).
static func wrap(text: String, size: int, width: float, max_lines: int = 2) -> PackedStringArray:
	var out := PackedStringArray()
	var cur: String = ""
	for word: String in text.split(" "):
		var trial: String = word if cur.is_empty() else cur + " " + word
		if UiTheme.text_width(trial, size) > width and not cur.is_empty():
			out.append(cur)
			cur = word
		else:
			cur = trial
	if not cur.is_empty():
		out.append(cur)
	while out.size() > max_lines:
		out.resize(max_lines)
	return out


func is_showing() -> bool:
	return age < SHOW_S and not label.is_empty()


func _process(delta: float) -> void:
	_t += delta
	if sim == null:
		return
	var n: int = sim.events.size()
	if n < _seen:
		_seen = 0
	for i: int in range(_seen, n):
		var e: Dictionary = sim.events[i]
		if str(e.get("kind", "")) == "structure_entered":
			label = str(e.get("label", e.get("structure", ""))).to_upper()
			radio = radio_line(sim, str(e.get("structure", "")), sim.drill.segment_id)
			age = 0.0
	_seen = n
	var covered: bool = hide_when.is_valid() and bool(hide_when.call())
	if is_showing() and not covered:
		age += delta
	if (is_showing() or age < SHOW_S + 0.5) and _pacer.due():
		queue_redraw()


func _draw() -> void:
	if not is_showing() or sim == null or (hide_when.is_valid() and bool(hide_when.call())):
		return
	var fade: float = clampf((SHOW_S - age) / 0.8, 0.0, 1.0) * clampf(age / 0.15, 0.0, 1.0)
	var drop: float = (1.0 - clampf(age / 0.25, 0.0, 1.0)) * -24.0
	var lines: PackedStringArray = wrap("TOPSIDE: " + radio, 17, WIDTH - 60.0) if not radio.is_empty() else PackedStringArray()
	var h: float = 92.0 + 22.0 * float(lines.size())
	var cx: float = RunScreen.WORLD_RECT.get_center().x
	var r := Rect2(cx - WIDTH * 0.5, POS_Y + drop, WIDTH, h)
	draw_rect(r, Color(0.07, 0.045, 0.02, 0.92 * fade), true)
	UiTheme.hazard_stripes(self, Rect2(r.position.x, r.position.y, 14.0, r.size.y))
	UiTheme.hazard_stripes(self, Rect2(r.end.x - 14.0, r.position.y, 14.0, r.size.y))
	var pulse: float = 0.65 + 0.35 * UiTheme.pulse(_t, 1.4)
	draw_rect(r, Color(WARM.lerp(UiTheme.AMBER, 0.4), fade * pulse), false, 3.0)
	UiTheme.text(self, Vector2(r.position.x, r.position.y + 26.0), "BROKE INTO A BURIED STRUCTURE", 16, Color(UiTheme.AMBER, fade), null, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UiTheme.glow_text(self, Vector2(r.position.x, r.position.y + 68.0), label, 36, Color(WARM.lerp(Color.WHITE, 0.25), fade), null, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var y: float = r.position.y + 94.0
	for ln: String in lines:
		UiTheme.text(self, Vector2(r.position.x + 30.0, y), ln, 17, Color(UiTheme.CRT, fade))
		y += 22.0
