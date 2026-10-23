class_name DrillSim
extends SimModule
## The drilling segment between map nodes. The sim owns a rock grid (square cells, one material code
## each, generated from a rock table, the segment's survey and the stream "drill/<segment id>"). The
## whole ship footprint moves through it; its bottom edge is the cutting crown. Each tick: turn toward
## the steered heading, read the leading band (cells about to be entered), move, cut every newly
## overlapped cell. Cut cells are counted exactly (mined per material); ore and gems go to run
## resources (one "mined" event per material per footprint step), water pockets pour into the drill
## room, gas pockets set it on fire, cutting heats the drill room, wears the bit and makes noise.
## Arrival is depth only: the ship's bottom edge reaching target_y. Steering is for detours: the
## heading goes to +-max_heading_deg(sim) (90 = "hold depth", cutting straight sideways). That cap and
## the scanner's range grow with the helm's installed bars (Room.sys_max, D060): the tuning tables
## drill.max_heading_deg_by_helm_<bars> and drill.scanner_range_m_by_helm_<bars>, where the highest
## key at or below the installed bars wins (bars 0 must be present; the single max_heading_deg is the
## fallback when the heading table is absent). The steer command is clamped to the cap when it
## applies. The view draws rock only within scanner_range_m(sim) of the drill head. The turn rate is
## turn_deg_s * Systems.steer_rate_scale and the sideways part of the motion is multiplied by
## Systems.side_cut_scale (both helm bars, when manned): per second (v sin h * side, v cos h), with v
## from power, gear, the bit and the leading band (side cells weighted |sin h| * side, bottom cells
## cos h). at_wall: pressed against the segment wall at a heading past at_wall_heading_deg.
## Pocket hazards, fault rock strain and rockfalls (and a rockfall seam's, RunState.rockfall_band),
## and blasts by the charge launcher live in DrillVerbs (verbs); the environment in force adds its
## rock_temp_add_c to the rock heat; the "blast" command goes there. The away miner (D046) lives in DrillMiner
## (miner; "send_miner", "recall_miner"): while one is out the drill is parked (no motion, cutting,
## heat, noise or wear; the segment cannot end) and the miner's cells go through cut() with
## CUT_MINER, so their yield is carried home instead of paid at once. A buried structure named by the survey (old
## mine works, a rig module, a crystal hollow) is stamped into the rock and broken into through
## DrillStructures (structures): crates pay loot, the break-in may open a store or an event
## mid-segment (the run leaves "drill" and comes back to it; arrival waits until it does).
## Gear (RunState.gear_x) scales cut speed, bit wear and the hardness of hard rock, read when the
## segment begins. Segment space: meters, +x right, +y down, like ship space. See ARCHITECTURE.md.
##
## Events: "segment_begin", "mined" {"material", "res", "amount", "x_m", "y_m"} (crown position, or
## the blast point), DrillVerbs' events (pockets, rockfalls, blasts), DrillMiner's, "bit_broken",
## "segment_done" {"segment", "time_s", "distance_m", "mined" (cells by material id), "yield"
## (resource units by material id), "ore", "gems", "noise", "lost_water_ml", "gas_bursts", "rockfalls",
## "blasts", "structure" (id or ""), "entered", "crates"}, and DrillStructures' events (placed,
## entered, loot, outcome).

