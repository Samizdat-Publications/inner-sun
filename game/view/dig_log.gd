class_name DigLog
extends RefCounted
## What the dig view remembers from the sim's events, so nothing in the sim has to know about it:
##  - `pickups`: the floating "+2 IRON" texts at the crown, one per "mined" event, merged when the same
##    material is cut again within MERGE_S, aged by real time (the PickupLayer draws them);
##  - `totals`: this segment's yield by material id, and `ore` / `gems` (the tally line);
##  - `toast`: the arrival summary built from "segment_done" (the panel shows it for TOAST_S);
##  - a buried structure's crates: each "loot" event is a floating text where the crate stood
##    ("CRATE: +4 COOLANT"), `crates` counts them and `loot` totals what they paid by resource.
## Read only: it follows `sim.events` by index (like the audio director), never writes the sim.

const MERGE_S: float = 0.5
const LIFE_S: float = 1.7
const TOAST_S: float = 5.0
const MAX_PICKUPS: int = 24
const LOOT_COLOR: Color = Color(1.0, 0.82, 0.42)

var pickups: Array[Dictionary] = []  ## {mat, res, amount, x_m, y_m, age, pop, text, color}
var totals: Dictionary = {}  ## material id -> resource units this segment (first mined first)
var ore: int = 0
var gems: int = 0
var toast: Dictionary = {}  ## {} or the arrival summary, see _summary
var crates: int = 0  ## Crates opened this segment.
var loot: Dictionary = {}  ## Resource id -> units the crates paid this segment.
var toast_age: float = 0.0
var _seen: int = 0
var _colors: Dictionary = {}


## Start following a (new) sim from its current end; forget everything shown.
func bind(sim: Sim) -> void:
	pickups.clear()
	totals = {}
	ore = 0
	gems = 0
	crates = 0
	loot = {}
	toast = {}
	toast_age = 0.0
	_colors = {}
	_seen = sim.events.size() if sim != null else 0


## Read the new events and age the texts by `delta` real seconds.
func update(sim: Sim, delta: float) -> void:
	if sim == null:
		return
	var n: int = sim.events.size()
	if n < _seen:
		_seen = 0
	for i: int in range(_seen, n):
		_on_event(sim, sim.events[i])
	_seen = n
	for p: Dictionary in pickups:
		p["age"] = float(p["age"]) + delta
		p["pop"] = maxf(0.0, float(p["pop"]) - delta * 5.0)
	var live: Array[Dictionary] = []
	for p: Dictionary in pickups:
		if float(p["age"]) < LIFE_S:
			live.append(p)
	pickups = live
	if not toast.is_empty():
		toast_age += delta
		if toast_age >= TOAST_S:
			toast = {}


func _on_event(sim: Sim, e: Dictionary) -> void:
	match str(e.get("kind", "")):
		"segment_begin":
			totals = {}
			ore = 0
			gems = 0
			crates = 0
			loot = {}
			toast = {}
		"loot":
			_on_loot(e)
		"miner_back":
			_on_miner_back(sim, e)
		"mined":
			_on_mined(sim, e)
		"gas_burst":
			_add_pickup(str(e.get("room", "gas")), "gas", 0, float(e.get("x_m", 0.0)), float(e.get("y_m", 0.0)), "GAS BURST", Color(0.82, 0.9, 0.3))
		"segment_done":
			toast = summary(e)
			toast["loot"] = loot.duplicate()
			toast["label"] = sim.drill.structures.label
			toast["crates_total"] = sim.drill.structures.crates_total
			toast_age = 0.0


func _on_mined(sim: Sim, e: Dictionary) -> void:
	var mat: String = str(e.get("material", ""))
	var res: String = str(e.get("res", ""))
	var amount: int = int(e.get("amount", 0))
	if amount <= 0:
		return
	totals[mat] = int(totals.get(mat, 0)) + amount
	if res == "gems":
		gems += amount
	else:
		ore += amount
	_add_pickup(mat, res, amount, float(e.get("x_m", 0.0)), float(e.get("y_m", 0.0)), "", color_of(sim, mat))


## The away miner climbed in: what they carried is paid now ("resource" events), so it joins the tally
## (as "miner", by its resource) and rises from the drill head as one text.
func _on_miner_back(sim: Sim, e: Dictionary) -> void:
	var haul: Dictionary = e.get("haul", {})
	for res: String in haul.keys():
		var n: int = int(haul[res])
		if n <= 0:
			continue
		totals["miner"] = int(totals.get("miner", 0)) + n
		if res == "gems":
			gems += n
		elif res == "ore":
			ore += n
		_add_pickup("miner", res, n, DrillMiner.head(sim.drill).x, DrillMiner.head(sim.drill).y, "MINER: +%d %s" % [n, res.to_upper()], Color(0.7, 1.0, 0.75), true)


## A crate paid: a floating text where it stood (absolute, not at the crown), counted in the tally.
func _on_loot(e: Dictionary) -> void:
	var res: String = str(e.get("res", ""))
	var amount: int = int(e.get("amount", 0))
	crates += 1
	if amount > 0:
		loot[res] = int(loot.get(res, 0)) + amount
	_add_pickup("crate", res, amount, float(e.get("x_m", 0.0)), float(e.get("y_m", 0.0)), loot_text(res, amount), LOOT_COLOR, true)


