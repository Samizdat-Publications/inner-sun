class_name RunState
extends SimModule
## The run around the ship: the phase (what steps each tick), the resources, the depth, the layer's
## node map, travel between nodes, the pursuer, what was learned, and how the run ended. Resources are
## integers changed only through add(), so every change is an event and balance reports can follow
## them. In "scenario" mode (tests, captures, the M0 drills) the run structure is off and ScenarioRun
## decides the outcome.
##
## For the view (read only):
## - map: Array of rows, each an Array of node Dictionaries (format in map_gen.gd: id, index, row,
##   col, x_m, type, links, enemy). nodes: the same Dictionaries flat, by index.
## - current_node / target_node: node ids ("" when none). links_from_current().
## - is_revealed(node), is_visited(node), is_overtaken(node); scanner_rows (rows seen ahead).
## - pursuer_row (float map row of the pursuer's front), caught, ship_row_f(sim).
##
## Travel: {"type": "choose_node", "node": id} in phase "idle", to a node linked from the current one.
## It spends one power cell (none left: the segment runs at reserve_speed_factor) and starts a drilling
## segment; on arrival the drill calls arrive(), which hands the node to Encounter or CombatSim.
##
## The pursuer: its front advances every world tick by rows_per_s * dt plus rows_per_noise times the
## drill noise made since the last tick (layer data). Unvisited nodes in rows at or above
## floor(pursuer_row) are overtaken; arriving at one, its content is gone and the pursuer strikes. The
## ship's position is a float row (current row plus drilling progress). Caught: the front reaches it;
## then it strikes every strike_every_s (hull, a breach in a random room, sometimes a fire). The front
## is capped just below the ship's row plus one: it can swallow the row the ship is drilling toward
## (so a caught ship loses its next node too), never the one after.

const PHASES: Array[String] = ["scenario", "idle", "drill", "dialog", "store", "combat", "dead", "won"]
const WORLD_PHASES: Array[String] = ["scenario", "idle", "drill", "combat"]
const RESOURCES: Array[String] = ["hull", "ore", "gems", "coolant", "cells", "bits", "charges"]
const COMMANDS: Array[String] = ["choose_node"]
const FLOOD_LIMIT_S: float = 10.0
const DEFAULT_LAYER: String = "crust"
const TUNING_KEYS: Array[String] = [
	"run.strike_every_s", "run.strike_hull_pts", "run.strike_breach_m2", "run.strike_fire_chance",
	"run.strike_fire_level", "run.reserve_speed_factor", "run.pursuer_cap_gap_rows",
]

var mode: String = "scenario"  ## "scenario" or "run".
var phase: String = "scenario"
var resources: Dictionary = {}
var depth_m: float = 0.0
var known_codex: PackedStringArray = PackedStringArray()  ## What the profile knew at the start (sorted).
var learned: PackedStringArray = PackedStringArray()  ## Codex entries learned this run, in order.
var end_cause: String = ""
var pursuer_row: float = -1.5  ## Map row the pursuer's front has reached.
var reveal_bonus: int = 0  ## Extra scanner rows for the rest of the layer (events).
# The map (run mode only).
var layer_id: String = ""
var layer: Dictionary = {}
var map: Array = []
var nodes: Array[Dictionary] = []
var current_node: String = ""
var target_node: String = ""
var visited: PackedByteArray = PackedByteArray()  ## By node index.
var overtaken: PackedByteArray = PackedByteArray()  ## By node index.
var scanner_rows: int = 0
var caught: bool = false
var strikes: int = 0

var _index_of: Dictionary = {}  ## node id -> index (lookup only, never iterated).
var _current: int = -1
var _target: int = -1
var _map_state: Array = []
var _last_noise: float = 0.0
var _overtaken_row: int = -1000  ## Highest map row already swept for overtaken nodes.
var _strike_ticks: int = 0
# Tuning, read once in begin().
var _rate_per_tick: float = 0.0
var _rows_per_noise: float = 0.0
var _strike_every: int = 480
var _strike_hull: int = 2
var _strike_breach: float = 0.0
var _strike_fire_chance: float = 0.0
var _strike_fire_level: float = 0.2
var _reserve_factor: float = 0.5
var _cap_gap: float = 0.001


func _init(p_mode: String, p_known_codex: PackedStringArray) -> void:
	mode = p_mode
	known_codex = p_known_codex.duplicate()
	known_codex.sort()
	for r: String in RESOURCES:
		resources[r] = 0


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


