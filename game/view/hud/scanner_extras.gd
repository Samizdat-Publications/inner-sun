class_name ScannerExtras
extends RefCounted
## The seismic scanner's M1c additions, kept out of ScannerPanel: the heading line over the full range
## (up to hold depth, 90 degrees), fault rock's hatching, the blast range ring and target circle, the
## screen-to-segment-meters mapping a blast click needs, and the HOLD DEPTH and AT THE WALL readouts.
## Pure geometry (static, tested) plus a few draw helpers that take the panel as the canvas item.

const FAULT_HATCH: Color = Color(0.86, 0.72, 0.46)
const FAULT_DARK: Color = Color(0.30, 0.22, 0.12)
const HOLD_DEG: float = 80.0  ## Past this heading the drill is holding depth.
const RING_POINTS: int = 120


## The CRT colour of a fault rock cell: pale brown diagonal hatching on a dark brown ground.
static func fault_color(c: int, r: int) -> Color:
	if (c + r) % 3 == 0:
		return FAULT_HATCH
	return FAULT_DARK.lerp(Color(0.45, 0.34, 0.18), float(((c * 31) ^ (r * 17)) & 3) / 6.0)


## Where a ray from `origin` going `dir` (pixels, any length) leaves `rect`.
static func ray_end(origin: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var t: float = INF
	if dir.x > 0.0001:
		t = minf(t, (rect.end.x - origin.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, (rect.position.x - origin.x) / dir.x)
	if dir.y > 0.0001:
		t = minf(t, (rect.end.y - origin.y) / dir.y)
	if t == INF or t < 0.0:
		return origin
	return origin + dir * t


## The heading line's end for `heading_deg`, in panel pixels: it runs out to the edge of the screen,
## so 90 degrees is a level line along the crown. `px_per_m` is the screen's (x, y) scale.
static func heading_end(origin: Vector2, heading_deg: float, px_per_m: Vector2, rect: Rect2) -> Vector2:
	var r: float = deg_to_rad(heading_deg)
	return ray_end(origin, Vector2(sin(r) * px_per_m.x, cos(r) * px_per_m.y), rect)


## Panel point to segment meters: x across the whole segment, y below the crown over `look_m`.
static func screen_to_m(p: Vector2, screen: Rect2, width_m: float, crown_y_m: float, look_m: float) -> Vector2:
	return Vector2((p.x - screen.position.x) / screen.size.x * width_m,
			crown_y_m + (p.y - screen.position.y) / screen.size.y * look_m)


## Segment meters to panel pixels (the inverse of screen_to_m).
static func m_to_screen(m: Vector2, screen: Rect2, width_m: float, crown_y_m: float, look_m: float) -> Vector2:
	return Vector2(screen.position.x + m.x / width_m * screen.size.x,
			screen.position.y + (m.y - crown_y_m) / look_m * screen.size.y)


## An ellipse as runs of consecutive points that lie inside `rect` (a ring that leaves the screen is
## drawn only where it is on it).
static func ellipse_runs(center: Vector2, rx: float, ry: float, rect: Rect2, n: int = RING_POINTS) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var run := PackedVector2Array()
	for i: int in range(n + 1):
		var a: float = float(i) / float(n) * TAU
		var p := Vector2(center.x + cos(a) * rx, center.y + sin(a) * ry)
		if rect.has_point(p):
			run.append(p)
		elif not run.is_empty():
			out.append(run)
			run = PackedVector2Array()
	if not run.is_empty():
		out.append(run)
	return out


## True when the heading (current or ordered) is past the hold depth threshold.
static func holding(heading_deg: float, target_deg: float) -> bool:
	return absf(heading_deg) > HOLD_DEG or absf(target_deg) > HOLD_DEG


## One short word for the blast readout in a corner of the screen.
static func blast_word(s: Sim, armed: bool) -> String:
	if BlastCard.launcher_slot(s) < 0:
		return ""
	if armed:
		return "BLAST ARMED"
	if s.drill.verbs.blast_pending:
		return "BLAST AWAY"
	var why: String = s.drill.blast_ready(s)
	if why.is_empty():
		return "BLAST READY"
	if why == "reloading":
		return "BLAST %.1f S" % s.drill.verbs.blast_cooldown_left_s
	# Short on the glass (it clipped as "BLAST: POWER WEAPO"); the blast card has the full reason.
	var r: String = BlastCard.reason_text(s, why)
	return "BLAST: " + r if r.length() <= 12 else "BLAST NOT READY"


## The blast range ring (centred on the footprint, which sits above the screen) and, when `hover` is a
## panel point inside the screen, the target circle: green when the sim would take the shot.
static func draw_blast(ci: CanvasItem, s: Sim, screen: Rect2, look_m: float, hover: Vector2, t: float) -> void:
	var d: DrillSim = s.drill
	var width_m: float = float(d.cols) * d.cell_m
	var crown: float = d.ship_pos.y + d.ship_size.y
	var px: Vector2 = Vector2(screen.size.x / width_m, screen.size.y / look_m)
	var range_m: float = s.db.tune("drill.blast_range_m")
	var centre_m := Vector2(d.ship_pos.x + d.ship_size.x * 0.5, d.ship_pos.y + d.ship_size.y * 0.5)
	var centre: Vector2 = m_to_screen(centre_m, screen, width_m, crown, look_m)
	var pulse: float = 0.55 + 0.35 * sin(t * 4.0)
	for run: PackedVector2Array in ellipse_runs(centre, range_m * px.x, range_m * px.y, screen):
		if run.size() >= 2:
			ci.draw_polyline(run, Color(UiTheme.AMBER, pulse), 2.0)
	if not screen.has_point(hover):
		return
	var m: Vector2 = screen_to_m(hover, screen, width_m, crown, look_m)
	var ok: bool = d.verbs.aim_ok(d, m).is_empty()
	var col: Color = UiTheme.CRT if ok else UiTheme.ALARM
	var rad: float = s.db.tune("drill.blast_radius_m")
	for run2: PackedVector2Array in ellipse_runs(hover, rad * px.x, rad * px.y, screen, 40):
		if run2.size() >= 2:
			ci.draw_polyline(run2, col, 2.0)
	ci.draw_line(hover - Vector2(6, 0), hover + Vector2(6, 0), col, 1.5)
	ci.draw_line(hover - Vector2(0, 6), hover + Vector2(0, 6), col, 1.5)


## The buried structure's box on the glass, clipped to the screen: an empty Rect2 when the segment has
## none or it is not in range yet (nothing of it within the `look_m` the screen shows below the crown).
static func structure_box(s: Sim, screen: Rect2, look_m: float) -> Rect2:
	var d: DrillSim = s.drill
	var st: DrillStructures = d.structures
	if not d.active or not st.has_structure():
		return Rect2()
	var width_m: float = float(d.cols) * d.cell_m
	var crown: float = d.ship_pos.y + d.ship_size.y
	var a: Vector2 = m_to_screen(st.rect.position, screen, width_m, crown, look_m)
	var b: Vector2 = m_to_screen(st.rect.end, screen, width_m, crown, look_m)
	var box := Rect2(a, b - a)
	if not box.intersects(screen):
		return Rect2()
	return box.intersection(screen)


## Draw the structure's outline (a brass dashed frame with corner ticks, green once broken into) and
## its small label once any of it is within range. The cells inside already show as the scanner's
## colours (void for the old air, hatching for timber, amber for crates).
static func draw_structure(ci: CanvasItem, s: Sim, screen: Rect2, look_m: float, t: float) -> void:
	var box: Rect2 = structure_box(s, screen, look_m)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var st: DrillStructures = s.drill.structures
	var col: Color = UiTheme.CRT if st.entered else UiTheme.AMBER
	var pulse: float = 0.75 + 0.25 * sin(t * 3.0)
	var edge := Color(col, 0.9 * pulse)
	var g: Rect2 = box.grow(2.0)
	ci.draw_dashed_line(g.position, Vector2(g.end.x, g.position.y), edge, 1.5, 5.0)
	ci.draw_dashed_line(Vector2(g.position.x, g.end.y), g.end, edge, 1.5, 5.0)
	ci.draw_dashed_line(g.position, Vector2(g.position.x, g.end.y), edge, 1.5, 5.0)
	ci.draw_dashed_line(Vector2(g.end.x, g.position.y), g.end, edge, 1.5, 5.0)
	for corner: Vector2 in [g.position, Vector2(g.end.x, g.position.y), Vector2(g.position.x, g.end.y), g.end]:
		ci.draw_rect(Rect2(corner - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(col, 0.95), true)
	var text: String = st.label + (" (OPEN)" if st.entered else "")
	var w: float = UiTheme.text_width(text, 12)
	var x: float = clampf(g.position.x, screen.position.x + 3.0, screen.end.x - w - 3.0)
	var y: float = g.position.y - 4.0
	if y < screen.position.y + 36.0:
		y = g.end.y + 13.0  # No room above the box (it is under the ship): put the label below it.
	ci.draw_rect(Rect2(x - 2.0, y - 11.0, w + 4.0, 14.0), Color(0.0, 0.03, 0.02, 0.8), true)
	UiTheme.text(ci, Vector2(x, y), text, 12, col)


## HOLD DEPTH and AT THE WALL on the glass, and the blast word in the top right corner.
static func draw_notes(ci: CanvasItem, s: Sim, screen: Rect2, t: float, target_deg: float, blast_word_text: String) -> void:
	var d: DrillSim = s.drill
	var cx: float = screen.get_center().x
	if holding(d.heading_deg, target_deg):
		UiTheme.glow_text(ci, Vector2(screen.position.x, screen.position.y + 44.0), "HOLD DEPTH", 22, UiTheme.AMBER, null, HORIZONTAL_ALIGNMENT_CENTER, screen.size.x)
	if d.at_wall:
		var blink: float = 0.6 + 0.4 * UiTheme.pulse(t, 2.0)
		var box := Rect2(screen.position.x + 10.0, screen.position.y + 54.0, screen.size.x - 20.0, 26.0)
		ci.draw_rect(box, Color(0.30, 0.05, 0.04, 0.85), true)
		ci.draw_rect(box, Color(UiTheme.ALARM, blink), false, 2.0)
		UiTheme.bold_text(ci, Vector2(cx - box.size.x * 0.5, box.position.y + 19.0), "AT THE WALL: steer down (S)", 17, UiTheme.TEXT, null, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	if not blast_word_text.is_empty():
		UiTheme.text(ci, Vector2(screen.end.x - 150.0, screen.position.y + 20.0), blast_word_text, 14, Color(UiTheme.CRT, 0.9), null, HORIZONTAL_ALIGNMENT_RIGHT, 142.0)

## The away miner on the glass: a bright dot at their feet with a short trail back to the drill head and
## the target as a small cross; with the order armed, the miner's range ring around the head and, when
## `hover` is a panel point inside the screen, a circle there (green when the sim would send them).
static func draw_miner(ci: CanvasItem, s: Sim, screen: Rect2, look_m: float, hover: Vector2, t: float, armed: bool, crew_id: String = "") -> void:
	var d: DrillSim = s.drill
	if not d.active:
		return
	var width_m: float = float(d.cols) * d.cell_m
	var crown: float = d.ship_pos.y + d.ship_size.y
	var px: Vector2 = Vector2(screen.size.x / width_m, screen.size.y / look_m)
	var head_m: Vector2 = DrillMiner.head(d)
	if armed:
		var head_px: Vector2 = m_to_screen(head_m, screen, width_m, crown, look_m)
		var pulse: float = 0.55 + 0.35 * sin(t * 4.0)
		for run: PackedVector2Array in ellipse_runs(head_px, d.miner.range_m * px.x, d.miner.range_m * px.y, screen):
			if run.size() >= 2:
				ci.draw_polyline(run, Color(UiTheme.CRT, pulse), 2.0)
		if screen.has_point(hover):
			var m: Vector2 = screen_to_m(hover, screen, width_m, crown, look_m)
			var ok: bool = DrillMiner.target_ok(d, s, crew_id, m).is_empty()
			var col: Color = UiTheme.CRT if ok else UiTheme.ALARM
			for run2: PackedVector2Array in ellipse_runs(hover, d.cell_m * 2.0 * px.x, d.cell_m * 2.0 * px.y, screen, 24):
				if run2.size() >= 2:
					ci.draw_polyline(run2, col, 2.0)
	var mn: DrillMiner = d.miner
	if not mn.is_out():
		return
	var feet: Vector2 = m_to_screen(mn.pos, screen, width_m, crown, look_m)
	var head2: Vector2 = m_to_screen(head_m, screen, width_m, crown, look_m)
	var tgt: Vector2 = m_to_screen(mn.target, screen, width_m, crown, look_m)
	if screen.has_point(tgt):
		ci.draw_line(tgt - Vector2(4, 4), tgt + Vector2(4, 4), Color(UiTheme.AMBER, 0.8), 1.5)
		ci.draw_line(tgt - Vector2(4, -4), tgt + Vector2(4, -4), Color(UiTheme.AMBER, 0.8), 1.5)
	if screen.has_point(feet):
		ci.draw_dashed_line(head2, feet, Color(1.0, 1.0, 1.0, 0.55), 1.5, 4.0)
		var blink: float = 0.7 + 0.3 * sin(t * 8.0)
		ci.draw_circle(feet, 9.0, Color(1.0, 1.0, 0.8, 0.25 * blink))
		ci.draw_circle(feet, 5.0, Color(1.0, 1.0, 0.85, blink))

