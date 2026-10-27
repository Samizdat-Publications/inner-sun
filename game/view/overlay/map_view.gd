class_name MapView
extends Control
## The node map overlay: a seismic survey chart on a green CRT in a steel frame. Rows run top to
## bottom like the descent (row 0 at the top, the gate at the bottom). Nodes are icons by type (a
## "?" until the scanner has seen them), links are lines, the path already drilled glows amber, the
## ship's node wears a pulsing ring, routes you can take right now glow green, and nodes the
## pursuer has overtaken are darkened and cracked. The pursuit front is a dark shadow creeping down
## from the top of the chart. While drilling, a marker rides the link at run.ship_row_f.
##
## In phase "idle" a click on a linked node pushes {"type": "choose_node", "node": id} (and closes
## the map). Hovering a node shows its type and row. A legend on the right explains the symbols.
##
## Mount (main.gd, on the HUD CanvasLayer, above the panels and below the dossier, store and death
## screen):
##   var map: MapView = MapView.build(layer, sim)    # one call to build
##   map.bind(new_sim)                               # one call to bind a Sim (again for a new run)
## Showing: with auto_open (default true) it opens by itself whenever the phase is "idle" and closes
## when the phase changes. open() and close() are for the M key (toggle() does both); Escape closes
## it. With handle_keys (default true) the map reads M and Escape itself; set it false if main.gd
## routes the M key. Closing in idle keeps it closed until the phase leaves idle once. It swallows
## the mouse while it is visible.

signal node_chosen(node_id: String)

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
const FRAME: Rect2 = Rect2(300, 36, 1320, 1008)
const SCREEN: Rect2 = Rect2(330, 92, 960, 920)
const LEGEND: Rect2 = Rect2(1314, 92, 276, 920)
const MARGIN_Y: float = 64.0
const MARGIN_X: float = 120.0
const NODE_R: float = 27.0
const PICK_R: float = 34.0
const TYPE_NAME: Dictionary = {
	"start": "LANDING SHAFT", "event": "EVENT SITE", "cavern": "CAVERN", "hazard": "HAZARD ZONE",
	"store": "TRADING POST", "fight": "HOSTILE CONTACT", "gate": "THE GATE", "deposit": "RICH DEPOSIT",
}
const LEGEND_ORDER: Array[String] = ["start", "event", "cavern", "hazard", "store", "fight", "deposit", "gate"]
const BG: Color = Color(0.022, 0.060, 0.040)
const CRT_BRIGHT: Color = Color(0.55, 1.0, 0.65)
const SHADOW: Color = Color(0.0, 0.0, 0.004)

var sim: Sim = null
var auto_open: bool = true
var handle_keys: bool = true

var _forced: bool = false
var _dismissed: bool = false
var _hover: String = ""
var _t: float = 0.0
var _traces: Array[PackedVector2Array] = []
var _close_button: Button = null
var _mat_info: Dictionary = {}  ## Rock materials of the layer (SurveyMarks.material_info), cached per rock id.
var _mat_rock: String = ""


static func build(parent: Control, p_sim: Sim) -> MapView:
	var m := MapView.new()
	m.position = Vector2.ZERO
	m.size = DESIGN_SIZE
	parent.add_child(m)
	m.bind(p_sim)
	return m


func _init() -> void:
	theme = UiTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_close_button = Button.new()
	_close_button.text = "CLOSE  [M]"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.position = Vector2(LEGEND.position.x + 24.0, LEGEND.end.y - 52.0)
	_close_button.size = Vector2(LEGEND.size.x - 48.0, 40.0)
	_close_button.add_theme_font_size_override("font_size", 17)
	_close_button.pressed.connect(close)
	add_child(_close_button)


func bind(p_sim: Sim) -> void:
	sim = p_sim
	_forced = false
	_dismissed = false
	_hover = ""
	_refresh()


## Open the map (the M key). It stays open until close() or Escape, whatever the phase.
func open() -> void:
	_forced = true
	_dismissed = false
	_refresh()


## Close the map. In idle it stays closed until the phase has left idle once.
func close() -> void:
	_forced = false
	_dismissed = true
	_refresh()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func is_open() -> bool:
	if sim == null or sim.run.mode != "run" or sim.run.nodes.is_empty():
		return false
	if _forced:
		return true
	return auto_open and not _dismissed and sim.run.phase == "idle"


