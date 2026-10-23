class_name ScannerDraw
extends RefCounted
## The scanner panel's drawing, moved out of ScannerPanel to keep that file short: the CRT screen's rock,
## glints, ticks, heading lines, node marker, legend, glass and readout. Every function draws onto the
## panel `p` and only runs inside its _draw.

static func draw_no_signal(p: ScannerPanel) -> void:
	var step: int = int(p._t * 14.0)
	for i: int in range(46):
		var h: int = ((step * 2654435761 + i * 40503) & 0xffff)
		var y: float = ScannerPanel.SCREEN.position.y + float(h % int(ScannerPanel.SCREEN.size.y))
		var x: float = ScannerPanel.SCREEN.position.x + float((h >> 3) % 200)
		var w: float = 20.0 + float((h >> 5) % 100)
		p.draw_line(Vector2(x, y), Vector2(minf(x + w, ScannerPanel.SCREEN.end.x - 1.0), y), Color(UiTheme.CRT, 0.05 + 0.07 * float(h % 3)), 1.0)
	var blink: float = 0.55 + 0.45 * UiTheme.pulse(p._t, 0.7)
	UiTheme.glow_text(p, Vector2(ScannerPanel.SCREEN.position.x, ScannerPanel.SCREEN.get_center().y + 10.0), "NO SIGNAL", 36, Color(UiTheme.CRT, blink), null, HORIZONTAL_ALIGNMENT_CENTER, ScannerPanel.SCREEN.size.x)


## Magnetite (RunState.scanner_blind): snow over the picture and a plain "NO SIGNAL: <ENV>" line.
static func draw_snow(p: ScannerPanel) -> void:
	var sc: Rect2 = ScannerPanel.SCREEN
	p.draw_rect(sc, Color(0.02, 0.05, 0.04, 0.72), true)
	var step: int = int(p._t * 16.0)
	for i: int in range(300):
		var h: int = ((step * 2654435761 + i * 40503 + i * i * 977) & 0xffffff)
		var x: float = sc.position.x + float(h % int(sc.size.x - 4.0))
		var y: float = sc.position.y + float((h >> 9) % int(sc.size.y - 2.0))
		var v: float = 0.35 + 0.6 * float((h >> 4) % 100) / 100.0
		p.draw_rect(Rect2(x, y, 3.0 + float(h % 3), 2.0), Color(0.6 * v, 1.0 * v, 0.75 * v, 0.55))
	for i: int in range(5):
		var yy: float = sc.position.y + fposmod(p._t * 90.0 + float(i) * 61.0, sc.size.y)
		p.draw_line(Vector2(sc.position.x, yy), Vector2(sc.end.x, yy), Color(UiTheme.CRT, 0.18), 3.0)
	var name_text: String = str(p.sim.run.env.get("name", "static")).to_upper()
	var blink: float = 0.7 + 0.3 * UiTheme.pulse(p._t, 0.9)
	var band := Rect2(sc.position.x, sc.get_center().y - 26.0, sc.size.x, 42.0)
	p.draw_rect(band, Color(0.0, 0.03, 0.02, 0.85), true)
	UiTheme.glow_text(p, Vector2(sc.position.x, sc.get_center().y + 6.0), "NO SIGNAL: " + name_text, 26, Color(UiTheme.CRT, blink), null, HORIZONTAL_ALIGNMENT_CENTER, sc.size.x)


