class_name SurveyMarks
extends RefCounted
## Survey readings on the node map (n["survey"], see sim/run/survey.gd), drawn beside a node and said
## in words for the tooltip. Pips are the richness tier (1 to the number of tiers); small coloured
## squares are the ore materials the rock can hold, diamonds the gem materials, then a gas flame and a
## water drop, a pale zigzag for fault rock (rockfalls: power bracing). Colours and names come from the layer's rock table, so new ores show up by themselves.

const PIP_GAP: float = 9.0
const ICON_GAP: float = 9.0
const STRUCTURE_KEY: String = "structure:"
const STRUCTURE_COLOR: Color = Color(0.95, 0.72, 0.38)


## Material id -> {"name", "color"} for the rock table the layer drills through.
static func material_info(db: DataDB, rock_id: String) -> Dictionary:
	var out: Dictionary = {}
	var rock: Dictionary = db.table("rock").get(rock_id, {})
	for m: Variant in rock.get("materials", []):
		var md: Dictionary = m
		out[str(md.get("id", ""))] = {"name": str(md.get("name", md.get("id", ""))), "color": Color.html(str(md.get("color", "#c0c0c0")))}
	# The buried structures the map can name, under "structure:<id>" (their label, as the banner says it).
	var structures: Dictionary = db.table("structures")
	for sid: Variant in structures.keys():
		var sd: Dictionary = structures[sid]
		out[STRUCTURE_KEY + str(sid)] = {"name": str(sd.get("label", sd.get("name", sid))), "color": STRUCTURE_COLOR}
	return out


## The label of a reading's buried structure ("" for none), from `info` (material_info).
static func structure_label(survey: Dictionary, info: Dictionary) -> String:
	var sid: String = str(survey.get("structure", ""))
	if sid.is_empty():
		return ""
	return str((info.get(STRUCTURE_KEY + sid, {}) as Dictionary).get("name", sid.replace("_", " "))).to_upper()


## True when a node's reading is worth drawing: it has one, and the scanner has seen the node.
static func has_reading(n: Dictionary) -> bool:
	return not (n.get("survey", {}) as Dictionary).is_empty()


## Pips for a reading: tier + 1 filled out of `tiers` (at least 1).
static func pips(survey: Dictionary, tiers: int) -> Vector2i:
	return Vector2i(clampi(int(survey.get("tier", 0)) + 1, 1, maxi(1, tiers)), maxi(1, tiers))