func _process(delta: float) -> void:
	_refresh()
	if visible:
		_t += delta
		queue_redraw()


func _refresh() -> void:
	if sim != null and sim.run.phase != "idle":
		_dismissed = false
	var open_now: bool = is_open()
	if open_now != visible:
		visible = open_now
		_hover = ""
		if open_now:
			queue_redraw()
	if visible:
		_close_button.text = "CLOSE  [M]"


## Only the chart's frame takes the mouse: the power panel and crew cards beside it stay usable
## while the map holds the world (orders still apply, see main.gd).
func _has_point(point: Vector2) -> bool:
	return FRAME.has_point(point)


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or sim == null:
		return
	if k.physical_keycode == KEY_ESCAPE and visible:
		close()
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_M and handle_keys:
		toggle()
		get_viewport().set_input_as_handled()


# Queries -----------------------------------------------------------------------------------------

## True when a click on this node would start a drill to it right now.
func can_choose(id: String) -> bool:
	return sim != null and sim.run.phase == "idle" and sim.run.links_from_current().has(id)


## Choose the node: push the travel command and close the map.
func choose(id: String) -> void:
	if not can_choose(id):
		return
	sim.push({"type": "choose_node", "node": id})
	node_chosen.emit(id)
	_forced = false
	_dismissed = true
	_refresh()


## What the tooltip says about a node: [title, detail, note].
func describe(n: Dictionary) -> PackedStringArray:
	var run: RunState = sim.run
	var row: int = int(n["row"])
	var depth: float = float(run.layer.get("row_depth_m", 36.0)) * float(row)
	var title: String = str(TYPE_NAME.get(str(n["type"]), "UNKNOWN")) if run.is_revealed(n) else "UNSURVEYED"
	var detail: String = "ROW %d   DEPTH %d M" % [row, roundi(depth)]
	var note: String = ""
	if run.current_node == str(n["id"]):
		note = "YOU ARE HERE"
	elif run.is_visited(n):
		note = "ALREADY DRILLED"
	elif run.is_overtaken(n):
		note = "OVERTAKEN: ITS CONTENT IS GONE" if not can_choose(str(n["id"])) else "OVERTAKEN: THE FRONT WILL STRIKE"
	elif can_choose(str(n["id"])):
		note = "CLICK TO DRILL HERE"
	var out: PackedStringArray = PackedStringArray([title, detail, note])
	if run.is_revealed(n) and str(n.get("type", "")) != "start":
		out.append_array(SurveyMarks.words(n.get("survey", {}), _tier_count(), _materials(), str(n["type"]) == "deposit"))
		var env_id: String = str(n.get("env", ""))
		if not env_id.is_empty():
			out.append_array(SurveyMarks.env_words(sim.db.table("environments").get(env_id, {})))
	return out


func _tier_count() -> int:
	return ((sim.run.layer.get("survey", {}) as Dictionary).get("tiers", []) as Array).size()


func _materials() -> Dictionary:
	var rock: String = str(sim.run.layer.get("rock", DrillSim.DEFAULT_ROCK))
	if rock != _mat_rock or _mat_info.is_empty():
		_mat_rock = rock
		_mat_info = SurveyMarks.material_info(sim.db, rock)
	return _mat_info


# Geometry ----------------------------------------------------------------------------------------

func _rows() -> int:
	return maxi(2, sim.run.map.size())


func _row_y(row: float) -> float:
	var step: float = (SCREEN.size.y - 2.0 * MARGIN_Y) / float(_rows() - 1)
	return SCREEN.position.y + MARGIN_Y + row * step


func _half_span() -> float:
	var l: Dictionary = sim.run.layer
	return maxf(1.0, maxf(absf(float(l.get("x_min_m", -12.0))), absf(float(l.get("x_max_m", 12.0)))))


func _x_px(x_m: float) -> float:
	return SCREEN.position.x + SCREEN.size.x * 0.5 + x_m / _half_span() * (SCREEN.size.x * 0.5 - MARGIN_X)


func _pos(n: Dictionary) -> Vector2:
	return Vector2(_x_px(float(n["x_m"])), _row_y(float(n["row"])))


