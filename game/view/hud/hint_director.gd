class_name HintDirector
extends Control
## One-time hints that teach a verb the first time it would pay off. Each hint is a pure condition on
## the sim state (static helpers below, tested), fires once ever per profile (`Profile.hints_seen`),
## at most one every GAP_S seconds of real time, never while an overlay is open (except the two hints
## that belong to an overlay), never in a fight (except the fight hints), and never in a bot, capture
## or replay run (`enabled` is false there). A hint shows as a TOPSIDE line low in the world area (the
## radio lines `hint_<name>` in game/data/radio) and a pulsing brass outline around the control that
## owns the key for GLOW_S seconds. The view only reads the sim; the line is picked by a hash of the
## profile's run count, never by the sim's random streams.
##
## Dev flag `--hint=<name>` (Main sets `force`): shows that one hint about 2 s into play, whatever the
## conditions and the profile say, and does not record it (for stills).
##
## Mount (RunScreen, on the HUD layer, after the panels):  hints = HintDirector.build(layer, self)

const GAP_S: float = 20.0  ## Least real time between two hints.
const SHOW_S: float = 9.0  ## How long the TOPSIDE line stays up.
const GLOW_S: float = 6.0  ## How long the control glows.
const CHECK_S: float = 0.5  ## Conditions are looked at twice a second.
const POWER_HOLD_S: float = 3.0  ## The drill must sit at 0 bars this long while drilling.
const STEER_AFTER_S: float = 20.0  ## Drilling time before the steering hint, if no steer order was given.
const CREW_HOLD_S: float = 3.0  ## A hazard nobody is heading to must last this long.
const FORCE_AFTER_S: float = 2.0
const MINER_NEAR_M: float = 12.0
const MINER_FRONT_ROWS: float = 2.0  ## The pursuer's front must be at least this many map rows behind.
const MINER_MIN_VALUE: float = 20.0
const BLAST_NEAR_M: float = 14.0
const BLAST_MIN_VALUE: float = 40.0
const VALUE_GEM: float = 3.0
const SEAM_MIN_WIDTH_M: float = 3.0
const SEAM_LEVEL_M: float = 2.5
const BRACING_AHEAD_M: float = 4.0
const STRUCTURE_NEAR_M: float = 15.0
const FIRE_DOUSE: float = 0.3
const FIRE_ANY: float = 0.05
const CLOCK_RECT: Rect2 = Rect2(1390.0, 57.0, 340.0, 28.0)  ## The top bar's clock and pause slot.
const STRIP_W: float = 780.0
const STRIP_BOTTOM: float = 880.0

## Every hint, in the order they are offered when several are due at once.
const NAMES: Array[String] = [
	"bit", "douse", "crew", "power", "weapons", "requisitions", "map", "structure", "miner", "blast",
	"bracing", "hold_depth", "steer", "pause",
]
## Hints that may fire in a fight.
const FIGHT_NAMES: Array[String] = ["weapons", "pause"]
## Hints that belong to an overlay (the node map, the death screen) and fire while it is open.
const OVERLAY_NAMES: Array[String] = ["map", "requisitions"]
const TRIGGER_PREFIX: String = "hint_"

var sim: Sim = null
var profile: Profile = null
var screen: RunScreen = null
var enabled: bool = false  ## Set by Main: true only for a person playing a full run.
var force: String = ""  ## Dev: the one hint to show about FORCE_AFTER_S in (not recorded).
var douse_rect: Callable = Callable()  ## Main: the screen rect of the worst burning room's DOUSE button.
var current: String = ""  ## The hint being shown ("" when none).
var line: String = ""  ## Its TOPSIDE text.
var shown: Array[String] = []  ## Hints shown since bind (also when forced), in order.

var _strip: Label
var _show_left: float = 0.0
var _glow_left: float = 0.0
var _glow_rect: Callable = Callable()
var _since: float = GAP_S  ## Real seconds since the last hint.
var _check: float = 0.0
var _elapsed: float = 0.0
var _drill_s: float = 0.0  ## Drilling seconds this run (for the steering hint).
var _power_s: float = 0.0
var _crew_s: float = 0.0
var _forced: bool = false
var _t: float = 0.0


static func build(parent: Control, p_screen: RunScreen) -> HintDirector:
	var h := HintDirector.new()
	h.position = Vector2.ZERO
	h.size = Vector2(1920, 1080)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.screen = p_screen
	parent.add_child(h)
	h._build_strip()
	h.bind(p_screen.sim, p_screen.profile)
	return h