## Called once by the Sim after every module exists.
func begin(sim: Sim) -> void:
	resources["hull"] = sim.ship.hull_max
	if mode != "run":
		return
	var start: Dictionary = sim.ship.source_def.get("start_resources", {})
	for r: String in RESOURCES:
		if r != "hull" and start.has(r):
			resources[r] = int(start[r])
	var db: DataDB = sim.db
	_rows_per_noise = 0.0
	_strike_every = maxi(1, roundi(db.tune("run.strike_every_s") * Sim.TICK_HZ))
	_strike_hull = roundi(db.tune("run.strike_hull_pts"))
	_strike_breach = db.tune("run.strike_breach_m2")
	_strike_fire_chance = db.tune("run.strike_fire_chance")
	_strike_fire_level = db.tune("run.strike_fire_level")
	_reserve_factor = db.tune("run.reserve_speed_factor")
	_cap_gap = db.tune("run.pursuer_cap_gap_rows")
	layer_id = str(sim.options.get("layer", DEFAULT_LAYER))
	layer = db.table("layers").get(layer_id, {})
	if layer.is_empty():
		push_error("RunState: no layer \"%s\" in data/layers" % layer_id)
	else:
		_build_map(sim)
	set_phase(sim, "idle")


func _build_map(sim: Sim) -> void:
	map = MapGen.generate(layer, sim.rng.get_stream("map"))
	for row: Array in map:
		for n: Dictionary in row:
			_index_of[str(n["id"])] = nodes.size()
			nodes.append(n)
			_map_state.append([n["id"], n["type"], n["x_m"], n["enemy"], Array(n["links"] as PackedStringArray)])
	visited.resize(nodes.size())
	overtaken.resize(nodes.size())
	_current = 0
	current_node = str(nodes[0]["id"])
	visited[0] = 1
	var pd: Dictionary = layer.get("pursuer", {})
	pursuer_row = float(pd.get("start_row", -1.5))
	_rate_per_tick = float(pd.get("rows_per_s", 0.0)) / Sim.TICK_HZ
	_rows_per_noise = float(pd.get("rows_per_noise", 0.0))
	_overtaken_row = floori(pursuer_row)
	_last_noise = sim.drill.noise_total
	scanner_rows = _scanner(sim)


# Queries -----------------------------------------------------------------------------------------

func get_res(res: String) -> int:
	return int(resources.get(res, 0))


func node(id: String) -> Dictionary:
	var i: int = int(_index_of.get(id, -1))
	return nodes[i] if i >= 0 else {}


func current_row() -> int:
	return int(nodes[_current]["row"]) if _current >= 0 else 0


func links_from_current() -> PackedStringArray:
	return nodes[_current]["links"] if _current >= 0 else PackedStringArray()


## The ship's position on the map as a float row: the current node's row plus drilling progress.
func ship_row_f(sim: Sim) -> float:
	var r: float = float(current_row())
	if _target >= 0 and phase == "drill":
		r += sim.drill.progress() * float(int(nodes[_target]["row"]) - current_row())
	return r


func is_visited(n: Dictionary) -> bool:
	return visited[int(n["index"])] == 1


func is_overtaken(n: Dictionary) -> bool:
	return overtaken[int(n["index"])] == 1


## The node's type is known: visited, or within scanner range of the current row.
func is_revealed(n: Dictionary) -> bool:
	return is_visited(n) or int(n["row"]) <= current_row() + scanner_rows


func world_running() -> bool:
	return WORLD_PHASES.has(phase)


func is_over() -> bool:
	return phase == "dead" or phase == "won"


## A codex entry is known if the profile knew it or this run learned it.
func knows(codex_id: String) -> bool:
	return known_codex.has(codex_id) or learned.has(codex_id)


# Changes -----------------------------------------------------------------------------------------

## Change a resource by an exact amount (never below zero; hull never above the ship's maximum).
## Returns the change actually applied.
func add(sim: Sim, res: String, amount: int) -> int:
	if not resources.has(res):
		push_error("RunState.add: unknown resource \"%s\"" % res)
		return 0
	var before: int = int(resources[res])
	var after: int = maxi(0, before + amount)
	if res == "hull":
		after = mini(after, sim.ship.hull_max)
	resources[res] = after
	if after != before:
		sim.emit("resource", {"res": res, "amount": after - before, "now": after})
	return after - before


func set_phase(sim: Sim, p: String) -> void:
	if not PHASES.has(p):
		push_error("RunState.set_phase: unknown phase \"%s\"" % p)
		return
	if p == phase:
		return
	var was: String = phase
	phase = p
	sim.emit("phase", {"from": was, "to": p})


func learn(sim: Sim, codex_id: String) -> void:
	if knows(codex_id):
		return
	learned.append(codex_id)
	sim.emit("codex", {"id": codex_id})


## Move the pursuer's front by a number of map rows (positive brings it closer).
func move_pursuer(sim: Sim, rows: float) -> void:
	pursuer_row += rows
	sim.emit("pursuer_moved", {"rows": rows})
	if not nodes.is_empty():
		_cap_pursuer(sim)
		_sweep_overtaken(sim)