func _node_at(p: Vector2) -> String:
	var best: String = ""
	var best_d: float = PICK_R
	for n: Dictionary in sim.run.nodes:
		var d: float = _pos(n).distance_to(p)
		if d < best_d:
			best_d = d
			best = str(n["id"])
	return best


func _gui_input(event: InputEvent) -> void:
	if sim == null:
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_hover = _node_at(mm.position) if SCREEN.has_point(mm.position) else ""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_choose(_hover) else Control.CURSOR_ARROW
		queue_redraw()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and SCREEN.has_point(mb.position):
		var id: String = _node_at(mb.position)
		if not id.is_empty():
			choose(id)


# Drawing -----------------------------------------------------------------------------------------

func _draw() -> void:
	if sim == null or sim.run.nodes.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.015, 0.74), true)
	UiTheme.draw_panel(self, FRAME, "SEISMIC SURVEY  /  %s" % str(sim.run.layer.get("name", "STRATA")).to_upper())
	_draw_chart_bg()
	_draw_links()
	_draw_shadow()
	for n: Dictionary in sim.run.nodes:
		_draw_node(n)
	_draw_ship_marker()
	_draw_front_label()
	draw_rect(SCREEN, UiTheme.BRASS_DARK, false, 2.0)
	_draw_legend()
	_draw_tooltip()


func _draw_chart_bg() -> void:
	var run: RunState = sim.run
	draw_rect(SCREEN, BG, true)
	# Seismic traces: faint wiggling vertical lines, fixed so nothing shimmers.
	if _traces.is_empty():
		for i: int in range(14):
			var pts := PackedVector2Array()
			var x0: float = SCREEN.position.x + 40.0 + float(i) * (SCREEN.size.x - 80.0) / 13.0
			var h: int = (i * 7919 + 13) & 0xffff
			var amp: float = 3.0 + float(h % 7)
			var fq: float = 0.03 + float(h % 11) * 0.004
			var y: float = SCREEN.position.y
			while y <= SCREEN.end.y:
				pts.append(Vector2(x0 + sin(y * fq + float(h)) * amp + sin(y * fq * 2.7) * amp * 0.4, y))
				y += 8.0
			_traces.append(pts)
	for pts: PackedVector2Array in _traces:
		draw_polyline(pts, Color(UiTheme.CRT, 0.045), 1.0)
	# Row lines with row and depth labels.
	var step_m: float = float(run.layer.get("row_depth_m", 36.0))
	for r: int in range(_rows()):
		var y: float = _row_y(float(r))
		draw_line(Vector2(SCREEN.position.x, y), Vector2(SCREEN.end.x, y), Color(UiTheme.CRT, 0.13), 1.0)
		UiTheme.text(self, Vector2(SCREEN.position.x + 12.0, y - 5.0), "ROW %d" % r, 14, Color(UiTheme.CRT, 0.55))
		UiTheme.text(self, Vector2(SCREEN.position.x + 12.0, y + 13.0), "%d M" % roundi(step_m * float(r)), 13, Color(UiTheme.CRT, 0.40))
	# Scanner limit: beyond it the chart is only a guess.
	var seen: float = float(run.current_row() + run.scanner_rows) + 0.5
	if seen < float(_rows() - 1):
		var ly: float = _row_y(seen)
		draw_rect(Rect2(SCREEN.position.x, ly, SCREEN.size.x, SCREEN.end.y - ly), Color(0, 0, 0, 0.28), true)
		draw_dashed_line(Vector2(SCREEN.position.x, ly), Vector2(SCREEN.end.x, ly), Color(UiTheme.CRT, 0.45), 1.5, 8.0)
		UiTheme.text(self, Vector2(SCREEN.end.x - 212.0, ly - 6.0), "SCANNER LIMIT", 14, UiTheme.CRT_DIM, null, HORIZONTAL_ALIGNMENT_RIGHT, 200.0)
	# Scanlines.
	var lines := PackedVector2Array()
	var sy: float = SCREEN.position.y + 2.0
	while sy < SCREEN.end.y:
		lines.append(Vector2(SCREEN.position.x, sy))
		lines.append(Vector2(SCREEN.end.x, sy))
		sy += 4.0
	draw_multiline(lines, Color(0, 0, 0, 0.16), 1.0)