static func draw_rock(p: ScannerPanel) -> void:
	var d: DrillSim = p.sim.drill
	p.draw_texture_rect_region(p._tex, ScannerPanel.SCREEN, Rect2(0.0, p._frac, float(d.cols), float(p._rows_shown)), Color(1, 1, 1, 1))
	var px_x: float = ScannerPanel.SCREEN.size.x / (float(d.cols))
	var px_y: float = ScannerPanel.SCREEN.size.y / float(p._rows_shown)
	# Glints.
	for gi: int in range(p._glints.size()):
		var g: Vector3 = p._glints[gi]
		var gp := Vector2(ScannerPanel.SCREEN.position.x + (g.x + 0.5) * px_x, ScannerPanel.SCREEN.position.y + (g.y - p._frac + 0.5) * px_y)
		if not ScannerPanel.SCREEN.has_point(gp):
			continue
		var tw: float = 0.5 + 0.5 * sin(p._t * 3.2 + g.z)
		var s: float = 2.0 + 5.0 * tw
		var base_c: Color = p._glint_cols[gi] if gi < p._glint_cols.size() else Color(0.85, 1.0, 0.9)
		var gc: Color = Color(base_c.r, base_c.g, base_c.b, 0.35 + 0.55 * tw)
		p.draw_line(gp - Vector2(s, 0), gp + Vector2(s, 0), gc, 1.0)
		p.draw_line(gp - Vector2(0, s), gp + Vector2(0, s), gc, 1.0)
	# Depth ticks every 5 m below the crown.
	var m_px: float = ScannerPanel.SCREEN.size.y / ScannerPanel.LOOK_AHEAD_M
	for m: int in range(5, int(ScannerPanel.LOOK_AHEAD_M) + 1, 5):
		var y: float = ScannerPanel.SCREEN.position.y + float(m) * m_px
		p.draw_line(Vector2(ScannerPanel.SCREEN.position.x, y), Vector2(ScannerPanel.SCREEN.position.x + 8.0, y), Color(UiTheme.CRT, 0.7), 1.0)
		UiTheme.text(p, Vector2(ScannerPanel.SCREEN.position.x + 11.0, y + 5.0), "%d" % m, 14, Color(UiTheme.CRT, 0.9))
	# The ship's footprint and heading.
	var cx: float = p._crown_x_px()
	var half: float = d.ship_size.x * 0.5 / (float(d.cols) * d.cell_m) * ScannerPanel.SCREEN.size.x
	p.draw_line(Vector2(cx - half, ScannerPanel.SCREEN.position.y + 2.0), Vector2(cx + half, ScannerPanel.SCREEN.position.y + 2.0), UiTheme.CRT, 3.0)
	p.draw_line(Vector2(cx - half, ScannerPanel.SCREEN.position.y), Vector2(cx - half, ScannerPanel.SCREEN.position.y + 10.0), UiTheme.CRT, 2.0)
	p.draw_line(Vector2(cx + half, ScannerPanel.SCREEN.position.y), Vector2(cx + half, ScannerPanel.SCREEN.position.y + 10.0), UiTheme.CRT, 2.0)
	var tgt_deg: float = p.target_heading()
	var ppm_xy := Vector2(ScannerPanel.SCREEN.size.x / (float(d.cols) * d.cell_m), m_px)
	var origin := Vector2(cx, ScannerPanel.SCREEN.position.y + 4.0)
	if absf(tgt_deg - d.heading_deg) > 0.5:
		p.draw_dashed_line(origin, ScannerExtras.heading_end(origin, tgt_deg, ppm_xy, ScannerPanel.SCREEN), Color(UiTheme.AMBER, 0.95), 2.0, 6.0)
	p.draw_line(origin, ScannerExtras.heading_end(origin, d.heading_deg, ppm_xy, ScannerPanel.SCREEN), Color(0.9, 1.0, 0.9), 2.5)
	if p.blast != null and p.blast.armed:
		ScannerExtras.draw_blast(p, p.sim, ScannerPanel.SCREEN, p.look_m(), p._hover, p._t)
	ScannerExtras.draw_miner(p, p.sim, ScannerPanel.SCREEN, p.look_m(), p._hover, p._t, p.miner != null and p.miner.armed, p.miner.crew_id() if p.miner != null else "")
	ScannerExtras.draw_notes(p, p.sim, ScannerPanel.SCREEN, p._t, tgt_deg, ScannerExtras.blast_word(p.sim, p.blast != null and p.blast.armed))
	# The next node: a line across the screen with a diamond where it sits.
	var crown: float = d.ship_pos.y + d.ship_size.y
	var remain: float = d.target_y - crown
	if remain >= 0.0 and remain <= ScannerPanel.LOOK_AHEAD_M:
		var ny: float = ScannerPanel.SCREEN.position.y + remain * m_px
		p.draw_dashed_line(Vector2(ScannerPanel.SCREEN.position.x, ny), Vector2(ScannerPanel.SCREEN.end.x, ny), UiTheme.AMBER, 2.0, 8.0)
		var tx: float = ScannerPanel.SCREEN.position.x + d.target_x / (float(d.cols) * d.cell_m) * ScannerPanel.SCREEN.size.x
		p.draw_colored_polygon(PackedVector2Array([Vector2(tx, ny - 9), Vector2(tx + 9, ny), Vector2(tx, ny + 9), Vector2(tx - 9, ny)]), UiTheme.AMBER)
		UiTheme.text(p, Vector2(ScannerPanel.SCREEN.end.x - 86.0, ny - 8.0), "NODE", 15, UiTheme.AMBER, null, HORIZONTAL_ALIGNMENT_RIGHT, 80.0)
	ScannerExtras.draw_structure(p, p.sim, ScannerPanel.SCREEN, p.look_m(), p._t)
	draw_legend(p)
	# The sweep.
	var sy: float = ScannerPanel.SCREEN.position.y + fposmod(p._t * ScannerPanel.SWEEP_HZ, 1.0) * ScannerPanel.SCREEN.size.y
	for i: int in range(14):
		var y2: float = sy - float(i) * 3.0
		if y2 < ScannerPanel.SCREEN.position.y:
			break
		p.draw_rect(Rect2(ScannerPanel.SCREEN.position.x, y2, ScannerPanel.SCREEN.size.x, 3.0), Color(UiTheme.CRT, 0.16 * (1.0 - float(i) / 14.0)), true)
	p.draw_line(Vector2(ScannerPanel.SCREEN.position.x, sy), Vector2(ScannerPanel.SCREEN.end.x, sy), Color(0.8, 1.0, 0.85, 0.7), 1.5)