const COMMANDS: Array[String] = ["steer", "change_bit", "begin_segment", "blast", "send_miner", "recall_miner"]
const CHUNK_CELLS: int = 16  ## The view redraws the rock in chunks of 16 x 16 cells.
const DEFAULT_ROCK: String = "crust"
const MAX_CODES: int = 256
const MAX_POWER_BAR: int = 4  ## Highest bar with its own power factor; more bars use this one.
const EPS: float = 0.000001
const STEEP_DEG: float = 60.0  ## steep_ticks counts drilling ticks at headings past this (balance stats).
const HELM_TABLE_MAX: int = 8  ## Highest helm bar count a by-helm tuning key may name.
const HEADING_TABLE: String = "drill.max_heading_deg_by_helm_"
const RANGE_TABLE: String = "drill.scanner_range_m_by_helm_"
const NO_RANGE_M: float = 1000.0  ## Scanner range when its table is absent: everything shows.
const TUNING_KEYS: Array[String] = [
	"drill.cell_m", "drill.width_m", "drill.top_air_m", "drill.shaft_margin_m", "drill.bottom_margin_m",
	"drill.max_lateral_m", "drill.band_cells", "drill.base_speed_m_s", "drill.max_speed_m_s",
	"drill.air_hardness_floor", "drill.turn_deg_s", "drill.max_heading_deg",
	"drill.power_factor_bar_0", "drill.power_factor_bar_1", "drill.power_factor_bar_2",
	"drill.power_factor_bar_3", "drill.power_factor_bar_4",
	"drill.heat_kw_per_bar", "drill.wear_per_m_hardness", "drill.bit_slow_at_full_wear",
	"drill.broken_bit_factor", "drill.bit_change_s", "drill.noise_per_m", "drill.pocket_breach_m2",
	"drill.rock_temp_base_c", "drill.rock_temp_c_per_m", "drill.gas_fire_level", "drill.gas_noise",
	"drill.hard_rock_min_hardness", "drill.at_wall_heading_deg", "drill.rockfall_strain_cells",
	"drill.rockfall_warn_s", "drill.rockfall_hull_pts", "drill.rockfall_sys_bars", "drill.blast_cooldown_s",
	"drill.blast_range_m", "drill.blast_fuse_s", "drill.blast_radius_m", "drill.blast_fire_m", "drill.blast_noise",
	"drill.blast_yield_pct", "drill.structure_at_min_frac", "drill.structure_at_max_frac", "drill.structure_offset_min_m",
	"drill.structure_offset_max_m", HEADING_TABLE + "0", RANGE_TABLE + "0",
]