func _link_color(a: Dictionary, b: Dictionary) -> Color:
	var run: RunState = sim.run
	if run.is_visited(a) and run.is_visited(b):
		return UiTheme.AMBER
	if str(a["id"]) == run.current_node and can_choose(str(b["id"])):
		return Color(CRT_BRIGHT, 0.55 + 0.45 * UiTheme.pulse(_t, 1.2))
	if run.is_overtaken(b) or run.is_overtaken(a):
		return Color(0.40, 0.14, 0.12, 0.55)
	return Color(UiTheme.CRT, 0.30)


func _draw_links() -> void:
	var run: RunState = sim.run
	for a: Dictionary in run.nodes:
		for id: String in (a["links"] as PackedStringArray):
			var b: Dictionary = run.node(id)
			if b.is_empty():
				continue
			var pa: Vector2 = _pos(a)
			var pb: Vector2 = _pos(b)
			var col: Color = _link_color(a, b)
			var walked: bool = run.is_visited(a) and run.is_visited(b)
			if walked:
				draw_line(pa, pb, Color(UiTheme.AMBER, 0.20), 9.0)
				draw_line(pa, pb, col, 4.0, true)
			elif not run.is_revealed(b):
				draw_dashed_line(pa, pb, Color(col, 0.55), 1.5, 5.0)
			elif run.is_overtaken(a) or run.is_overtaken(b):
				draw_dashed_line(pa, pb, col, 2.0, 7.0)
			else:
				draw_line(pa, pb, col, 3.0 if col.a > 0.5 else 2.0, true)
	# The leg being drilled right now.
	if run.phase == "drill" and not run.target_node.is_empty():
		var cur: Dictionary = run.node(run.current_node)
		var tgt: Dictionary = run.node(run.target_node)
		if not cur.is_empty() and not tgt.is_empty():
			draw_dashed_line(_pos(cur), _pos(tgt), UiTheme.AMBER, 4.0, 10.0, false)


func _draw_shadow() -> void:
	var run: RunState = sim.run
	var front_y: float = _row_y(run.pursuer_row)
	var top: float = SCREEN.position.y
	if front_y <= top + 14.0:
		# The front is still above the chart: a thin dark fringe that grows as it nears.
		var near: float = clampf(1.0 - (top - front_y) / 90.0, 0.0, 1.0)
		for i: int in range(6):
			draw_rect(Rect2(SCREEN.position.x, top + float(i) * 3.0, SCREEN.size.x, 3.0), Color(SHADOW, (0.45 + 0.4 * near) * (1.0 - float(i) / 6.0)), true)
		return
	var edge := PackedVector2Array()
	var x: float = SCREEN.position.x
	var i2: int = 0
	while x <= SCREEN.end.x + 0.1:
		var wob: float = 11.0 * sin(float(i2) * 1.7 + _t * 0.8) + 7.0 * sin(float(i2) * 3.1 - _t * 1.3)
		var spike: float = 18.0 if i2 % 5 == 2 else 0.0
		# Kept below the top line: a wobble above it made the polygon cross itself ("triangulation failed").
		edge.append(Vector2(x, clampf(front_y + wob + spike, top + 1.0, SCREEN.end.y)))
		x += 24.0
		i2 += 1
	var poly := PackedVector2Array([Vector2(SCREEN.position.x, top), Vector2(SCREEN.end.x, top)])
	for k: int in range(edge.size() - 1, -1, -1):
		poly.append(edge[k])
	draw_colored_polygon(poly, Color(SHADOW, 0.93))
	# Slow dark streaks inside the shadow, and a red haze just below its edge.
	for j: int in range(9):
		var sx: float = SCREEN.position.x + 40.0 + float(j) * 105.0 + 12.0 * sin(_t * 0.4 + float(j))
		draw_line(Vector2(sx, top), Vector2(sx, maxf(top, front_y - 30.0)), Color(UiTheme.ALARM, 0.05), 3.0)
	for k2: int in range(1, 6):
		var haze := PackedVector2Array()
		for p: Vector2 in edge:
			haze.append(p + Vector2(0.0, float(k2) * 5.0))
		draw_polyline(haze, Color(UiTheme.ALARM, 0.20 * (1.0 - float(k2) / 6.0)), 5.0)
	draw_polyline(edge, Color(UiTheme.ALARM, 0.75), 2.0)


