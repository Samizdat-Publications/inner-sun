class_name DigTally
extends Control
## The dig tally and the arrival toast, drawn over the world area (RunScreen.WORLD_RECT):
##  - while drilling, one line at its top: "THIS DIG  coal 4  iron 14  = +18 ore +3 gems", each
##    material in its own colour, with the ore and gem icons on the total;
##  - on arrival ("segment_done"), a small plaque for TOAST_S seconds: time and distance, what was
##    taken (ore, gems, by material) and gas bursts. It sits above the overlays so the map or a dossier
##    opening at once does not hide it, and it never takes the mouse.
## It owns the DigLog (the floating pickups read it too); `update` is called from _process.
##
## Mount (RunScreen, last on the HUD layer):  var t: DigTally = DigTally.build(layer, sim)

const TALLY_POS: Vector2 = Vector2(352.0, 98.0)
const TOAST_W: float = 560.0
const FONT: int = 18

var sim: Sim = null
var digs: DigLog = DigLog.new()
var hide_tally: Callable = Callable()  ## Returns true while an overlay or a fight covers the world.
var hide_toast: Callable = Callable()  ## Returns true while the death screen is up.
var _pacer: RedrawPacer = RedrawPacer.new()
var _was_shown: bool = false


static func build(parent: Control, p_sim: Sim) -> DigTally:
	var t := DigTally.new()
	t.position = Vector2.ZERO
	t.size = Vector2(1920, 1080)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	t.bind(p_sim)
	return t


func bind(p_sim: Sim) -> void:
	sim = p_sim
	digs.bind(sim)
	queue_redraw()


func _process(delta: float) -> void:
	if sim == null:
		return
	digs.update(sim, delta)
	var shown: bool = tally_visible() or toast_visible()
	if shown or _was_shown:
		if _pacer.due():
			queue_redraw()
	_was_shown = shown


func tally_visible() -> bool:
	if sim == null or not sim.drill.active or sim.run.phase != "drill":
		return false
	return not (hide_tally.is_valid() and bool(hide_tally.call()))


func toast_visible() -> bool:
	if digs.toast.is_empty():
		return false
	return not (hide_toast.is_valid() and bool(hide_toast.call()))


func _draw() -> void:
	if sim == null:
		return
	if tally_visible():
		_draw_tally()
	if toast_visible():
		_draw_toast()


func _draw_tally() -> void:
	var mats: Array = digs.totals.keys()
	var w: float = 30.0 + UiTheme.text_width("THIS DIG", FONT)
	for m: Variant in mats:
		w += UiTheme.text_width("%s %d" % [DigLog.short_name(str(m)).to_lower(), int(digs.totals[m])], FONT) + 18.0
	w += UiTheme.text_width("= +%d ore +%d gems" % [digs.ore, digs.gems], FONT) + 70.0
	var crate_s: String = crates_text(sim)
	if not crate_s.is_empty():
		w += UiTheme.text_width(crate_s, FONT) + 24.0
	var r := Rect2(TALLY_POS, Vector2(minf(w, 1150.0), 34.0))
	draw_rect(r, Color(0.03, 0.04, 0.05, 0.78), true)
	draw_rect(r, UiTheme.BRASS_DARK, false, 1.5)
	var x: float = r.position.x + 12.0
	var y: float = r.position.y + 24.0
	UiTheme.text(self, Vector2(x, y), "THIS DIG", FONT, UiTheme.AMBER)
	x += UiTheme.text_width("THIS DIG", FONT) + 18.0
	for m: Variant in mats:
		var s: String = "%s %d" % [DigLog.short_name(str(m)).to_lower(), int(digs.totals[m])]
		UiTheme.text(self, Vector2(x, y), s, FONT, DigLog.readable(digs.color_of(sim, str(m))))
		x += UiTheme.text_width(s, FONT) + 18.0
	var tot: String = "= +%d" % digs.ore
	UiTheme.text(self, Vector2(x, y), tot, FONT, UiTheme.TEXT)
	x += UiTheme.text_width(tot, FONT) + 6.0
	UiTheme.icon(self, "ore", Vector2(x + 8.0, y - 6.0), 17.0)
	x += 24.0
	var g: String = "+%d" % digs.gems
	UiTheme.text(self, Vector2(x, y), g, FONT, UiTheme.TEXT)
	x += UiTheme.text_width(g, FONT) + 6.0
	UiTheme.icon(self, "gems", Vector2(x + 8.0, y - 6.0), 17.0)
	x += 26.0
	if not crate_s.is_empty():
		UiTheme.text(self, Vector2(x, y), crate_s, FONT, DigLog.LOOT_COLOR)


## "crates 1/3" while the segment holds a buried structure with crates, else "".
static func crates_text(s: Sim) -> String:
	var st: DrillStructures = s.drill.structures
	if not st.has_structure() or st.crates_total <= 0:
		return ""
	return "crates %d/%d" % [st.crates_opened, st.crates_total]