func bind(p_sim: Sim, p_profile: Profile) -> void:
	sim = p_sim
	profile = p_profile
	current = ""
	line = ""
	shown.clear()
	_show_left = 0.0
	_glow_left = 0.0
	_glow_rect = Callable()
	_since = GAP_S
	_check = 0.0
	_elapsed = 0.0
	_drill_s = 0.0
	_power_s = 0.0
	_crew_s = 0.0
	_forced = false
	if _strip != null:
		_strip.visible = false
	queue_redraw()


func _build_strip() -> void:
	_strip = Label.new()
	_strip.position = Vector2(RunScreen.WORLD_RECT.get_center().x - STRIP_W * 0.5, STRIP_BOTTOM - 60.0)
	_strip.custom_minimum_size = Vector2(STRIP_W, 0)
	_strip.size = Vector2(STRIP_W, 0)
	_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_strip.add_theme_font_size_override("font_size", 20)
	_strip.add_theme_color_override("font_color", UiTheme.CRT)
	_strip.add_theme_stylebox_override("normal", UiTheme.box(Color(UiTheme.STEEL_DEEP, 0.94), UiTheme.BRASS, 3, 2, 14))
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.visible = false
	add_child(_strip)


# Conditions (pure: they read the sim, change nothing) ----------------------------------------------

## A fight is on.
static func in_fight(s: Sim) -> bool:
	return s.combat.active and s.enemy != null


## Drilling in a full run, with no fight on.
static func drilling(s: Sim) -> bool:
	return s.run.mode == "run" and s.drill.active and s.run.phase == "drill" and not in_fight(s)


## power: the drill room has 0 bars while a segment is under way (the director waits POWER_HOLD_S).
## A parked drill (the miner is out) is not "unpowered": it stands still on purpose.
static func drill_unpowered(s: Sim) -> bool:
	var d: DrillSim = s.drill
	if not drilling(s) or d.drill_room < 0 or d.parked or d.miner.active:
		return false
	return s.ship.rooms[d.drill_room].sys_power == 0


## steer: no steer order has been given yet this run (the director waits STEER_AFTER_S of drilling).
static func never_steered(s: Sim) -> bool:
	for c: Dictionary in s.command_log:
		if str(c.get("type", "")) == "steer":
			return false
	return true