## Draw the marks with their top-left corner at `at`; returns the width used.
static func draw(ci: CanvasItem, at: Vector2, survey: Dictionary, tiers: int, info: Dictionary, dim: float = 1.0) -> float:
	var pp: Vector2i = pips(survey, tiers) if tiers > 0 else Vector2i.ZERO
	var gold: Color = Color(UiTheme.AMBER, dim)
	var empty: Color = Color(UiTheme.AMBER_DIM, 0.55 * dim)
	for i: int in range(pp.y):
		var c: Vector2 = at + Vector2(4.0 + float(i) * PIP_GAP, 5.0)
		if i < pp.x:
			ci.draw_circle(c, 3.6, gold)
		else:
			ci.draw_arc(c, 3.2, 0.0, TAU, 10, empty, 1.2)
	var x: float = at.x + float(pp.y) * PIP_GAP + 4.0
	if bool(survey.get("gas", false)):
		var g: Vector2 = Vector2(x + 4.0, at.y + 5.0)
		ci.draw_colored_polygon(PackedVector2Array([g + Vector2(0, -5.5), g + Vector2(4.5, 4.0), g + Vector2(-4.5, 4.0)]), Color(0.82, 0.9, 0.25, dim))
		x += ICON_GAP + 2.0
	if bool(survey.get("water", false)):
		var w: Vector2 = Vector2(x + 4.0, at.y + 5.0)
		ci.draw_circle(w + Vector2(0, 1.5), 3.6, Color(0.30, 0.60, 0.92, dim))
		ci.draw_colored_polygon(PackedVector2Array([w + Vector2(0, -5.5), w + Vector2(3.2, 0.5), w + Vector2(-3.2, 0.5)]), Color(0.30, 0.60, 0.92, dim))
		x += ICON_GAP + 2.0
	if bool(survey.get("faults", false)):
		var f: Vector2 = Vector2(x + 4.0, at.y + 5.0)
		var zig := PackedVector2Array([f + Vector2(-4.5, -5.0), f + Vector2(1.0, -1.5), f + Vector2(-2.0, 1.0), f + Vector2(4.5, 5.5)])
		ci.draw_polyline(zig, Color(0.86, 0.72, 0.46, dim), 2.2)
		x += ICON_GAP + 2.0
	var sname: String = structure_label(survey, info)
	if not sname.is_empty():
		# A little hut: a roof over a door, in the structure colour.
		var h: Vector2 = Vector2(x + 4.0, at.y + 5.0)
		var sc := Color(STRUCTURE_COLOR, dim)
		ci.draw_colored_polygon(PackedVector2Array([h + Vector2(-5.5, -0.5), h + Vector2(0, -5.5), h + Vector2(5.5, -0.5)]), sc)
		ci.draw_rect(Rect2(h + Vector2(-4.0, -0.5), Vector2(8.0, 6.0)), sc, false, 1.5)
		x += ICON_GAP + 3.0
	var width: float = x - at.x
	var y2: float = at.y + 16.0
	var x2: float = at.x + 1.0
	for m: Variant in survey.get("ores", []):
		var col: Color = (info.get(str(m), {}) as Dictionary).get("color", Color(0.7, 0.7, 0.7)) as Color
		col = DigLog.readable(col)
		ci.draw_rect(Rect2(x2, y2, 7.0, 7.0), Color(col, dim), true)
		ci.draw_rect(Rect2(x2, y2, 7.0, 7.0), Color(0, 0, 0, 0.7 * dim), false, 1.0)
		x2 += 9.0
	for m: Variant in survey.get("gems", []):
		var col2: Color = (info.get(str(m), {}) as Dictionary).get("color", Color(0.8, 0.9, 1.0)) as Color
		var c2: Vector2 = Vector2(x2 + 4.5, y2 + 3.5)
		var dia := PackedVector2Array([c2 + Vector2(0, -5), c2 + Vector2(4.5, 0), c2 + Vector2(0, 5), c2 + Vector2(-4.5, 0)])
		ci.draw_colored_polygon(dia, Color(col2, dim))
		ci.draw_polyline(dia + PackedVector2Array([dia[0]]), Color(0, 0, 0, 0.7 * dim), 1.0)
		x2 += 11.0
	if not sname.is_empty():
		UiTheme.text(ci, Vector2(at.x + 1.0, at.y + 36.0), sname, 11, Color(STRUCTURE_COLOR, dim))
		width = maxf(width, UiTheme.text_width(sname, 11))
	return maxf(width, x2 - at.x)