## The structure line of the arrival toast ("OLD MINE WORKS  BROKEN INTO  CRATES 2/3"), "" when the
## segment had none. Pure: the tests read it.
static func structure_line(t: Dictionary) -> String:
	if str(t.get("structure", "")).is_empty():
		return ""
	var label: String = str(t.get("label", t.get("structure", ""))).to_upper()
	var bits := PackedStringArray([label, "BROKEN INTO" if bool(t.get("entered", false)) else "NOT ENTERED"])
	if int(t.get("crates_total", 0)) > 0:
		bits.append("CRATES %d/%d" % [int(t.get("crates", 0)), int(t.get("crates_total", 0))])
	return "  ".join(bits)


func _draw_toast() -> void:
	var t: Dictionary = digs.toast
	var yields: Dictionary = t.get("yield", {})
	var yield_row: bool = not yields.is_empty() or int(t.get("gas_bursts", 0)) > 0
	var rows: int = 3 if yield_row else 2
	var st_line: String = structure_line(t)
	var loot: Dictionary = t.get("loot", {})
	if not st_line.is_empty():
		rows += 1
	var h: float = 40.0 + 26.0 * float(rows)
	var cx: float = RunScreen.WORLD_RECT.get_center().x
	var fade: float = clampf((DigLog.TOAST_S - digs.toast_age) / 0.8, 0.0, 1.0) * clampf(digs.toast_age / 0.12, 0.0, 1.0)
	var r := Rect2(Vector2(cx - TOAST_W * 0.5, 1012.0 - h), Vector2(TOAST_W, h))
	draw_rect(r, Color(0.03, 0.04, 0.05, 0.9 * fade), true)
	draw_rect(r, Color(UiTheme.BRASS, fade), false, 2.0)
	var x: float = r.position.x + 18.0
	var y: float = r.position.y + 28.0
	UiTheme.glow_text(self, Vector2(x, y), "SEGMENT DONE", 20, Color(UiTheme.AMBER, fade))
	var stat: String = "%.0f S   %.0f M" % [float(t.get("time_s", 0.0)), float(t.get("distance_m", 0.0))]
	UiTheme.text(self, Vector2(r.end.x - 18.0 - 200.0, y), stat, 17, Color(UiTheme.TEXT_DIM, fade), null, HORIZONTAL_ALIGNMENT_RIGHT, 200.0)
	y += 28.0
	var ore: int = int(t.get("ore", 0))
	var gems: int = int(t.get("gems", 0))
	if ore == 0 and gems == 0:
		UiTheme.text(self, Vector2(x, y), "NOTHING WORTH TAKING", 20, Color(UiTheme.TEXT_DIM, fade))
	else:
		var s1: String = "+%d" % ore
		UiTheme.bold_text(self, Vector2(x, y), s1, 22, Color(UiTheme.TEXT, fade))
		x += UiTheme.text_width(s1, 22) + 8.0
		UiTheme.icon(self, "ore", Vector2(x + 10.0, y - 7.0), 22.0, Color(1, 1, 1, fade))
		x += 40.0
		var s2: String = "+%d" % gems
		UiTheme.bold_text(self, Vector2(x, y), s2, 22, Color(UiTheme.TEXT, fade))
		x += UiTheme.text_width(s2, 22) + 8.0
		UiTheme.icon(self, "gems", Vector2(x + 10.0, y - 7.0), 22.0, Color(1, 1, 1, fade))
	if yield_row:
		x = r.position.x + 18.0
		y += 26.0
		for m: Variant in yields.keys():
			var s: String = "%s %d" % [DigLog.short_name(str(m)).to_lower(), int(yields[m])]
			var c: Color = DigLog.readable(digs.color_of(sim, str(m)))
			UiTheme.text(self, Vector2(x, y), s, 17, Color(c.r, c.g, c.b, fade))
			x += UiTheme.text_width(s, 17) + 16.0
		if int(t.get("gas_bursts", 0)) > 0:
			UiTheme.text(self, Vector2(x, y), "GAS BURSTS %d" % int(t["gas_bursts"]), 17, Color(0.85, 0.92, 0.3, fade))
	if not st_line.is_empty():
		x = r.position.x + 18.0
		y += 26.0
		UiTheme.text(self, Vector2(x, y), st_line, 17, Color(DigLog.LOOT_COLOR, fade))
		x += UiTheme.text_width(st_line, 17) + 16.0
		for res: Variant in loot.keys():
			var ls: String = "+%d %s" % [int(loot[res]), DigLog.short_name(str(res)).to_lower()]
			UiTheme.text(self, Vector2(x, y), ls, 17, Color(UiTheme.TEXT, fade))
			x += UiTheme.text_width(ls, 17) + 12.0