# Read by the view (never written outside this class and DrillMaterials).
var active: bool = false
var segment_id: String = ""
var rock_id: String = ""
var survey: Dictionary = {}  ## The options this segment was generated with (RockGen.options_of).
var grid: PackedByteArray = PackedByteArray()  ## Material code per cell, row-major (cols x rows).
var grid_serial: int = 0  ## Bumped by every begin_segment: the view rebuilds everything.
var cols: int = 0
var rows: int = 0
var cell_m: float = 0.5
var ship_size: Vector2 = Vector2.ZERO
var ship_pos: Vector2 = Vector2.ZERO  ## Top-left of the ship footprint, segment meters.
var heading_deg: float = 0.0  ## 0 = straight down, positive = toward +x.
var target_heading_deg: float = 0.0
var side_scale: float = 1.0  ## Systems.side_cut_scale this tick: the share of the sideways motion kept.
var at_wall: bool = false  ## Pressed against the segment wall at a heading past at_wall_heading_deg.
var steep_ticks: int = 0  ## Whole run: drilling ticks with |heading| past STEEP_DEG.
var speed_m_s: float = 0.0
var speed_scale: float = 1.0  ## Set by the run per segment (reserve power: below 1). Multiplies the speed.
var bit_wear: float = 0.0  ## 0 (new) to 1 (broken).
var bit_broken: bool = false
var bit_change_left_s: float = 0.0
var cutting: bool = false
var start_center_x: float = 0.0
var start_y: float = 0.0  ## Ship top at the start.
var target_x: float = 0.0  ## Where the next node sits (centre x at target_y): a hint, not a condition.
var target_y: float = 0.0  ## Arrival when the ship's bottom edge reaches this.
var depth_m: float = 0.0
var start_depth_m: float = 0.0
var distance_m: float = 0.0
var segment_ticks: int = 0
var noise_segment: float = 0.0
var noise_total: float = 0.0  ## Whole run; the pursuer reads it.
var mined: PackedInt32Array = PackedInt32Array()  ## Cells cut this segment, by material code.
var generated: PackedInt32Array = PackedInt32Array()  ## Cells at generation, by material code.
var yielded: PackedInt32Array = PackedInt32Array()  ## Given to run resources this segment, by RunState.RESOURCES index.
var yield_mat: PackedInt32Array = PackedInt32Array()  ## Given to run resources this segment, by material code.
var water_in_ml: int = 0  ## Pocket water that went into the drill room this segment.
var lost_water_ml: int = 0  ## Pocket water that did not fit (lost to the rock).
var water_cell_ml: int = 0
var heat_added_j: int = 0
var pockets_burst: int = 0
var verbs: DrillVerbs  ## Pockets, fault rock and rockfalls, blasts (read its fields for the view).
var miner: DrillMiner  ## The away miner (read its fields for the view).
var parked: bool = false  ## A miner is out: the drill stands still (set by DrillMiner).
var gas_bursts: int = 0
var chunk_cols: int = 0
var chunk_rows: int = 0
var chunk_changes: PackedInt32Array = PackedInt32Array()  ## +1 whenever a cell in that chunk changes.
var materials: Array[Dictionary] = []  ## By code: {"id", "name", "hardness", "color", "res", "amount"} or {}.
var hardness_of: PackedFloat64Array = PackedFloat64Array()  ## By code, effective (after gear).
var yield_res_of: PackedInt32Array = PackedInt32Array()  ## By code: RunState.RESOURCES index or -1.
var yield_amount_of: PackedInt32Array = PackedInt32Array()
var water_of: PackedByteArray = PackedByteArray()  ## By code: 1 for water pockets.
var gas_of: PackedByteArray = PackedByteArray()  ## By code: 1 for gas pockets.
var unstable_of: PackedByteArray = PackedByteArray()  ## By code: 1 for fault rock (strain, rockfalls).
var loot_of: PackedByteArray = PackedByteArray()  ## By code: 1 for crates (a structure's loot).
var interior_of: PackedByteArray = PackedByteArray()  ## By code: 1 for a structure's old air.
var structure_marks: PackedByteArray = PackedByteArray()  ## By cell: 2 structure interior, 1 the rest of it, 0 none.
var structures: DrillStructures  ## The segment's buried structure (read its fields for the view).
var burst_marks: PackedByteArray = PackedByteArray()  ## By cell: 1 once its pocket burst, drained or burned.
var drill_room: int = -1  ## The player's drill room index (-1 without one).

var _db: DataDB
var _px: float = 0.0
var _py: float = 0.0
var _c0: int = 0
var _c1: int = -1
var _r0: int = 0
var _r1: int = -1
var _band_dirty: bool = true
var _bb_sum: float = 0.0
var _bb_n: int = 0
var _bl_sum: float = 0.0
var _bl_n: int = 0
var _br_sum: float = 0.0
var _br_n: int = 0
var _pend_amt: PackedInt32Array = PackedInt32Array()  ## Yield waiting for the flush, by material code.
var _pend_codes: PackedInt32Array = PackedInt32Array()  ## Codes with a pending yield, in first-cut order.
var _pend_n: int = 0
var _bit_change_ticks: int = 0
var _bit_broken_said: bool = false
var _return_phase: String = "idle"
var _power: PackedFloat64Array = PackedFloat64Array()
var _cut_x: float = 1.0  ## Gear multipliers, read when the segment begins.
var _wear_x: float = 1.0
var _hard_x: float = 1.0
# Tuning, read once.
var _base_speed: float = 1.0
var _max_speed: float = 3.0
var _air_floor: float = 0.3
var _turn_per_tick: float = 0.0
var _max_heading: float = 90.0  ## The fallback cap when the by-helm table is absent.
var _heading_by_helm: PackedFloat64Array = PackedFloat64Array()  ## Cap by installed helm bars (0..HELM_TABLE_MAX).
var _range_by_helm: PackedFloat64Array = PackedFloat64Array()  ## Scanner range by installed helm bars.
var _wall_deg: float = 80.0
var _band: int = 2
var _heat_kw_per_bar: float = 0.0
var _wear_k: float = 0.0
var _bit_slow: float = 0.5
var _broken_factor: float = 0.2
var _noise_k: float = 0.0
var _rock_base_c: float = 40.0
var _rock_c_per_m: float = 0.0
var _hard_min: float = 3.0
var _stamp_tune: Dictionary = {}