func _add_pickup(mat: String, res: String, amount: int, x_m: float, y_m: float, text: String, col: Color, absolute: bool = false) -> void:
	for p: Dictionary in pickups:
		if str(p["mat"]) == mat and float(p["age"]) < MERGE_S and str(p["text"]) == text:
			p["amount"] = int(p["amount"]) + amount
			p["pop"] = 1.0
			return
	if pickups.size() >= MAX_PICKUPS:
		pickups.remove_at(0)
	# Crate texts that are up together are stacked (slot 0, 1, 2) so neighbouring crates do not overprint.
	var slot: int = 0
	if absolute:
		for p: Dictionary in pickups:
			if bool(p.get("abs", false)):
				slot += 1
		slot = slot % 3
	pickups.append({"mat": mat, "res": res, "amount": amount, "x_m": x_m, "y_m": y_m, "age": 0.0,
			"pop": 1.0, "text": text, "color": col, "abs": absolute, "slot": slot})


## The material's colour hint from the segment's rock table (cached per material id).
func color_of(sim: Sim, mat: String) -> Color:
	if _colors.has(mat):
		return _colors[mat]
	for m: Dictionary in sim.drill.materials:
		if str(m.get("id", "")) == mat:
			_colors[mat] = Color.html(str(m.get("color", "#c0c0c0")))
			return _colors[mat]
	return Color(0.75, 0.75, 0.75)


# Pure helpers ------------------------------------------------------------------------------------

## A short upper-case name for a material id ("iron_ore" > "IRON", "gem" > "QUARTZ").
static func short_name(mat: String) -> String:
	if mat == "gem":
		return "QUARTZ"
	return mat.replace("_ore", "").replace("_pocket", "").replace("_", " ").to_upper()


## The text of a floating pickup ("+2 IRON", or its own text such as "GAS BURST").
static func pickup_text(p: Dictionary) -> String:
	var t: String = str(p.get("text", ""))
	if not t.is_empty():
		return t
	return "+%d %s" % [int(p["amount"]), short_name(str(p["mat"]))]


## The text a crate's loot makes: "CRATE: +4 COOLANT", or "CRATE: EMPTY" when it paid nothing.
static func loot_text(res: String, amount: int) -> String:
	if amount <= 0 or res.is_empty():
		return "CRATE: EMPTY"
	return "CRATE: +%d %s" % [amount, short_name(res)]


## Text colour that reads on dark rock: a dark material colour (coal) is lifted toward white.
static func readable(col: Color) -> Color:
	var lum: float = col.r * 0.3 + col.g * 0.59 + col.b * 0.11
	if lum >= 0.6:
		return col
	return col.lerp(Color(1, 1, 1), clampf(0.65 - lum + 0.1, 0.0, 0.8))


## Text size in screen px: gold bigger, gems bigger still, a merged stack grows a little.
static func pickup_size(p: Dictionary) -> int:
	var base: int = 26
	var mat: String = str(p.get("mat", ""))
	if mat == "crate":
		base = 30
	elif str(p.get("res", "")) == "gems":
		base = 34 if mat != "emerald" else 38
	elif mat == "gold_ore":
		base = 32
	elif mat == "silver_ore":
		base = 29
	return base + mini(6, int(p.get("amount", 0)) / 6)


## The tally line: "THIS DIG  coal 4  iron 14 = +18 ore +3 gems" (empty values left out).
func tally_text() -> String:
	var parts: PackedStringArray = PackedStringArray(["THIS DIG"])
	for mat: String in totals.keys():
		parts.append("%s %d" % [short_name(mat).to_lower(), int(totals[mat])])
	parts.append("= +%d ore +%d gems" % [ore, gems])
	return "  ".join(parts)


## The arrival summary from a "segment_done" event.
static func summary(e: Dictionary) -> Dictionary:
	return {"time_s": float(e.get("time_s", 0.0)), "distance_m": float(e.get("distance_m", 0.0)),
			"ore": int(e.get("ore", 0)), "gems": int(e.get("gems", 0)), "yield": (e.get("yield", {}) as Dictionary).duplicate(),
			"gas_bursts": int(e.get("gas_bursts", 0)), "structure": str(e.get("structure", "")),
			"entered": bool(e.get("entered", false)), "crates": int(e.get("crates", 0))}


## The newest arrival summary in the event log ({} before the first), for the map's last-dig block.
static func last_summary(sim: Sim) -> Dictionary:
	for i: int in range(sim.events.size() - 1, -1, -1):
		if str(sim.events[i].get("kind", "")) == "segment_done":
			return summary(sim.events[i])
	return {}


## One line for a summary: "+24 ore +3 gems" or "nothing worth taking".
static func summary_line(s: Dictionary) -> String:
	if int(s.get("ore", 0)) == 0 and int(s.get("gems", 0)) == 0:
		return "NOTHING WORTH TAKING"
	return "+%d ORE  +%d GEMS" % [int(s.get("ore", 0)), int(s.get("gems", 0))]
