class_name DrillMiner
extends RefCounted
## The away miner (D046), owned by a DrillSim (DrillSim.miner). One crew member leaves the parked
## drill, digs a one-cell tunnel by hand to a point in the rock, mines out the vein there and carries
## the haul home. Holds its tuning and state, never the DrillSim or the Sim: both are passed in, so
## nothing here forms a cycle. The tunnel, vein and walk home are stepped by MinerDig (static).
##
## Commands (through DrillSim): {"type": "send_miner", "crew", "x_m", "y_m"} and {"type": "recall_miner"}.
## Phases, all on the fixed tick:
## - board: the crew member walks to the drill room (crew job "sortie"); the drill keeps going. If the
##   segment ends first (or the target is no longer rock beside the ship when they get there, or a
##   recall comes), the sortie is called off ("miner_back" with an empty haul and "called_off").
## - exit: the drill parks (DrillSim.parked), the crew member is away; hatch_s later they stand at the
##   exit point (the drill head: ship bottom centre). The route is planned here: a 4-connected line of
##   cells from the cell under the head to the target cell (when the target is level with the hull,
##   along the row under the ship first, then up beside it), so the tunnel is walkable.
## - dig: one cell at a time: air costs cell_m / walk_m_s, solid rock dig_base_s + dig_hard_s *
##   hardness (the material's own hardness: hands, not the drill head). Solid cells are cut through
##   DrillSim.cut with CUT_MINER, the drill's own cutting path: mined counts, chunk changes,
##   structures and crates stay consistent; only the routing differs (book, on_cut).
## - vein: when the target cell held ore or gems, the connected ore and gem cells around it are dug
##   breadth first (neighbours queued in cell index order), up to vein_max_cells, each next to a cell
##   already dug. The short walk inside the vein is folded into each cell's dig time.
## - return: back along the dug cells (parent links) at walk speed; enter: hatch_s to climb in.
##   Aboard: the haul is paid into the run with run.add ("resource" events), "miner_back", the drill
##   unparks.
## Harm (hp clamps at 0; at 0 the miner dies where they are, the haul is lost, "miner_lost", the drill
## unparks): a water pocket cell drains the whole connected pocket into the tunnel (water_hp, nothing
## enters the ship), a gas pocket cell burns it off (gas_hp, no fire aboard), every fault cell adds 1 to
## the miner's own strain (at strain_cells a rockfall lands rockfall_warn_s later for rockfall_hp), a
## pursuer strike while out (strike_hp). Yield: yield_pct of each cell's yield, rounded down per cell,
## goes into haul (by RunState.RESOURCES index); a crate the miner opens pays into haul too.
## A fight starting while the miner is out pulls them aboard at once (haul paid).
##
## Events: "miner_out" {"crew", "x_m", "y_m"} (the target, as they climb out), "miner_hurt" {"crew",
## "cause", "hp" (damage), "left"}, "miner_rockfall_warn" {"in_s"}, "miner_back" {"crew", "haul": {res:
## n}}, "miner_lost" {"crew", "cause", "haul"} (and "crew_died"), "bad_command" {"type", "why"}.

const TUNING_KEYS: Array[String] = [
	"miner.range_m", "miner.walk_m_s", "miner.hatch_s", "miner.dig_base_s", "miner.dig_hard_s",
	"miner.yield_pct", "miner.vein_max_cells", "miner.noise_per_cell", "miner.water_hp", "miner.gas_hp",
	"miner.strain_cells", "miner.rockfall_warn_s", "miner.rockfall_hp", "miner.strike_hp",
]
const CUT_DRILL: int = 0
const CUT_MINER: int = 1

# Read-only for the view and the bots.
var active: bool = false  ## A sortie is under way (from send to back aboard or lost).
var crew_id: String = ""
var phase: String = ""  ## "board", "exit", "dig", "vein", "return", "enter" ("" when not active).
var pos: Vector2 = Vector2.ZERO  ## The miner's feet, segment meters (meaningful from "exit" on).
var target: Vector2 = Vector2.ZERO  ## Segment meters.
var haul: PackedInt32Array = PackedInt32Array()  ## Carried, by RunState.RESOURCES index.
var cells_dug: int = 0  ## Cells this sortie turned to air (pocket cells drained or burned included).
var strain: int = 0  ## Fault cells dug toward the next rockfall on the miner.
var rockfall_ticks: int = 0  ## Ticks until a rockfall lands on the miner (0: none coming).
var range_m: float = 12.0
var next_cell: int = -1  ## The cell being walked into or dug (-1: none).
var action_ticks: int = 0  ## Ticks left on the current hatch, walk or dig.
var action_total: int = 0  ## Ticks the current hatch, walk or dig takes in all.
var sorties: int = 0  ## Miners that went out this run.