## The reading in words, one short line each, for the tooltip. `deposit` marks a rich-seam node.
static func words(survey: Dictionary, tiers: int, info: Dictionary, deposit: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if survey.is_empty():
		return out
	var pp: Vector2i = pips(survey, tiers)
	var head: String = "%s ROCK  (%d OF %d)" % [str(survey.get("tier_name", "fair")).to_upper(), pp.x, pp.y]
	if deposit:
		head = "RICH DEPOSIT: " + head
	out.append(head)
	out.append("ORE: " + _names(survey.get("ores", []), info))
	var gems: Array = survey.get("gems", [])
	out.append("GEMS: " + (_names(gems, info) if not gems.is_empty() else "NONE"))
	var hazards: PackedStringArray = PackedStringArray()
	if bool(survey.get("gas", false)):
		hazards.append("GAS POCKETS")
	if bool(survey.get("water", false)):
		hazards.append("WATER POCKETS")
	if bool(survey.get("faults", false)):
		hazards.append("FAULT ROCK (BRACE)")
	out.append("AHEAD: " + (", ".join(hazards) if not hazards.is_empty() else "CLEAR"))
	var sname: String = structure_label(survey, info)
	if not sname.is_empty():
		out.append("BURIED: " + sname)
	return out


## The legend's key to the marks; returns the y below it. (x, y) is the left edge and first baseline.
static func draw_key(ci: CanvasItem, x: float, y: float, info: Dictionary) -> float:
	UiTheme.text(ci, Vector2(x, y), "SURVEY MARKS", 15, UiTheme.AMBER)
	y += 22.0
	var demo: Dictionary = {"tier": 1, "ores": [], "gems": [], "gas": true, "water": true, "faults": true}
	draw(ci, Vector2(x, y - 12.0), demo, 3, info)
	UiTheme.text(ci, Vector2(x + 88.0, y), "RICHNESS, GAS, WATER, FAULTS", 13, UiTheme.TEXT)
	y += 22.0
	var ores: Array = []
	var gems: Array = []
	for m: Variant in info.keys():
		if str(m).ends_with("_ore") or str(m) == "coal":
			ores.append(m)
		elif str(m) in ["gem", "amethyst", "emerald"]:
			gems.append(m)
	draw(ci, Vector2(x, y - 12.0), {"tier": -1, "ores": ores, "gems": gems, "gas": false, "water": false}, 0, info)
	UiTheme.text(ci, Vector2(x + 106.0, y + 4.0), "ORES, GEMS", 13, UiTheme.TEXT)
	return y + 24.0


## The last arrival in the map's legend ("LAST DIG +24 ORE +3 GEMS"), nothing before the first.
static func draw_last_dig(ci: CanvasItem, x: float, y: float, s: Dictionary) -> void:
	if s.is_empty():
		return
	UiTheme.text(ci, Vector2(x, y), "LAST DIG", 15, UiTheme.AMBER)
	UiTheme.text(ci, Vector2(x, y + 22.0), DigLog.summary_line(s), 14, UiTheme.TEXT)

# Environments (a node's "env", data/environments): one small icon per kind, and the words for the tooltip.

const ENV_R: float = 11.0
const ENV_COLORS: Dictionary = {
	"rockfall_seam": Color(0.88, 0.74, 0.5), "magma_heat": Color(1.0, 0.5, 0.18),
	"magnetite": Color(0.62, 0.8, 1.0), "gas_seam": Color(0.82, 0.9, 0.25),
}


## The environment's icon centred on c: a dark disc with a symbol, falling slabs (rockfall), a heat
## shimmer (magma), a compass needle (magnetite), a gas cloud (gas), a diamond for anything new.
static func draw_env(ci: CanvasItem, c: Vector2, env_id: String, dim: float = 1.0) -> void:
	var col: Color = ENV_COLORS.get(env_id, Color(0.95, 0.8, 0.4)) as Color
	col = Color(col, dim)
	ci.draw_circle(c, ENV_R, Color(0.02, 0.03, 0.035, 0.92 * dim))
	ci.draw_arc(c, ENV_R, 0.0, TAU, 20, col, 1.6, true)
	match env_id:
		"rockfall_seam":
			for i: int in range(3):
				var p: Vector2 = c + Vector2(-5.0 + 5.0 * float(i), -4.0 + 3.0 * float(i % 2))
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2.6, -2.2), p + Vector2(2.6, -2.8), p + Vector2(2.2, 2.4), p + Vector2(-2.4, 2.8)]), col)
			ci.draw_line(c + Vector2(-6.0, 7.0), c + Vector2(6.0, 7.0), col, 1.5)
		"magma_heat":
			for i: int in range(3):
				var x: float = c.x - 4.5 + 4.5 * float(i)
				ci.draw_polyline(PackedVector2Array([Vector2(x, c.y + 6.0), Vector2(x + 2.2, c.y + 2.0), Vector2(x - 2.2, c.y - 2.0), Vector2(x, c.y - 6.0)]), col, 1.8)
		"magnetite":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -7.5), c + Vector2(2.6, 0.0), c + Vector2(-2.6, 0.0)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, 7.5), c + Vector2(2.6, 0.0), c + Vector2(-2.6, 0.0)]), Color(col, 0.4 * dim))
			ci.draw_circle(c, 1.4, Color(0.02, 0.03, 0.035, dim))
		"gas_seam":
			ci.draw_circle(c + Vector2(-3.8, 1.6), 3.6, col)
			ci.draw_circle(c + Vector2(0.8, -2.2), 4.4, col)
			ci.draw_circle(c + Vector2(4.2, 2.0), 3.4, col)
		_:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), col)


## The environment in words for the tooltip: its name, then its blurb broken into short lines.
static func env_words(def: Dictionary, wrap: int = 40) -> PackedStringArray:
	var out := PackedStringArray()
	if def.is_empty():
		return out
	out.append("ENVIRONMENT: " + str(def.get("name", def.get("id", ""))).to_upper())
	var line: String = ""
	for word: String in str(def.get("blurb", "")).split(" ", false):
		if not line.is_empty() and line.length() + word.length() + 1 > wrap:
			out.append(line)
			line = word
		else:
			line = word if line.is_empty() else line + " " + word
	if not line.is_empty():
		out.append(line)
	return out


static func _names(ids: Array, info: Dictionary) -> String:
	if ids.is_empty():
		return "NONE"
	var names := PackedStringArray()
	for m: Variant in ids:
		names.append(str((info.get(str(m), {}) as Dictionary).get("name", str(m))).to_upper())
	return ", ".join(names)