func _node_state(n: Dictionary) -> String:
	var run: RunState = sim.run
	if str(n["id"]) == run.current_node:
		return "current"
	if run.is_visited(n):
		return "visited"
	if run.is_overtaken(n):
		return "overtaken"
	if not run.is_revealed(n):
		return "unknown"
	if can_choose(str(n["id"])):
		return "open"
	return "seen"


func _draw_node(n: Dictionary) -> void:
	var st: String = _node_state(n)
	var c: Vector2 = _pos(n)
	var kind: String = str(n["type"])
	var hot: bool = str(n["id"]) == _hover
	var ring: Color = UiTheme.CRT
	var fill: Color = Color(0.03, 0.12, 0.07)
	var glyph: Color = UiTheme.CRT
	match st:
		"current":
			ring = UiTheme.AMBER
			fill = Color(0.22, 0.14, 0.04)
			glyph = UiTheme.BRASS_LIGHT
		"visited":
			ring = UiTheme.AMBER_DIM
			fill = Color(0.14, 0.09, 0.03)
			glyph = UiTheme.AMBER
		"overtaken":
			ring = Color(0.28, 0.22, 0.20)
			fill = Color(0.02, 0.02, 0.02)
			glyph = Color(0.30, 0.26, 0.24)
		"unknown":
			ring = UiTheme.CRT_DIM
			fill = Color(0.02, 0.07, 0.045)
			glyph = UiTheme.CRT_DIM
		"open":
			ring = CRT_BRIGHT
			fill = Color(0.05, 0.20, 0.11)
			glyph = CRT_BRIGHT
		"seen":
			ring = Color(UiTheme.CRT, 0.55)
			glyph = Color(UiTheme.CRT, 0.75)
	if st == "open":
		var halo: float = 0.18 + 0.16 * UiTheme.pulse(_t, 1.2)
		draw_circle(c, NODE_R + 9.0, Color(CRT_BRIGHT, halo))
	if st == "current":
		var pr: float = NODE_R + 8.0 + 3.0 * UiTheme.pulse(_t, 0.9)
		draw_arc(c, pr, 0.0, TAU, 40, Color(UiTheme.AMBER, 0.85), 2.5, true)
		draw_arc(c, pr + 6.0, 0.0, TAU, 40, Color(UiTheme.AMBER, 0.30), 1.5, true)
	draw_circle(c, NODE_R, fill)
	draw_arc(c, NODE_R, 0.0, TAU, 36, ring, 3.0 if (hot or st == "open" or st == "current") else 2.0, true)
	if st == "unknown":
		UiTheme.text(self, c + Vector2(-10.0, 11.0), "?", 32, glyph, null, HORIZONTAL_ALIGNMENT_CENTER, 20.0)
	else:
		_glyph(kind, c, NODE_R * 0.62, glyph, st == "overtaken")
	if st == "overtaken":
		_crack(c, str(n["id"]))
	if st != "unknown" and not str(n.get("env", "")).is_empty():
		SurveyMarks.draw_env(self, c + Vector2(-NODE_R - 14.0, -NODE_R + 4.0), str(n["env"]), 0.6 if st in ["visited", "overtaken"] else 1.0)
	if (st == "open" or st == "seen") and SurveyMarks.has_reading(n):
		SurveyMarks.draw(self, c + Vector2(NODE_R + 8.0, -12.0), n["survey"], _tier_count(), _materials(), 1.0 if st == "open" else 0.75)