var _crew: int = -1
var _route: PackedInt32Array = PackedInt32Array()  ## Planned tunnel, cell under the head to the target cell.
var _route_i: int = 0
var _cells: PackedInt32Array = PackedInt32Array()  ## Cells entered, in order.
var _par: PackedInt32Array = PackedInt32Array()  ## Index into _cells of each entered cell's parent (-1: the hatch).
var _at: int = -1  ## Index into _cells of the cell the miner stands in (-1: at the hatch).
var _step_par: int = -1  ## Parent of next_cell.
var _vq: PackedInt32Array = PackedInt32Array()  ## Vein queue: candidate cells.
var _vq_par: PackedInt32Array = PackedInt32Array()  ## Their parents (index into _cells).
var _vq_i: int = 0
var _vein_n: int = 0
var _vein_ok: bool = false  ## The target cell held ore or gems.
var _seen: PackedByteArray = PackedByteArray()  ## Vein cells already queued (scratch, per sortie).
# Tuning, read once.
var _walk: float = 1.4
var _hatch_ticks: int = 120
var _dig_base: float = 0.25
var _dig_hard: float = 0.9
var _yield_pct: int = 100
var _vein_max: int = 30
var _noise: float = 0.0
var _water_hp: float = 20.0
var _gas_hp: float = 45.0
var _strain_max: int = 12
var _warn_ticks: int = 72
var _rockfall_hp: float = 35.0
var _strike_hp: float = 30.0


func _init(db: DataDB) -> void:
	range_m = db.tune("miner.range_m")
	_walk = maxf(0.01, db.tune("miner.walk_m_s"))
	_hatch_ticks = maxi(1, roundi(db.tune("miner.hatch_s") * Sim.TICK_HZ))
	_dig_base = maxf(0.0, db.tune("miner.dig_base_s"))
	_dig_hard = maxf(0.0, db.tune("miner.dig_hard_s"))
	_yield_pct = clampi(roundi(db.tune("miner.yield_pct")), 0, 100)
	_vein_max = maxi(0, roundi(db.tune("miner.vein_max_cells")))
	_noise = maxf(0.0, db.tune("miner.noise_per_cell"))
	_water_hp = maxf(0.0, db.tune("miner.water_hp"))
	_gas_hp = maxf(0.0, db.tune("miner.gas_hp"))
	_strain_max = maxi(1, roundi(db.tune("miner.strain_cells")))
	_warn_ticks = maxi(1, roundi(db.tune("miner.rockfall_warn_s") * Sim.TICK_HZ))
	_rockfall_hp = maxf(0.0, db.tune("miner.rockfall_hp"))
	_strike_hp = maxf(0.0, db.tune("miner.strike_hp"))
	haul.resize(RunState.RESOURCES.size())


## Out of the ship (climbing out, digging, walking home or climbing in): the drill is parked.
func is_out() -> bool:
	return active and phase != "board"


# Aiming ------------------------------------------------------------------------------------------

## "" when crew_id may be sent to point (segment meters) now, else why not: "no_segment", "miner_out",
## "no_crew", "outside" or "range" (MinerRoute.why_not has the details). The view calls it for its aim
## circle, like DrillVerbs.aim_ok.
static func target_ok(d: DrillSim, sim: Sim, p_crew_id: String, point: Vector2) -> String:
	return MinerRoute.why_not(d, sim, p_crew_id, point)


## The drill head: the ship's bottom centre, segment meters (where the miner climbs out).
static func head(d: DrillSim) -> Vector2:
	return MinerRoute.head(d)


# Commands ----------------------------------------------------------------------------------------

func send(sim: Sim, d: DrillSim, p_crew_id: String, point: Vector2) -> bool:
	var why: String = target_ok(d, sim, p_crew_id, point)
	if not why.is_empty():
		sim.emit("bad_command", {"type": "send_miner", "why": why})
		return false
	var c: CrewMember = sim.ship.crew_by_id(p_crew_id)
	_reset()
	active = true
	crew_id = p_crew_id
	_crew = c.index
	target = point
	c.job_kind = "sortie"
	c.job_room = d.drill_room
	c.path = sim.ship.nav.route(sim.ship, c.room, d.drill_room, sim.ship.rooms[d.drill_room].center_floor().x)
	c.path_i = 0
	_set_phase(d, "board")
	return true