func _init(db: DataDB) -> void:
	_db = db
	for i: int in range(MAX_POWER_BAR + 1):
		_power.append(db.tune("drill.power_factor_bar_%d" % i))
	cell_m = db.tune("drill.cell_m")
	_base_speed = db.tune("drill.base_speed_m_s")
	_max_speed = db.tune("drill.max_speed_m_s")
	_air_floor = maxf(0.01, db.tune("drill.air_hardness_floor"))
	_turn_per_tick = db.tune("drill.turn_deg_s") * Sim.DT
	_max_heading = db.tune("drill.max_heading_deg")
	_heading_by_helm = helm_table(db, HEADING_TABLE, _max_heading)
	_range_by_helm = helm_table(db, RANGE_TABLE, NO_RANGE_M)
	_wall_deg = db.tune("drill.at_wall_heading_deg")
	_band = maxi(1, roundi(db.tune("drill.band_cells")))
	_heat_kw_per_bar = db.tune("drill.heat_kw_per_bar")
	_wear_k = db.tune("drill.wear_per_m_hardness")
	_bit_slow = db.tune("drill.bit_slow_at_full_wear")
	_broken_factor = db.tune("drill.broken_bit_factor")
	_noise_k = db.tune("drill.noise_per_m")
	_rock_base_c = db.tune("drill.rock_temp_base_c")
	_rock_c_per_m = db.tune("drill.rock_temp_c_per_m")
	_hard_min = db.tune("drill.hard_rock_min_hardness")
	yielded.resize(RunState.RESOURCES.size())
	yield_mat.resize(MAX_CODES)
	_pend_amt.resize(MAX_CODES)
	_pend_codes.resize(MAX_CODES)
	verbs = DrillVerbs.new(db)
	miner = DrillMiner.new(db)
	structures = DrillStructures.new()
	_stamp_tune = {"at_min": db.tune("drill.structure_at_min_frac"), "at_max": db.tune("drill.structure_at_max_frac"),
		"off_min_m": db.tune("drill.structure_offset_min_m"), "off_max_m": db.tune("drill.structure_offset_max_m")}


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