## One node type as a small drawn symbol, centred on c, about 2s across.
func _glyph(kind: String, c: Vector2, s: float, col: Color, dead: bool) -> void:
	match kind:
		"start":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.6), c + Vector2(s * 0.8, -s * 0.6), c + Vector2(0, s * 0.8)]), col)
			draw_line(c + Vector2(-s, -s * 0.9), c + Vector2(s, -s * 0.9), col, 2.0)
		"event":
			var r := Rect2(c + Vector2(-s * 0.55, -s * 0.85), Vector2(s * 1.1, s * 1.7))
			draw_rect(r, col, false, 2.0)
			for i: int in range(3):
				var ly: float = r.position.y + s * 0.4 + float(i) * s * 0.42
				draw_line(Vector2(r.position.x + s * 0.2, ly), Vector2(r.end.x - s * 0.2, ly), col, 1.5)
		"cavern":
			var pts := PackedVector2Array()
			for i: int in range(0, 13):
				var a: float = PI + float(i) * PI / 12.0
				pts.append(c + Vector2(cos(a) * s * 0.95, sin(a) * s * 0.95 + s * 0.35))
			pts.append(c + Vector2(s * 0.95, s * 0.8))
			pts.append(c + Vector2(-s * 0.95, s * 0.8))
			draw_colored_polygon(pts, col)
			var hole := PackedVector2Array()
			for i: int in range(0, 13):
				var a2: float = PI + float(i) * PI / 12.0
				hole.append(c + Vector2(cos(a2) * s * 0.45, sin(a2) * s * 0.45 + s * 0.45))
			hole.append(c + Vector2(s * 0.45, s * 0.8))
			hole.append(c + Vector2(-s * 0.45, s * 0.8))
			draw_colored_polygon(hole, Color(0.03, 0.08, 0.05))
		"hazard":
			var tri := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.85), c + Vector2(-s, s * 0.85)])
			draw_colored_polygon(tri, UiTheme.HAZARD if not dead else col)
			draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), UiTheme.STEEL_DEEP, 2.5)
			draw_circle(c + Vector2(0, s * 0.6), 1.5, UiTheme.STEEL_DEEP)
		"store":
			var b := Rect2(c + Vector2(-s * 0.85, -s * 0.5), Vector2(s * 1.7, s * 1.2))
			draw_rect(b, col, false, 2.0)
			draw_line(b.position, b.end, col, 1.5)
			draw_line(Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), col, 1.5)
			draw_line(c + Vector2(-s * 0.85, -s * 0.5), c + Vector2(-s * 0.55, -s * 0.9), col, 2.0)
			draw_line(c + Vector2(s * 0.85, -s * 0.5), c + Vector2(s * 0.55, -s * 0.9), col, 2.0)
		"fight":
			draw_arc(c, s * 0.7, 0.0, TAU, 24, col, 2.0, true)
			for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + d * s * 0.45, c + d * s * 1.1, col, 2.0)
			draw_circle(c, 2.2, col)
		"deposit":
			var gem := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, -s * 0.1), c + Vector2(0, s), c + Vector2(-s * 0.8, -s * 0.1)])
			draw_colored_polygon(gem, col)
			draw_line(c + Vector2(-s * 0.8, -s * 0.1), c + Vector2(s * 0.8, -s * 0.1), Color(0.03, 0.08, 0.05), 1.5)
			draw_line(c + Vector2(0, -s), c + Vector2(-s * 0.25, -s * 0.1), Color(0.03, 0.08, 0.05), 1.2)
			draw_line(c + Vector2(0, -s), c + Vector2(s * 0.25, -s * 0.1), Color(0.03, 0.08, 0.05), 1.2)
			for sp: Vector2 in [Vector2(-1.1, -0.9), Vector2(1.15, -1.0)]:
				draw_line(c + sp * s - Vector2(3, 0), c + sp * s + Vector2(3, 0), col, 1.5)
				draw_line(c + sp * s - Vector2(0, 3), c + sp * s + Vector2(0, 3), col, 1.5)
		"gate":
			var g := Rect2(c + Vector2(-s * 0.8, -s * 0.9), Vector2(s * 1.6, s * 1.8))
			draw_rect(g, col, false, 2.5)
			draw_line(c + Vector2(0, -s * 0.9), c + Vector2(0, s * 0.9), col, 2.0)
			for i: int in range(3):
				var by: float = -s * 0.45 + float(i) * s * 0.45
				draw_line(c + Vector2(-s * 0.8, by), c + Vector2(s * 0.8, by), Color(col, 0.6), 1.2)
		_:
			draw_circle(c, s * 0.5, col)


func _crack(c: Vector2, id: String) -> void:
	var h: int = id.hash() & 0xffff
	var a: float = float(h % 628) / 100.0
	var pts := PackedVector2Array([c + Vector2(cos(a), sin(a)) * NODE_R * 1.1])
	var p: Vector2 = pts[0]
	for i: int in range(4):
		a += float((h >> (i * 2)) % 5 - 2) * 0.45 + PI
		p = p + Vector2(cos(a), sin(a)) * NODE_R * 0.45
		pts.append(p)
	draw_polyline(pts, Color(UiTheme.ALARM, 0.65), 1.8)
	draw_line(c + Vector2(-NODE_R * 0.7, -NODE_R * 0.7), c + Vector2(NODE_R * 0.7, NODE_R * 0.7), Color(0.55, 0.15, 0.12, 0.5), 2.0)