## The scanner sees this many more rows ahead for the rest of the layer.
func add_reveal(sim: Sim, rows: int) -> void:
	reveal_bonus += rows
	sim.emit("reveal", {"rows": rows})
	if not nodes.is_empty():
		scanner_rows = _scanner(sim)


func end_run(sim: Sim, p_phase: String, cause: String) -> void:
	if is_over():
		return
	end_cause = cause
	set_phase(sim, p_phase)
	sim.emit("run_over", {"result": p_phase, "cause": cause})


## {"type": "choose_node", "node": id}
func apply(sim: Sim, cmd: Dictionary) -> void:
	if str(cmd.get("type", "")) == "choose_node":
		choose_node(sim, str(cmd.get("node", "")))


## Start the drilling segment to a node linked from the current one. Returns false if refused.
func choose_node(sim: Sim, id: String) -> bool:
	var why: String = ""
	if mode != "run" or nodes.is_empty():
		why = "not a run"
	elif phase != "idle":
		why = "not idle (phase %s)" % phase
	elif not links_from_current().has(id):
		why = "\"%s\" is not linked from %s" % [id, current_node]
	if not why.is_empty():
		sim.emit("bad_command", {"type": "choose_node", "why": why})
		return false
	var from: Dictionary = nodes[_current]
	var to: Dictionary = node(id)
	var reserve: bool = get_res("cells") <= 0
	sim.drill.speed_scale = _reserve_factor if reserve else 1.0
	var rows: int = int(to["row"]) - int(from["row"])
	var ok: bool = sim.drill.begin_segment(sim, "%s-%s" % [from["id"], to["id"]],
			float(layer.get("row_depth_m", 36.0)) * float(rows), float(to["x_m"]) - float(from["x_m"]),
			str(layer.get("rock", DrillSim.DEFAULT_ROCK)))
	if not ok:
		return false
	_target = int(to["index"])
	target_node = id
	if not reserve:
		add(sim, "cells", -1)
	sim.emit("travel", {"from": from["id"], "to": id, "reserve": reserve})
	return true


## Called by the drill when a segment ends in run mode. The node becomes current and visited, then
## goes to the module for its type (or, if overtaken, the pursuer strikes instead).
func arrive(sim: Sim) -> void:
	if _target < 0:
		set_phase(sim, "idle")  # A segment begun directly (tests): no node to arrive at.
		return
	_current = _target
	_target = -1
	target_node = ""
	var n: Dictionary = nodes[_current]
	current_node = str(n["id"])
	visited[_current] = 1
	depth_m = float(layer.get("row_depth_m", 36.0)) * float(int(n["row"]))
	scanner_rows = _scanner(sim)
	var kind: String = str(n["type"])
	sim.emit("arrived", {"node": current_node, "type": kind, "row": int(n["row"])})
	if overtaken[_current] == 1:
		sim.emit("node_lost", {"node": current_node, "type": kind})
		_strike(sim, "overtaken")
		set_phase(sim, "idle")
		return
	match kind:
		"event", "cavern", "hazard", "store":
			sim.encounter.start_node(sim, kind, int(n["row"]))
		"fight":
			sim.combat.start_fight(sim, str(n["enemy"]), false)
		"gate":
			sim.combat.start_fight(sim, str(n["enemy"]), true)
	if phase == "drill":
		set_phase(sim, "idle")  # No module took the node.


# Stepping ----------------------------------------------------------------------------------------

func step(sim: Sim) -> void:
	if mode != "run" or is_over():
		return
	if get_res("hull") <= 0:
		end_run(sim, "dead", "hull")
		return
	var alive: int = 0
	var last_cause: String = ""
	for c: CrewMember in sim.ship.crew:
		if c.alive:
			alive += 1
		else:
			last_cause = c.cause_of_death
	if alive == 0:
		end_run(sim, "dead", "crew_" + last_cause)
		return
	var di: int = sim.ship.room_with_system("drill")
	if di >= 0 and sim.ship.rooms[di].flooded_s >= FLOOD_LIMIT_S:
		end_run(sim, "dead", "flooded")
		return
	if nodes.is_empty():
		return
	var noise: float = sim.drill.noise_total
	var new_noise: float = noise - _last_noise
	_last_noise = noise
	if not world_running():
		return
	scanner_rows = _scanner(sim)
	pursuer_row += _rate_per_tick + _rows_per_noise * new_noise
	_cap_pursuer(sim)
	_sweep_overtaken(sim)
	_check_caught(sim)
	if phase == "idle":
		sim.ship.rock_temp_c = float(layer.get("rock_temp_base_c", 40.0)) + float(layer.get("rock_temp_c_per_m", 0.0)) * depth_m