## {"type": "steer", "angle": deg} | {"type": "change_bit"} | {"type": "blast", "x_m", "y_m"} (DrillVerbs) |
## {"type": "send_miner", "crew", "x_m", "y_m"} | {"type": "recall_miner"} (DrillMiner) |
## {"type": "begin_segment", "segment": id, "depth_m": d, "lateral_m": x, "rock": table id (optional),
##  "survey": a node survey (optional, see RockGen.options_of)}
func apply(sim: Sim, cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"steer":
			var cap: float = max_heading_deg(sim)
			target_heading_deg = clampf(float(cmd.get("angle", 0.0)), -cap, cap)
		"change_bit":
			change_bit(sim)
		"blast":
			verbs.fire_blast(sim, self, Vector2(float(cmd.get("x_m", -1.0)), float(cmd.get("y_m", -1.0))))
		"send_miner":
			miner.send(sim, self, str(cmd.get("crew", "")), Vector2(float(cmd.get("x_m", -1.0)), float(cmd.get("y_m", -1.0))))
		"recall_miner":
			miner.recall(sim, self)
		"begin_segment":
			var sv: Variant = cmd.get("survey", {})
			begin_segment(sim, str(cmd.get("segment", "")), float(cmd.get("depth_m", 36.0)),
					float(cmd.get("lateral_m", 0.0)), str(cmd.get("rock", DEFAULT_ROCK)), sv if sv is Dictionary else {})


## Start a segment: generate the rock and switch the run to the "drill" phase. Allowed from "idle"
## (a run between nodes) or "scenario" (tests and captures). On arrival a scenario returns to
## "scenario" and a run calls RunState.arrive (which goes back to idle when no node was chosen).
## The work is in DrillSegment.begin.
func begin_segment(sim: Sim, p_segment_id: String, p_depth_m: float, lateral_m: float,
		p_rock_id: String = DEFAULT_ROCK, p_survey: Dictionary = {}) -> bool:
	return DrillSegment.begin(sim, self, p_segment_id, p_depth_m, lateral_m, p_rock_id, p_survey)


## Spend a drill bit (run resource "bits") and stop drilling while it is fitted.
func change_bit(sim: Sim) -> bool:
	if _bit_change_ticks > 0 or sim.run.get_res("bits") <= 0:
		sim.emit("bad_command", {"type": "change_bit", "why": "already changing" if _bit_change_ticks > 0 else "no bits left"})
		return false
	sim.run.add(sim, "bits", -1)
	_bit_change_ticks = maxi(1, roundi(_db.tune("drill.bit_change_s") * Sim.TICK_HZ))
	bit_change_left_s = float(_bit_change_ticks) / Sim.TICK_HZ
	sim.emit("bit_change_started", {"bits_left": sim.run.get_res("bits")})
	return true


## 0 at the start of the segment, 1 on arrival.
func progress() -> float:
	if depth_m <= 0.0:
		return 0.0
	return clampf((_py - start_y) / depth_m, 0.0, 1.0)


func power_factor(bars: int) -> float:
	return _power[clampi(bars, 0, MAX_POWER_BAR)]


## The steepest heading the player's ship may steer to now (degrees), by the helm's installed bars.
func max_heading_deg(sim: Sim) -> float:
	return _heading_by_helm[helm_bars(sim)]


## How far from the drill head the scanner shows rock now (meters), by the helm's installed bars.
func scanner_range_m(sim: Sim) -> float:
	return _range_by_helm[helm_bars(sim)]


## The player's helm installed bars (Room.sys_max), clamped to the tables' range; 0 without a helm.
static func helm_bars(sim: Sim) -> int:
	var ri: int = sim.ship.room_with_system("helm")
	return clampi(sim.ship.rooms[ri].sys_max, 0, HELM_TABLE_MAX) if ri >= 0 else 0


## A by-helm tuning table as one value per bar count 0..HELM_TABLE_MAX: the value of the highest key
## at or below each count, `fallback` below the first key present.
static func helm_table(db: DataDB, prefix: String, fallback: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var cur: float = fallback
	for i: int in range(HELM_TABLE_MAX + 1):
		var key: String = prefix + str(i)
		if db.tuning.has(key):
			cur = float(db.tuning[key])
		out.append(cur)
	return out


## Every key the by-helm tables may use (the tuning-keys check reads these).
static func helm_table_keys() -> Array[String]:
	var out: Array[String] = []
	for prefix: String in [HEADING_TABLE, RANGE_TABLE]:
		for i: int in range(HELM_TABLE_MAX + 1):
			out.append(prefix + str(i))
	return out


## "" when a blast may be fired now, else why not (DrillVerbs.blast_ready).
func blast_ready(sim: Sim) -> String:
	return verbs.blast_ready(sim, self)


## Material lookup by code for the view and bots: {"id", "name", "hardness", "color", "res", "amount"} or {}.
func material(code: int) -> Dictionary:
	if code < 0 or code >= materials.size():
		return {}
	return materials[code]


func step(sim: Sim) -> void:
	if _bit_change_ticks > 0 and sim.run.world_running():
		_bit_change_ticks -= 1
		bit_change_left_s = float(_bit_change_ticks) / Sim.TICK_HZ
		if _bit_change_ticks == 0:
			bit_wear = 0.0
			bit_broken = false
			_bit_broken_said = false
			sim.emit("bit_changed", {})
	if sim.run.world_running():
		verbs.tick_cooldown()
	miner.watch(sim, self)
	if not active or sim.run.phase != "drill":
		return
	segment_ticks += 1
	# Systems: a manned helm turns faster and cuts sideways faster; a manned drill room cuts faster
	# (drill_bonus is a multiplier).
	heading_deg = move_toward(heading_deg, target_heading_deg, _turn_per_tick * sim.systems.steer_rate_scale(sim.player))
	if absf(heading_deg) > STEEP_DEG:
		steep_ticks += 1
	side_scale = sim.systems.side_cut_scale(sim.player)
	var bars: int = sim.systems.drill_bars(sim.player)
	var pf: float = power_factor(bars) * sim.systems.drill_bonus(sim.player)
	speed_m_s = 0.0
	cutting = false
	at_wall = false
	if pf > 0.0 and _bit_change_ticks == 0 and not parked:
		DrillCutting.drive(sim, self, bars, pf)
	verbs.step(sim, self)
	miner.step(sim, self)
	structures.resolve(sim, self, not sim.run.is_over())
	if sim.run.is_over():
		return
	sim.run.depth_m = start_depth_m + (_py - start_y)
	var base_c: float = _rock_base_c
	var per_m: float = _rock_c_per_m
	if not sim.run.layer.is_empty():  # In a run the layer owns rock heat; drill tuning is the scenario fallback.
		base_c = float(sim.run.layer.get("rock_temp_base_c", base_c))
		per_m = float(sim.run.layer.get("rock_temp_c_per_m", per_m))
	sim.ship.rock_temp_c = base_c + per_m * sim.run.depth_m + sim.run.rock_add_c(sim.player)  # Plus the environment's (magma).
	if sim.run.phase == "drill" and not parked and _py + ship_size.y >= target_y - EPS:
		DrillSegment.arrive(sim, self)  # Not while a break-in has a store or an event open: the segment waits for it.


# Footprint and cutting (the work is in DrillCutting) ----------------------------------------------

func _set_footprint() -> void:
	_c0 = clampi(floori(_px / cell_m + EPS), 0, cols - 1)
	_c1 = clampi(ceili((_px + ship_size.x) / cell_m - EPS) - 1, 0, cols - 1)
	_r0 = clampi(floori(_py / cell_m + EPS), 0, rows - 1)
	_r1 = clampi(ceili((_py + ship_size.y) / cell_m - EPS) - 1, 0, rows - 1)


## Cut cell i (not air) by a cutter: DrillMiner.CUT_DRILL (the crown) or CUT_MINER (DrillCutting.cut).
func cut(sim: Sim, i: int, cutter: int) -> void:
	DrillCutting.cut(sim, self, i, cutter)


## Turn cell i into air and book it; returns the material code it had (DrillCutting.take_cell).
func take_cell(i: int, cutter: int = DrillMiner.CUT_DRILL) -> int:
	return DrillCutting.take_cell(self, i, cutter)


## Pay what was cut since the last flush, "mined" events at (x, y) (DrillCutting.flush_yields).
func flush_yields(sim: Sim, x: float, y: float) -> void:
	DrillCutting.flush_yields(sim, self, x, y)


## Keep pct percent of every pending yield, rounded down (DrillCutting.scale_pending).
func scale_pending(pct: int) -> void:
	DrillCutting.scale_pending(self, pct)


## Everything this module owns, in a fixed order, for the state hash (the grid bytes included).
func state() -> Array:
	return [active, segment_id, rock_id, grid_serial, cols, rows, cell_m, _px, _py, heading_deg,
		target_heading_deg, speed_m_s, bit_wear, bit_broken, _bit_broken_said, _bit_change_ticks, cutting,
		start_center_x, start_y, target_x, target_y, depth_m, start_depth_m, distance_m, segment_ticks,
		noise_segment, noise_total, mined, yielded, yield_mat, water_in_ml, lost_water_ml, heat_added_j,
		pockets_burst, gas_bursts, _return_phase, grid, burst_marks, speed_scale, survey.values(), _cut_x, _wear_x, _hard_x,
		side_scale, at_wall, steep_ticks, verbs.state(), structure_marks, structures.state(), parked, miner.state()]


static func lint(db: DataDB, errs: PackedStringArray) -> void:
	DrillLint.lint(db, errs)