func _draw_ship_marker() -> void:
	var run: RunState = sim.run
	if run.phase != "drill" or run.target_node.is_empty():
		return
	var cur: Dictionary = run.node(run.current_node)
	var tgt: Dictionary = run.node(run.target_node)
	if cur.is_empty() or tgt.is_empty():
		return
	var rows: float = float(int(tgt["row"]) - int(cur["row"]))
	var t: float = clampf((run.ship_row_f(sim) - float(run.current_row())) / maxf(0.001, rows), 0.0, 1.0)
	var p: Vector2 = _pos(cur).lerp(_pos(tgt), t)
	draw_circle(p, 17.0, Color(UiTheme.AMBER, 0.20))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -11), p + Vector2(9, -11), p + Vector2(0, 12)]), UiTheme.AMBER)
	draw_polyline(PackedVector2Array([p + Vector2(-9, -11), p + Vector2(9, -11), p + Vector2(0, 12), p + Vector2(-9, -11)]), UiTheme.STEEL_DEEP, 1.5)
	UiTheme.text(self, p + Vector2(16, 5), "DRILLING", 15, UiTheme.AMBER)


func _draw_front_label() -> void:
	var run: RunState = sim.run
	var front_y: float = _row_y(run.pursuer_row)
	var gap: float = run.ship_row_f(sim) - run.pursuer_row
	var txt: String = "PURSUIT FRONT   %.1f ROWS BEHIND YOU" % gap if gap > 0.0 else "PURSUIT FRONT   ON TOP OF YOU"
	var ly: float = clampf(front_y - 12.0, SCREEN.position.y + 30.0, SCREEN.end.y - 8.0)
	if front_y <= SCREEN.position.y + 14.0:
		ly = SCREEN.position.y + 30.0
	var warn: Color = UiTheme.ALARM if gap < 1.6 else Color(0.78, 0.36, 0.30)
	# At the end of the chart away from the player's node, so the label never runs under its ring.
	var lx: float = SCREEN.position.x + 118.0
	var cur: Dictionary = run.node(run.current_node)
	if not cur.is_empty() and _pos(cur).x < SCREEN.get_center().x:
		lx = SCREEN.end.x - UiTheme.text_width(txt, 16) - 24.0
	UiTheme.text(self, Vector2(lx, ly), txt, 16, Color(warn, 0.65 + 0.35 * UiTheme.pulse(_t, 1.4) if gap < 1.6 else 0.9))