## A tiny legend along the foot of the screen: a swatch for every ore, gem, gas and water material
## the rock table has, in the colours the screen uses. Drawn from the material table, so new ores show.
static func draw_legend(p: ScannerPanel) -> void:
	var d: DrillSim = p.sim.drill
	var groups: Array = [["ORE", ScannerPanel.K_ORE], ["GEM", ScannerPanel.K_GEM], ["GAS", ScannerPanel.K_GAS], ["WATER", ScannerPanel.K_WATER], ["FAULT", ScannerPanel.K_FAULT], ["LOOT", ScannerPanel.K_LOOT]]
	var x: float = ScannerPanel.SCREEN.position.x + 6.0
	var y: float = ScannerPanel.SCREEN.end.y - 17.0
	p.draw_rect(Rect2(ScannerPanel.SCREEN.position.x, y, ScannerPanel.SCREEN.size.x, 17.0), Color(0.0, 0.03, 0.02, 0.82), true)
	for g: Array in groups:
		var kind: int = int(g[1])
		var swatches: Array[Color] = []
		for code: int in range(1, d.materials.size()):
			if p._kind[code] == kind:
				var sw: Color = swatch(p, kind, code)
				if not swatches.has(sw):  # Timber and rubble are both fault rock on the glass: one swatch.
					swatches.append(sw)
		if swatches.is_empty():
			continue
		UiTheme.text(p, Vector2(x, y + 13.0), str(g[0]), 12, Color(UiTheme.CRT, 0.9))
		x += UiTheme.text_width(str(g[0]), 12) + 4.0
		for col: Color in swatches:
			p.draw_rect(Rect2(x, y + 4.0, 8.0, 9.0), col, true)
			p.draw_rect(Rect2(x, y + 4.0, 8.0, 9.0), Color(0, 0, 0, 0.6), false, 1.0)
			x += 10.0
		x += 8.0