## The clusters of ore and gem cells within `radius_m` of `centre` (segment meters), each as
## {"cells": n, "value": ore units plus gems x value_gem, "box": Rect2 of its cells, "near": the cell
## centre closest to `centre`, "near_m": that distance}. Crates are not ore. Breadth first, row-major
## order, so the same grid always gives the same list.
static func clusters(d: DrillSim, centre: Vector2, radius_m: float, value_gem: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not d.active or d.cols <= 0:
		return out
	var cell: float = d.cell_m
	var ore_i: int = RunState.RESOURCES.find("ore")
	var c_lo: int = maxi(0, floori((centre.x - radius_m) / cell))
	var c_hi: int = mini(d.cols - 1, floori((centre.x + radius_m) / cell))
	var r_lo: int = maxi(0, floori((centre.y - radius_m) / cell))
	var r_hi: int = mini(d.rows - 1, floori((centre.y + radius_m) / cell))
	var seen := PackedByteArray()
	seen.resize(d.grid.size())
	for r: int in range(r_lo, r_hi + 1):
		for c: int in range(c_lo, c_hi + 1):
			var i: int = r * d.cols + c
			if seen[i] == 1 or not _ore_cell(d, i):
				continue
			var queue := PackedInt32Array([i])
			seen[i] = 1
			var k: int = 0
			var value: float = 0.0
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			var near := Vector2.ZERO
			var near_m: float = INF
			while k < queue.size():
				var j: int = queue[k]
				k += 1
				var m: int = d.grid[j]
				value += float(d.yield_amount_of[m]) * (1.0 if d.yield_res_of[m] == ore_i else value_gem)
				var jr: int = j / d.cols
				var jc: int = j % d.cols
				var p := Vector2((float(jc) + 0.5) * cell, (float(jr) + 0.5) * cell)
				lo = Vector2(minf(lo.x, p.x - cell * 0.5), minf(lo.y, p.y - cell * 0.5))
				hi = Vector2(maxf(hi.x, p.x + cell * 0.5), maxf(hi.y, p.y + cell * 0.5))
				var dist: float = p.distance_to(centre)
				if dist < near_m:
					near_m = dist
					near = p
				var nbs := PackedInt32Array([j - d.cols if jr > 0 else -1, j - 1 if jc > 0 else -1,
						j + 1 if jc < d.cols - 1 else -1, j + d.cols if jr < d.rows - 1 else -1])
				for n: int in nbs:
					if n >= 0 and seen[n] == 0 and _ore_cell(d, n):
						seen[n] = 1
						queue.append(n)
			out.append({"cells": queue.size(), "value": value, "box": Rect2(lo, hi - lo), "near": near, "near_m": near_m})
	return out


static func _ore_cell(d: DrillSim, i: int) -> bool:
	var m: int = d.grid[i]
	return m != 0 and d.yield_res_of[m] >= 0 and d.loot_of[m] == 0


## The ship's centre, segment meters (the blast range is measured from it).
static func ship_centre(d: DrillSim) -> Vector2:
	return d.ship_pos + d.ship_size * 0.5


## hold_depth: a seam (a wide, flat cluster of ore) to the side of the ship, level with the drill head,
## while the heading is still down.
static func seam_beside(s: Sim) -> bool:
	if not drilling(s) or ScannerExtras.holding(s.drill.heading_deg, s.drill.target_heading_deg):
		return false
	var d: DrillSim = s.drill
	var head: Vector2 = MinerRoute.head(d)
	for cl: Dictionary in clusters(d, head, BLAST_NEAR_M, VALUE_GEM):
		var box: Rect2 = cl["box"]
		if box.size.x < SEAM_MIN_WIDTH_M or box.size.y > box.size.x:
			continue
		if box.position.y > head.y + SEAM_LEVEL_M or box.end.y < head.y - SEAM_LEVEL_M:
			continue
		var gap: float = maxf(box.position.x - head.x, head.x - box.end.x)
		if gap >= 2.0 and gap <= BLAST_NEAR_M:
			return true
	return false


## miner: ore within the miner's reach but off the drill's path (MinerPlanner.target), the pursuer's
## front at least MINER_FRONT_ROWS behind, and a crew member who could go.
static func miner_worth(s: Sim) -> bool:
	var d: DrillSim = s.drill
	if not drilling(s) or d.miner.active or d.drill_room < 0:
		return false
	if s.run.ship_row_f(s) - s.run.pursuer_row < MINER_FRONT_ROWS:
		return false
	if MinerPlanner.crew(s, d).is_empty():
		return false
	return not MinerPlanner.target(s, d, 1.0, VALUE_GEM, MINER_MIN_VALUE, 3.0).is_empty()


## blast: a rich cluster within the blast range of the ship, a launcher aboard and charges in stock
## (powered weapons or not).
static func blast_worth(s: Sim) -> bool:
	if not drilling(s) or BlastCard.launcher_slot(s) < 0 or BlastCard.charges_of(s) == 0:
		return false
	var d: DrillSim = s.drill
	for cl: Dictionary in clusters(d, ship_centre(d), BLAST_NEAR_M, VALUE_GEM):
		if float(cl["near_m"]) <= BLAST_NEAR_M and float(cl["value"]) >= BLAST_MIN_VALUE:
			return true
	return false


## bracing: fault rock within BRACING_AHEAD_M ahead and no bracing layer up.
static func fault_unbraced(s: Sim) -> bool:
	if not drilling(s):
		return false
	return AlertsStrip.fault_ahead_m(s, BRACING_AHEAD_M) >= 0.0 and s.systems.bracing_layers(s.player) == 0


## douse: a room burning above the douse level and coolant in stock.
static func fire_to_douse(s: Sim) -> bool:
	if s.run.mode != "run" or s.run.get_res("coolant") < 1:
		return false
	for r: Room in s.ship.rooms:
		if r.fire > FIRE_DOUSE:
			return true
	return false


## bit: the bit is broken.
static func bit_broken(s: Sim) -> bool:
	return s.run.mode == "run" and s.drill.active and s.drill.bit_broken


## crew: a fire or a breach that no live crew member is working on or heading to.
static func hazard_unattended(s: Sim) -> bool:
	if s.run.mode != "run":
		return false
	for r: Room in s.ship.rooms:
		if r.fire <= FIRE_ANY and r.breach_m2 <= 0.0:
			continue
		var covered: bool = false
		for c: CrewMember in s.ship.crew:
			if c.alive and not c.away and ((c.job_room == r.index and not c.job_kind.is_empty()) or c.order_room == r.index):
				covered = true
		if not covered:
			return true
	return false


## weapons: a fight has started.
static func fight_on(s: Sim) -> bool:
	return s.run.mode == "run" and in_fight(s)


## requisitions: the death screen is up and there is research to spend.
static func requisitions_due(death_open: bool, research: int) -> bool:
	return death_open and research > 0


## map: the node map is open.
static func map_due(map_open: bool) -> bool:
	return map_open


## pause: the first fire, fight or miner sortie, whichever comes first.
static func pause_due(s: Sim) -> bool:
	if s.run.mode != "run":
		return false
	if in_fight(s) or s.drill.miner.active:
		return true
	for r: Room in s.ship.rooms:
		if r.fire > FIRE_ANY:
			return true
	return false


## structure: a buried structure not yet broken into, within STRUCTURE_NEAR_M of the drill head.
static func structure_near(s: Sim) -> bool:
	var d: DrillSim = s.drill
	if not drilling(s) or not d.structures.has_structure() or d.structures.entered:
		return false
	var head: Vector2 = MinerRoute.head(d)
	var r: Rect2 = d.structures.rect
	var dx: float = maxf(maxf(r.position.x - head.x, head.x - r.end.x), 0.0)
	var dy: float = maxf(maxf(r.position.y - head.y, head.y - r.end.y), 0.0)
	return Vector2(dx, dy).length() <= STRUCTURE_NEAR_M


# Pacing and picking --------------------------------------------------------------------------------

## Whether `hint` may be shown now: unseen is checked by the caller. Pure given its arguments.
static func allowed_now(hint: String, overlay_open: bool, fighting: bool) -> bool:
	if overlay_open and not OVERLAY_NAMES.has(hint):
		return false
	if fighting and not FIGHT_NAMES.has(hint):
		return false
	return true


## The text of a hint: one of its radio lines, picked by a hash of the run count. "" when there is none.
static func line_for(s: Sim, hint: String, runs: int) -> String:
	var texts := PackedStringArray()
	var radios: Dictionary = s.db.table("radio")
	var ids: Array = radios.keys()
	ids.sort()
	for id: Variant in ids:
		var entry: Dictionary = radios[id]
		for ln: Variant in entry.get("lines", []):
			var l: Dictionary = ln
			if str(l.get("trigger", "")) == TRIGGER_PREFIX + hint and not str(l.get("text", "")).is_empty():
				texts.append(str(l["text"]))
	if texts.is_empty():
		return ""
	return texts[absi(("%s/%d" % [hint, runs]).hash()) % texts.size()]


## Whether hint `hint` is due now, given the director's own timers.
func is_due(hint: String) -> bool:
	if sim == null:
		return false
	match hint:
		"power":
			return _power_s >= POWER_HOLD_S
		"steer":
			return _drill_s >= STEER_AFTER_S and never_steered(sim)
		"hold_depth":
			return seam_beside(sim)
		"miner":
			return miner_worth(sim)
		"blast":
			return blast_worth(sim)
		"bracing":
			return fault_unbraced(sim)
		"douse":
			return fire_to_douse(sim)
		"bit":
			return bit_broken(sim)
		"crew":
			return _crew_s >= CREW_HOLD_S
		"weapons":
			return fight_on(sim)
		"requisitions":
			return screen != null and profile != null and requisitions_due(screen.death.is_open(), profile.research)
		"map":
			return screen != null and sim.run.mode == "run" and map_due(screen.map.is_open())
		"pause":
			return pause_due(sim)
		"structure":
			return structure_near(sim)
	return false


func seen(hint: String) -> bool:
	return profile != null and profile.hints_seen.has(hint)


## The hint to show now, or "": the first unseen due hint that is allowed, if the gap has passed.
func pick() -> String:
	if _since < GAP_S:
		return ""
	var overlay: bool = screen != null and screen.overlay_open()
	var fighting: bool = sim != null and in_fight(sim)
	for hint: String in NAMES:
		if seen(hint) or not allowed_now(hint, overlay, fighting):
			continue
		if is_due(hint):
			return hint
	return ""


## Show a hint: the line, the glow, and (unless it is a dev force) remember it in the profile.
func fire(hint: String, record: bool = true) -> void:
	if sim == null:
		return
	var text: String = line_for(sim, hint, profile.runs if profile != null else 0)
	if text.is_empty():
		return
	current = hint
	line = text
	shown.append(hint)
	_show_left = SHOW_S
	_glow_left = GLOW_S
	_glow_rect = func() -> Rect2: return target_rect(hint)
	_since = 0.0
	if _strip != null:
		_strip.text = "TOPSIDE: " + text
		_strip.modulate.a = 0.0
		_strip.visible = true
		_strip.reset_size()
		_strip.position.y = STRIP_BOTTOM - _strip.get_combined_minimum_size().y
	if record and profile != null:
		profile.hints_seen.append(hint)
		profile.hints_seen.sort()
		profile.save()


## The screen rectangle of the control a hint points at (Rect2() when there is none to show).
func target_rect(hint: String) -> Rect2:
	if screen == null:
		return Rect2()
	match hint:
		"power":
			return _power_row("drill")
		"bracing":
			return _power_row("bracing")
		"steer", "hold_depth", "structure":
			return screen.scanner.get_global_rect()
		"miner":
			return screen.miner.get_global_rect()
		"blast":
			return screen.blast.get_global_rect()
		"douse":
			return Rect2() if not douse_rect.is_valid() else (douse_rect.call() as Rect2)
		"bit":
			return screen.alerts.get_global_rect()
		"crew":
			return screen.cards.get_global_rect()
		"weapons":
			return screen.weapons.get_global_rect()
		"requisitions":
			var b: Button = screen.death._req_button
			return b.get_global_rect() if b != null else Rect2()
		"map":
			return MapView.LEGEND
		"pause":
			return CLOCK_RECT
	return Rect2()


## The power panel's row for a system, or the whole panel when the ship has no such row.
func _power_row(system: String) -> Rect2:
	var p: PowerPanel = screen.power
	var row: int = PowerPanel.powered_rooms(sim.ship).find(sim.ship.room_with_system(system))
	if row < 0:
		return p.get_global_rect()
	return Rect2(p.position + Vector2(0.0, PowerPanel.ROW_TOP + float(row) * PowerPanel.ROW_H), Vector2(PowerPanel.WIDTH, PowerPanel.ROW_H))


# Frame loop ----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if sim == null:
		return
	if _show_left > 0.0:
		_show_left -= delta
		if _strip != null:
			_strip.modulate.a = clampf(_show_left / 0.8, 0.0, 1.0) * clampf((SHOW_S - _show_left) / 0.25, 0.0, 1.0)
		if _show_left <= 0.0:
			if _strip != null:
				_strip.visible = false
			current = ""
	if _glow_left > 0.0:
		_glow_left -= delta
		queue_redraw()
	elif current.is_empty():
		_glow_rect = Callable()
	_since += delta
	_elapsed += delta
	if drilling(sim):
		_drill_s += delta
	# Timers that need a steady count run every frame; the rest of the conditions twice a second.
	_power_s = _power_s + delta if drill_unpowered(sim) else 0.0
	_crew_s = _crew_s + delta if hazard_unattended(sim) else 0.0
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_S
	if not force.is_empty():
		_try_force()
		return
	if not enabled or profile == null:
		return
	var hint: String = pick()
	if not hint.is_empty():
		fire(hint)


## The dev hint: once, FORCE_AFTER_S in (a drill hint waits for the drill to be at work).
func _try_force() -> void:
	if _forced or _elapsed < FORCE_AFTER_S:
		return
	if not OVERLAY_NAMES.has(force) and force != "pause" and not (sim.drill.active and sim.run.phase == "drill"):
		return
	_forced = true
	fire(force, false)


func _draw() -> void:
	if _glow_left <= 0.0 or not _glow_rect.is_valid():
		return
	var r: Rect2 = _glow_rect.call() as Rect2
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var fade: float = clampf(_glow_left / 1.0, 0.0, 1.0)
	var pulse: float = 0.55 + 0.45 * UiTheme.pulse(_t, 1.6)
	var col := Color(UiTheme.BRASS_LIGHT, fade * pulse)
	draw_rect(r.grow(5.0), Color(UiTheme.AMBER, 0.16 * fade * pulse), true)
	draw_rect(r.grow(4.0), col, false, 4.0)
	draw_rect(r.grow(9.0), Color(UiTheme.AMBER, 0.45 * fade * pulse), false, 2.0)