func _draw_legend() -> void:
	var run: RunState = sim.run
	var x: float = LEGEND.position.x + 24.0
	var y: float = LEGEND.position.y + 22.0
	UiTheme.glow_text(self, Vector2(x, y), "SURVEY LOG", 18, UiTheme.AMBER)
	y += 8.0
	draw_line(Vector2(x, y), Vector2(LEGEND.end.x - 24.0, y), UiTheme.BRASS_DARK, 1.0)
	y += 26.0
	var lines: Array[String] = [
		"DEPTH     %d M" % roundi(run.depth_m),
		"ROW       %d / %d" % [run.current_row(), _rows() - 1],
		"SCANNER   %d ROWS" % run.scanner_rows,
		"CELLS     %d" % run.get_res("cells"),
	]
	for s: String in lines:
		UiTheme.text(self, Vector2(x, y), s, 17, UiTheme.CRT)
		y += 24.0
	y += 14.0
	UiTheme.glow_text(self, Vector2(x, y), "SYMBOLS", 18, UiTheme.AMBER)
	y += 8.0
	draw_line(Vector2(x, y), Vector2(LEGEND.end.x - 24.0, y), UiTheme.BRASS_DARK, 1.0)
	y += 30.0
	for kind: String in LEGEND_ORDER:
		var c: Vector2 = Vector2(x + 16.0, y - 5.0)
		draw_circle(c, 15.0, Color(0.03, 0.12, 0.07))
		draw_arc(c, 15.0, 0.0, TAU, 24, UiTheme.CRT, 1.5, true)
		_glyph(kind, c, 9.5, UiTheme.CRT, false)
		UiTheme.text(self, Vector2(x + 44.0, y), str(TYPE_NAME[kind]), 15, UiTheme.TEXT)
		y += 34.0
	var cq: Vector2 = Vector2(x + 16.0, y - 5.0)
	draw_circle(cq, 15.0, Color(0.02, 0.07, 0.045))
	draw_arc(cq, 15.0, 0.0, TAU, 24, UiTheme.CRT_DIM, 1.5, true)
	UiTheme.text(self, cq + Vector2(-6.0, 7.0), "?", 20, UiTheme.CRT_DIM)
	UiTheme.text(self, Vector2(x + 44.0, y), "UNSURVEYED", 15, UiTheme.TEXT)
	y += 40.0
	# Route and state keys.
	var key_rows: Array = [
		[UiTheme.AMBER, "DRILLED PATH"], [CRT_BRIGHT, "OPEN ROUTE"],
		[Color(0.55, 0.20, 0.16), "OVERTAKEN"],
	]
	for kr: Array in key_rows:
		draw_line(Vector2(x + 2.0, y - 5.0), Vector2(x + 32.0, y - 5.0), kr[0] as Color, 3.0)
		UiTheme.text(self, Vector2(x + 44.0, y), str(kr[1]), 15, UiTheme.TEXT)
		y += 28.0
	draw_arc(Vector2(x + 17.0, y - 5.0), 10.0, 0.0, TAU, 20, UiTheme.AMBER, 2.0, true)
	UiTheme.text(self, Vector2(x + 44.0, y), "YOUR POSITION", 15, UiTheme.TEXT)
	y += 28.0
	draw_rect(Rect2(x + 2.0, y - 15.0, 30.0, 20.0), SHADOW, true)
	draw_rect(Rect2(x + 2.0, y - 15.0, 30.0, 20.0), Color(UiTheme.ALARM, 0.6), false, 1.0)
	UiTheme.text(self, Vector2(x + 44.0, y), "PURSUIT FRONT", 15, UiTheme.TEXT)
	y += 30.0
	y = SurveyMarks.draw_key(self, x, y, _materials())
	SurveyMarks.draw_last_dig(self, x, y + 8.0, DigLog.last_summary(sim))
	# The one line the player needs.
	var hint: String = "CHOOSE A GLOWING ROUTE." if run.phase == "idle" else "DRILLING. MAP IS READ ONLY."
	var pulse: float = 0.65 + 0.35 * UiTheme.pulse(_t, 1.0) if run.phase == "idle" else 0.7
	UiTheme.text(self, Vector2(x, LEGEND.end.y - 74.0), hint, 15, Color(CRT_BRIGHT, pulse))


func _draw_tooltip() -> void:
	if _hover.is_empty():
		return
	var n: Dictionary = sim.run.node(_hover)
	if n.is_empty():
		return
	var d: PackedStringArray = describe(n)
	var lines: Array[String] = [d[0], d[1]]
	if not d[2].is_empty():
		lines.append(d[2])
	var survey_from: int = lines.size()
	var env_from: int = 1000
	for i: int in range(3, d.size()):
		if d[i].begins_with("ENVIRONMENT"):
			env_from = lines.size()
		lines.append(d[i])
	var w: float = 0.0
	for s: String in lines:
		w = maxf(w, UiTheme.text_width(s, 16))
	var box := Rect2(_pos(n) + Vector2(NODE_R + 14.0, -34.0), Vector2(w + 28.0, 22.0 * float(lines.size()) + 18.0))
	if box.end.x > SCREEN.end.x:
		box.position.x = _pos(n).x - NODE_R - 14.0 - box.size.x
	box.position.y = clampf(box.position.y, SCREEN.position.y + 4.0, SCREEN.end.y - box.size.y - 4.0)
	draw_rect(box, UiTheme.STEEL_DEEP, true)
	draw_rect(box, UiTheme.BRASS, false, 1.5)
	for i: int in range(lines.size()):
		var col: Color = UiTheme.AMBER if i == 0 else (UiTheme.CRT if i == 1 else UiTheme.BRASS_LIGHT)
		if i >= survey_from:
			col = UiTheme.CRT
		if i >= env_from:
			col = UiTheme.AMBER if i == env_from else UiTheme.BRASS_LIGHT
		UiTheme.text(self, box.position + Vector2(14.0, 26.0 + 22.0 * float(i)), lines[i], 16, col)
