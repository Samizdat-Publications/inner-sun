class_name DrillStructures
extends RefCounted
## The buried structure of the current segment (at most one), owned by a DrillSim (DrillSim.structures).
## Holds its state, never the DrillSim or the Sim: both are passed in, so nothing here forms a cycle.
##
## - Placement: when the segment's survey names a structure, StructureStamp writes it into the rock
##   (drawn from the segment stream "drill/<segment>" after the features) and DrillSim.structure_marks
##   marks its cells (2 = interior: the old air and the crates in it, 1 = the rest of the stamp).
## - Crates: the first cut cell of a crate (a "loot" material; by the footprint or a blast) opens the
##   whole connected crate (flood-and-mark in DrillSim.burst_marks, like a pocket) and pays ONE roll of
##   the structure's loot table (or its "loot_by_material" table for that material) from the stream
##   "drill/<segment>/loot", through run.add: exact integers. A crate the away miner opens pays the
##   same roll into the miner's haul instead (DrillMiner.haul; lost if the miner is already lost).
## - Break-in: the first cut of an interior cell (the footprint overlapping the interior, or a blast)
##   enters the structure once: "structure_entered", its codex entry learned (run.learn), then one
##   roll pair from "drill/<segment>/structure": a trader (trader_chance, when the structure names a
##   store) opens that store mid-segment; else an event (event_chance) of kind "structure" listing
##   this structure starts mid-segment; else nothing more. The drill stays active; Encounter returns
##   the run to "drill" when the store is left or the event ends.
## Cuts only note what happened (note, from DrillSim.take_cell); resolve() pays and emits once per
## drilling tick, after the drill moved and any blast went off.
##
## Events: "structure_placed" {"structure", "x_m", "y_m", "w_m", "h_m", "mirror"},
## "structure_entered" {"structure", "label"}, "loot" {"structure", "res", "amount", "x_m", "y_m", "miner"},
## "structure_outcome" {"structure", "outcome": "trader" | "event" | "none", "id": store or event id}.

# Read-only for the view and the bots.
var id: String = ""  ## The placed structure's id ("" when the segment has none).
var label: String = ""  ## Map and banner text.
var def: Dictionary = {}  ## Its data (game/data/structures/<id>.json).
var rect: Rect2 = Rect2()  ## The stamp's rectangle, segment meters.
var interior: Rect2 = Rect2()  ## The bounding box of its interior cells, segment meters.
var cell_rect: Rect2i = Rect2i()  ## The stamp's rectangle in cells.
var mirrored: bool = false
var entered: bool = false  ## Broken into this segment.
var crates_total: int = 0  ## Separate crates in the stamp.
var crates_opened: int = 0
var outcome: String = ""  ## After the break-in: "trader", "event" or "none".
var outcome_id: String = ""  ## The store or event it opened.
var loot_res: PackedInt32Array = PackedInt32Array()  ## Paid by crates this segment, by RunState.RESOURCES index.

var _enter_pending: bool = false
var _pend_cells: PackedInt32Array = PackedInt32Array()  ## First cut cell of each crate opened since resolve().
var _pend_codes: PackedInt32Array = PackedInt32Array()
var _pend_miner: PackedByteArray = PackedByteArray()  ## 1 when the away miner opened that crate.


func _init() -> void:
	loot_res.resize(RunState.RESOURCES.size())


func has_structure() -> bool:
	return not id.is_empty()


## Place the segment's structure (or none). Called by DrillSim.begin_segment right after RockGen.
func begin_segment(sim: Sim, d: DrillSim, p_def: Dictionary, codes: Dictionary, rng: RandomNumberGenerator,
		start: Rect2, tune: Dictionary) -> void:
	id = ""
	label = ""
	def = {}
	rect = Rect2()
	interior = Rect2()
	cell_rect = Rect2i()
	mirrored = false
	entered = false
	crates_total = 0
	crates_opened = 0
	outcome = ""
	outcome_id = ""
	loot_res.fill(0)
	_enter_pending = false
	_pend_cells = PackedInt32Array()
	_pend_codes = PackedInt32Array()
	_pend_miner = PackedByteArray()
	if p_def.is_empty():
		return
	var at: Dictionary = StructureStamp.place(p_def, codes, rng, d.grid, d.structure_marks, d.cols, d.rows, d.cell_m,
			start, d.target_x, d.depth_m, sim.run.depth_m, tune, d.interior_of, d.loot_of)
	if at.is_empty():
		return
	def = p_def
	id = str(p_def.get("id", ""))
	label = str(p_def.get("label", ""))
	mirrored = bool(at["mirror"])
	cell_rect = Rect2i(int(at["c0"]), int(at["r0"]), int(at["w"]), int(at["h"]))
	rect = Rect2(Vector2(cell_rect.position) * d.cell_m, Vector2(cell_rect.size) * d.cell_m)
	_measure(d)
	sim.emit("structure_placed", {"structure": id, "x_m": rect.position.x, "y_m": rect.position.y,
			"w_m": rect.size.x, "h_m": rect.size.y, "mirror": mirrored})


