class_name RunState
extends SimModule
## The run around the ship: the phase (what steps each tick), the resources, the depth, what was
## learned, and how the run ended. Resources are integers changed only through add(), so every
## change is an event and balance reports can follow them. In "scenario" mode (tests, captures, the
## M0 drills) the run structure is off and ScenarioRun decides the outcome.
## The node map, travel and the pursuer arrive with M1 step 3 (see docs/plans/M1.md).

const PHASES: Array[String] = ["scenario", "idle", "drill", "dialog", "store", "combat", "dead", "won"]
const WORLD_PHASES: Array[String] = ["scenario", "idle", "drill", "combat"]
const RESOURCES: Array[String] = ["hull", "ore", "gems", "coolant", "cells", "bits", "charges"]
const COMMANDS: Array[String] = []
const FLOOD_LIMIT_S: float = 10.0

var mode: String = "scenario"  ## "scenario" or "run".
var phase: String = "scenario"
var resources: Dictionary = {}
var depth_m: float = 0.0
var known_codex: PackedStringArray = PackedStringArray()  ## What the profile knew at the start (sorted).
var learned: PackedStringArray = PackedStringArray()  ## Codex entries learned this run, in order.
var end_cause: String = ""
var pursuer_row: float = -1.5  ## Map row the pursuer's front has reached (step 3 moves it).
var reveal_bonus: int = 0  ## Extra scanner rows for the rest of the layer (events).


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
	set_phase(sim, "idle")


func get_res(res: String) -> int:
	return int(resources.get(res, 0))


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


func world_running() -> bool:
	return WORLD_PHASES.has(phase)


func is_over() -> bool:
	return phase == "dead" or phase == "won"


## A codex entry is known if the profile knew it or this run learned it.
func knows(codex_id: String) -> bool:
	return known_codex.has(codex_id) or learned.has(codex_id)


func learn(sim: Sim, codex_id: String) -> void:
	if knows(codex_id):
		return
	learned.append(codex_id)
	sim.emit("codex", {"id": codex_id})


## Move the pursuer's front by a number of map rows (positive brings it closer).
func move_pursuer(sim: Sim, rows: float) -> void:
	pursuer_row += rows
	sim.emit("pursuer_moved", {"rows": rows})


## The scanner sees this many more rows ahead for the rest of the layer.
func add_reveal(sim: Sim, rows: int) -> void:
	reveal_bonus += rows
	sim.emit("reveal", {"rows": rows})


func end_run(sim: Sim, p_phase: String, cause: String) -> void:
	if is_over():
		return
	end_cause = cause
	set_phase(sim, p_phase)
	sim.emit("run_over", {"result": p_phase, "cause": cause})


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


func state() -> Array:
	var res: Array = []
	for r: String in RESOURCES:
		res.append(int(resources[r]))
	return [mode, phase, res, depth_m, Array(known_codex), Array(learned), end_cause, pursuer_row, reveal_bonus]


## Checks the run tables (layers, node types, map rules). Filled in with M1 step 3.
static func lint(_db: DataDB, _errs: PackedStringArray) -> void:
	pass