func recall(sim: Sim, d: DrillSim) -> void:
	if not active:
		sim.emit("bad_command", {"type": "recall_miner", "why": "no_miner"})
		return
	match phase:
		"board":
			_call_off(sim, d)
		"exit":
			MinerDig.start_enter(self, d, maxi(1, _hatch_ticks - action_ticks))
		"dig", "vein":
			MinerDig.turn_back(self, d)


## The segment is ending: a miner still boarding stays aboard.
func end_segment(sim: Sim, d: DrillSim) -> void:
	if active and phase == "board":
		_call_off(sim, d)


## A pursuer strike: it hits a miner who is out.
func strike(sim: Sim, d: DrillSim) -> void:
	if is_out():
		hurt(sim, d, _strike_hp, "miner_strike")


# Stepping ----------------------------------------------------------------------------------------

## Every tick, any phase: a fight pulls a miner aboard at once (none can start mid-segment today; an
## event or a structure's break-in could queue one).
func watch(sim: Sim, d: DrillSim) -> void:
	if active and sim.run.phase == "combat":
		if phase == "board":
			_call_off(sim, d)
		else:
			_aboard(sim, d)


## Every drilling tick (the segment active, run phase "drill").
func step(sim: Sim, d: DrillSim) -> void:
	if not active:
		return
	var c: CrewMember = sim.ship.crew[_crew]
	if not c.alive:  # Killed by something else (an event).
		if is_out():
			_die(sim, d, c.cause_of_death)
		else:
			_end(d)
		return
	if phase == "board":
		if c.room == d.drill_room and c.path_i >= c.path.size() and not c.climbing:
			_start_exit(sim, d, c)
		return
	if rockfall_ticks > 0:
		rockfall_ticks -= 1
		if rockfall_ticks == 0:
			hurt(sim, d, _rockfall_hp, "miner_rockfall")
			if not active:
				return
			_check_strain(sim)
	action_ticks -= 1
	if action_ticks > 0:
		return
	match phase:
		"exit":
			MinerDig.plan(self, d)
			MinerDig.next_dig(self, d)
		"dig":
			MinerDig.finish_step(sim, self, d)
			if active:
				MinerDig.next_dig(self, d)
		"vein":
			MinerDig.finish_step(sim, self, d)
			if active:
				MinerDig.next_vein(self, d)
		"return":
			_at = _par[_at]
			pos = MinerDig.feet(d, _cells[_at]) if _at >= 0 else MinerRoute.hatch(d, target)
			MinerDig.next_back(self, d)
		"enter":
			_aboard(sim, d)


func _start_exit(sim: Sim, d: DrillSim, c: CrewMember) -> void:
	c.away = true
	c.path = PackedVector2Array()
	c.path_i = 0
	pos = MinerRoute.hatch(d, target)
	if not MinerRoute.geometry_ok(d, target):  # The drill moved on while they boarded: the target is cut or behind.
		_call_off(sim, d)
		return
	sorties += 1
	_set_phase(d, "exit")
	_set_action(_hatch_ticks)
	sim.emit("miner_out", {"crew": crew_id, "x_m": snappedf(target.x, 0.01), "y_m": snappedf(target.y, 0.01)})


# Cut routing (from DrillSim) ---------------------------------------------------------------------

## A cell the miner cut (DrillSim.take_cell with CUT_MINER): count it and carry its yield.
func book(d: DrillSim, m: int) -> void:
	cells_dug += 1
	var ri: int = d.yield_res_of[m]
	if ri >= 0:
		haul[ri] += d.yield_amount_of[m] * _yield_pct / 100


## What a miner's cut does beyond the cell itself (DrillSim.cut, after take_cell): pockets, strain,
## noise.
func on_cut(sim: Sim, d: DrillSim, i: int, m: int) -> void:
	d.noise_segment += _noise
	d.noise_total += _noise
	if d.water_of[m] == 1 or d.gas_of[m] == 1:
		var water: bool = d.water_of[m] == 1
		d.burst_marks[i] = 1
		for j: int in DrillMaterials.flood_cells(d.grid, d.cols, d.rows, i, d.water_of if water else d.gas_of):
			if j != i:
				d.burst_marks[j] = 1
				d.take_cell(j, CUT_MINER)
		if water:
			hurt(sim, d, _water_hp, "miner_water")
		else:
			hurt(sim, d, _gas_hp, "miner_gas")
	elif d.unstable_of[m] == 1:
		strain += 1
		_check_strain(sim)