## Interior bounding box and the number of separate crates (a scratch mark array: once per segment).
func _measure(d: DrillSim) -> void:
	var lo := Vector2i(cell_rect.end)
	var hi := Vector2i(cell_rect.position) - Vector2i.ONE
	var seen := PackedByteArray()
	seen.resize(d.grid.size())
	for r: int in range(cell_rect.position.y, cell_rect.end.y):
		for c: int in range(cell_rect.position.x, cell_rect.end.x):
			var i: int = r * d.cols + c
			if d.structure_marks[i] != StructureStamp.MARK_INTERIOR:
				continue
			lo = Vector2i(mini(lo.x, c), mini(lo.y, r))
			hi = Vector2i(maxi(hi.x, c), maxi(hi.y, r))
			if d.loot_of[d.grid[i]] == 1 and seen[i] == 0:
				DrillMaterials.flood(d.grid, d.cols, d.rows, i, d.loot_of, seen)
				crates_total += 1
	if hi.x >= lo.x:
		interior = Rect2(Vector2(lo) * d.cell_m, Vector2(hi - lo + Vector2i.ONE) * d.cell_m)


## A structure interior cell (structure_marks 2) is being cut; m is its material code; by_miner when
## the away miner cut it. Called by DrillSim.take_cell before the cell turns to air.
func note(d: DrillSim, i: int, m: int, by_miner: bool = false) -> void:
	if not entered:
		_enter_pending = true
	if d.loot_of[m] == 1 and d.burst_marks[i] == 0:
		DrillMaterials.flood(d.grid, d.cols, d.rows, i, d.loot_of, d.burst_marks)
		_pend_cells.append(i)
		_pend_codes.append(m)
		_pend_miner.append(1 if by_miner else 0)


## Pay the crates opened since the last call and handle a new break-in. allow_encounter false (at
## arrival, or when the run is over) enters and pays but opens no store or event.
func resolve(sim: Sim, d: DrillSim, allow_encounter: bool) -> void:
	if not _enter_pending and _pend_cells.is_empty():
		return
	var broke_in: bool = false
	if _enter_pending and not entered:
		entered = true
		broke_in = true
		sim.emit("structure_entered", {"structure": id, "label": label})
		var codex: String = str(def.get("codex", ""))
		if not codex.is_empty():
			sim.run.learn(sim, codex)
	_enter_pending = false
	if not _pend_cells.is_empty():
		var rng: RandomNumberGenerator = sim.rng.get_stream("drill/%s/loot" % d.segment_id)
		for k: int in range(_pend_cells.size()):
			_pay_crate(sim, d, rng, _pend_cells[k], _pend_codes[k], _pend_miner[k] == 1)
		_pend_cells = PackedInt32Array()
		_pend_codes = PackedInt32Array()
		_pend_miner = PackedByteArray()
	if broke_in and allow_encounter:
		_break_in(sim, d)


func _pay_crate(sim: Sim, d: DrillSim, rng: RandomNumberGenerator, cell: int, code: int, by_miner: bool) -> void:
	crates_opened += 1
	var table: Array = def.get("loot", [])
	var by_mat: Dictionary = def.get("loot_by_material", {})
	var mid: String = str(d.materials[code].get("id", ""))
	if by_mat.has(mid):
		table = by_mat[mid] as Array
	var row: Dictionary = roll(table, rng.randf())
	var x: float = snappedf((float(cell % d.cols) + 0.5) * d.cell_m, 0.01)
	var y: float = snappedf((float(cell / d.cols) + 0.5) * d.cell_m, 0.01)
	var res: String = str(row.get("res", ""))
	var got: int = 0
	if RunState.RESOURCES.has(res):
		var ri: int = RunState.RESOURCES.find(res)
		if not by_miner:
			got = sim.run.add(sim, res, int(row.get("amount", 0)))
			loot_res[ri] += got
		elif d.miner.active:
			got = maxi(0, int(row.get("amount", 0)))
			d.miner.haul[ri] += got
	sim.emit("loot", {"structure": id, "res": res, "amount": got, "x_m": x, "y_m": y, "miner": by_miner})


## The row of a weighted loot table that u (0..1) lands on ({} for an empty table).
static func roll(table: Array, u: float) -> Dictionary:
	var total: float = 0.0
	for t: Variant in table:
		total += maxf(0.0, float((t as Dictionary).get("weight", 0.0)))
	if total <= 0.0:
		return {}
	var left: float = u * total
	for t: Variant in table:
		left -= maxf(0.0, float((t as Dictionary).get("weight", 0.0)))
		if left < 0.0:
			return t as Dictionary
	return table[table.size() - 1] as Dictionary


func _break_in(sim: Sim, d: DrillSim) -> void:
	var rng: RandomNumberGenerator = sim.rng.get_stream("drill/%s/structure" % d.segment_id)
	var u_trader: float = rng.randf()
	var u_event: float = rng.randf()
	var trader: String = str(def.get("trader", ""))
	outcome = "none"
	outcome_id = ""
	if sim.encounter.is_busy():
		pass
	elif not trader.is_empty() and u_trader < float(def.get("trader_chance", 0.0)):
		outcome = "trader"
		outcome_id = trader
	elif u_event < float(def.get("event_chance", 0.0)):
		outcome_id = sim.encounter.pick_structure_event(sim, id, rng)
		if not outcome_id.is_empty():
			outcome = "event"
	sim.emit("structure_outcome", {"structure": id, "outcome": outcome, "id": outcome_id})
	if outcome == "trader":
		sim.encounter.open_store(sim, outcome_id)
	elif outcome == "event":
		sim.encounter.start_event(sim, outcome_id)


func state() -> Array:
	return [id, rect, interior, mirrored, entered, crates_total, crates_opened, outcome, outcome_id, loot_res,
		_enter_pending, _pend_cells, _pend_codes, _pend_miner]