func _scanner(sim: Sim) -> int:
	var helm: int = sim.ship.room_with_system("helm")
	var bars: int = sim.ship.rooms[helm].effective_bars() if helm >= 0 else 0
	return int(layer.get("scanner_base_rows", 1)) + bars + reveal_bonus


func _cap_pursuer(sim: Sim) -> void:
	pursuer_row = minf(pursuer_row, ship_row_f(sim) + 1.0 - _cap_gap)


func _sweep_overtaken(sim: Sim) -> void:
	var front: int = mini(floori(pursuer_row), map.size() - 1)
	while _overtaken_row < front:
		_overtaken_row += 1
		if _overtaken_row < 0:
			continue
		for n: Dictionary in (map[_overtaken_row] as Array):
			var i: int = int(n["index"])
			if visited[i] == 0 and overtaken[i] == 0:
				overtaken[i] = 1
				sim.emit("overtaken", {"node": n["id"]})


func _check_caught(sim: Sim) -> void:
	var now: bool = pursuer_row >= ship_row_f(sim)
	if now != caught:
		caught = now
		_strike_ticks = _strike_every
		sim.emit("pursuer_caught" if now else "pursuer_escaped", {"row": snappedf(pursuer_row, 0.01)})
	if not caught:
		return
	_strike_ticks -= 1
	if _strike_ticks <= 0:
		_strike_ticks = _strike_every
		_strike(sim, "caught")


## The pursuer hits the ship: hull, a breach in a random room, sometimes a fire. Two draws from the
## "pursuer" stream every time, so the sequence never depends on the outcome.
func _strike(sim: Sim, why: String) -> void:
	var rng: RandomNumberGenerator = sim.rng.get_stream("pursuer")
	var rooms: Array[Room] = sim.ship.rooms
	var r: Room = rooms[rng.randi_range(0, rooms.size() - 1)]
	var fire: bool = rng.randf() < _strike_fire_chance
	strikes += 1
	var lost: int = add(sim, "hull", -_strike_hull)
	r.breach_m2 += _strike_breach
	sim.emit("pursuer_strike", {"why": why, "room": r.id, "hull": lost, "fire": fire})
	sim.emit("breach", {"room": r.id})
	if fire:
		sim.hazards.ignite(sim, sim.player, r, _strike_fire_level)


# Summary and state -------------------------------------------------------------------------------

## The run's results for the death screen, balance reports and Profile.merge_run (result, cause,
## depth_m). gained and spent sum the positive and negative resource events per resource.
func summary(sim: Sim) -> Dictionary:
	var gained: Dictionary = {}
	var spent: Dictionary = {}
	for r: String in RESOURCES:
		gained[r] = 0
		spent[r] = 0
	var fights_won: int = 0
	for e: Dictionary in sim.events:
		var kind: String = str(e["kind"])
		if kind == "resource":
			var res: String = str(e["res"])
			var amt: int = int(e["amount"])
			if amt > 0:
				gained[res] = int(gained[res]) + amt
			else:
				spent[res] = int(spent[res]) - amt
		elif kind == "fight_won":
			fights_won += 1
	var crew_lost: int = 0
	for c: CrewMember in sim.ship.crew:
		if not c.alive:
			crew_lost += 1
	var n_visited: int = 0
	var n_overtaken: int = 0
	for i: int in range(nodes.size()):
		n_visited += visited[i]
		n_overtaken += overtaken[i]
	return {
		"result": phase if is_over() else "unfinished",
		"cause": end_cause,
		"depth_m": snappedf(depth_m, 0.1),
		"rows_reached": current_row(),
		"rows_total": map.size(),
		"time_s": snappedf(sim.seconds(), 0.1),
		"gained": gained,
		"spent": spent,
		"fights_won": fights_won,
		"codex": Array(learned),
		"crew_lost": crew_lost,
		"nodes_visited": n_visited,
		"nodes_overtaken": n_overtaken,
		"strikes": strikes,
		"seed": sim.run_seed,
		"ship": sim.ship_id,
		"layer": layer_id,
	}


func state() -> Array:
	var res: Array = []
	for r: String in RESOURCES:
		res.append(int(resources[r]))
	return [mode, phase, res, depth_m, Array(known_codex), Array(learned), end_cause, pursuer_row, reveal_bonus,
		layer_id, _map_state, _current, _target, visited, overtaken, scanner_rows, caught, strikes,
		_last_noise, _overtaken_row, _strike_ticks]


## Checks the layer tables and the run tuning (run_lint.gd).
static func lint(db: DataDB, errs: PackedStringArray) -> void:
	RunLint.lint(db, errs)