## The legend colour of a material of this kind.
static func swatch(p: ScannerPanel, kind: int, code: int) -> Color:
	if kind == ScannerPanel.K_WATER:
		return ScannerPanel.cell_color(ScannerPanel.K_WATER, 0.6, 3, 4)
	if kind == ScannerPanel.K_FAULT:
		return ScannerExtras.FAULT_HATCH
	if kind == ScannerPanel.K_LOOT:
		return ScannerPanel.cell_color(ScannerPanel.K_LOOT, 0.4, 3, 4)
	return p._tints[code]


## Scanlines, vignette and a glass reflection over the screen, clipped to it by construction.
static func draw_glass(p: ScannerPanel) -> void:
	var y: float = ScannerPanel.SCREEN.position.y
	while y < ScannerPanel.SCREEN.end.y:
		p.draw_line(Vector2(ScannerPanel.SCREEN.position.x, y), Vector2(ScannerPanel.SCREEN.end.x, y), Color(0, 0, 0, 0.20), 1.0)
		y += 3.0
	for i: int in range(7):
		var a: float = 0.14 * (1.0 - float(i) / 7.0)
		p.draw_rect(ScannerPanel.SCREEN.grow(-float(i) * 2.0), Color(0, 0, 0, a), false, 2.0)
	p.draw_rect(ScannerPanel.SCREEN, Color(UiTheme.CRT, 0.5), false, 1.0)


static func draw_readout(p: ScannerPanel) -> void:
	var d: DrillSim = p.sim.drill
	var y: float = ScannerPanel.SCREEN.end.y + 32.0
	if not p.is_live():
		UiTheme.bold_text(p, Vector2(22, y), "STANDBY", 20, UiTheme.TEXT)
		UiTheme.text(p, Vector2(22, y + 28.0), "DRILL IDLE", 18, UiTheme.TEXT_DIM)
		return
	var crown: float = d.ship_pos.y + d.ship_size.y
	var remain: float = maxf(0.0, d.target_y - crown)
	UiTheme.bold_text(p, Vector2(22, y), "HDG %+d  TGT %+d" % [roundi(d.heading_deg), roundi(p.target_heading())], 20, UiTheme.CRT)
	UiTheme.bold_text(p, Vector2(p.size.x - 22.0 - 190.0, y), "NODE IN %d M" % roundi(remain), 20, UiTheme.AMBER, null, HORIZONTAL_ALIGNMENT_RIGHT, 190.0)
	var wear: int = roundi(d.bit_wear * 100.0)
	var bit_col: Color = UiTheme.ALARM if d.bit_broken else (UiTheme.AMBER if wear >= 70 else UiTheme.CRT)
	UiTheme.text(p, Vector2(22, y + 28.0), "SPEED %.1f M/S" % d.speed_m_s, 18, UiTheme.TEXT)
	var bit_text: String = "BIT BROKEN" if d.bit_broken else "BIT WEAR %d%%" % wear
	if d.bit_change_left_s > 0.0:
		bit_text = "FITTING BIT %.0f S" % d.bit_change_left_s
		bit_col = UiTheme.AMBER
	if p.bit_offer():
		draw_bit_button(p, p.sim.run.get_res("bits"))
		return
	UiTheme.text(p, Vector2(p.size.x - 22.0 - 210.0, y + 28.0), bit_text, 18, bit_col, null, HORIZONTAL_ALIGNMENT_RIGHT, 210.0)


static func draw_bit_button(p: ScannerPanel, bits: int) -> void:
	var r: Rect2 = ScannerPanel.BIT_BUTTON
	var can: bool = bits > 0
	var pulse: float = UiTheme.pulse(p._t, 1.6)
	p.draw_rect(r, Color(0.22, 0.15, 0.05).lerp(Color(0.32, 0.21, 0.06), pulse) if can else UiTheme.STEEL_DEEP, true)
	p.draw_rect(r, UiTheme.AMBER if can else UiTheme.ALARM, false, 2.0)
	var label: String = "[B] NEW BIT (%d left)" % bits if can else "NO BITS LEFT"
	UiTheme.bold_text(p, Vector2(r.position.x, r.position.y + 21.0), label, 17, UiTheme.BRASS_LIGHT if can else UiTheme.ALARM, null, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