func _check_strain(sim: Sim) -> void:
	if rockfall_ticks == 0 and strain >= _strain_max:
		strain -= _strain_max
		rockfall_ticks = _warn_ticks
		sim.emit("miner_rockfall_warn", {"in_s": snappedf(float(_warn_ticks) / Sim.TICK_HZ, 0.01)})


# Harm, return and loss ---------------------------------------------------------------------------

## The miner loses hp (clamped at 0); at 0 they die where they are.
func hurt(sim: Sim, d: DrillSim, amount: float, cause: String) -> void:
	if not is_out() or amount <= 0.0:
		return
	var c: CrewMember = sim.ship.crew[_crew]
	c.hp = maxf(0.0, c.hp - amount)
	sim.emit("miner_hurt", {"crew": crew_id, "cause": cause, "hp": amount, "left": snappedf(c.hp, 0.01)})
	if c.hp <= 0.0:
		_die(sim, d, cause)


func _die(sim: Sim, d: DrillSim, cause: String) -> void:
	var c: CrewMember = sim.ship.crew[_crew]
	var lost: Dictionary = _haul_dict()
	if c.alive:
		c.hp = 0.0
		c.alive = false
		c.cause_of_death = cause
		c.path = PackedVector2Array()
		sim.emit("crew_died", {"crew": c.id, "cause": cause})
	sim.emit("miner_lost", {"crew": crew_id, "cause": cause, "haul": lost})
	_end(d)


func _aboard(sim: Sim, d: DrillSim) -> void:
	var c: CrewMember = sim.ship.crew[_crew]
	c.away = false
	if d.drill_room >= 0:
		c.room = d.drill_room
		c.pos = sim.ship.rooms[d.drill_room].center_floor()
	c.job_kind = ""
	c.job_room = -1
	c.path = PackedVector2Array()
	c.path_i = 0
	var paid: Dictionary = {}
	for ri: int in range(haul.size()):
		if haul[ri] > 0:
			paid[RunState.RESOURCES[ri]] = sim.run.add(sim, RunState.RESOURCES[ri], haul[ri])
	sim.emit("miner_back", {"crew": crew_id, "haul": paid})
	_end(d)


## Called off before they left the ship: back to their own judgement, nothing carried.
func _call_off(sim: Sim, d: DrillSim) -> void:
	var c: CrewMember = sim.ship.crew[_crew]
	c.away = false
	c.job_kind = ""
	c.job_room = -1
	c.path = PackedVector2Array()
	c.path_i = 0
	sim.emit("miner_back", {"crew": crew_id, "haul": {}, "called_off": true})
	_end(d)


func _end(d: DrillSim) -> void:
	active = false
	haul.fill(0)
	rockfall_ticks = 0
	next_cell = -1
	action_ticks = 0
	action_total = 0
	_set_phase(d, "")


func _reset() -> void:
	haul.fill(0)
	cells_dug = 0
	strain = 0
	rockfall_ticks = 0
	next_cell = -1
	action_ticks = 0
	action_total = 0
	_route = PackedInt32Array()
	_route_i = 0
	_cells = PackedInt32Array()
	_par = PackedInt32Array()
	_at = -1
	_step_par = -1
	_vq = PackedInt32Array()
	_vq_par = PackedInt32Array()
	_vq_i = 0
	_vein_n = 0
	_vein_ok = false
	_seen = PackedByteArray()


func _set_phase(d: DrillSim, p: String) -> void:
	phase = p
	d.parked = is_out()


func _set_action(ticks: int) -> void:
	action_ticks = ticks
	action_total = ticks


func _haul_dict() -> Dictionary:
	var out: Dictionary = {}
	for ri: int in range(haul.size()):
		if haul[ri] > 0:
			out[RunState.RESOURCES[ri]] = haul[ri]
	return out


func state() -> Array:
	return [active, crew_id, _crew, phase, pos, target, haul, cells_dug, strain, rockfall_ticks, next_cell,
		action_ticks, action_total, sorties, _route, _route_i, _cells, _par, _at, _step_par, _vq, _vq_par, _vq_i,
		_vein_n, _vein_ok]
