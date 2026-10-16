class_name Research
extends RefCounted
## Research: the payout of a run. TOPSIDE's lab turns the rig's telemetry into research even when the
## crew does not come back, and research buys requisitions (game/data/requisitions). A pure function
## of the run summary (RunState.summary), so tests, the profile and the death screen always agree.
## The numbers are logged in docs/DECISIONS.md (D040).

const PER_ROW: int = 2  ## For each map row reached.
const PER_CODEX: int = 5  ## For each codex entry learned this run that the profile did not know.
const PER_FIGHT: int = 3  ## For each fight won.
const GATE_BONUS: int = 15  ## For beating the layer gate (result "won").
const ORE_PER_POINT: int = 40  ## One research per this much ore gained (rounded down).


## The breakdown: {"lines": Array of {"label", "count", "each", "points", "per"}, "total": int}.
## Lines that earned nothing are left out. "per" is true when `each` is a divisor (ore).
static func compute(summary: Dictionary) -> Dictionary:
	var lines: Array[Dictionary] = []
	var rows: int = maxi(0, int(summary.get("rows_reached", 0)))
	_line(lines, "ROWS REACHED", rows, PER_ROW, rows * PER_ROW)
	var codex: Array = summary.get("codex", [])
	_line(lines, "CODEX ENTRIES", codex.size(), PER_CODEX, codex.size() * PER_CODEX)
	var fights: int = maxi(0, int(summary.get("fights_won", 0)))
	_line(lines, "FIGHTS WON", fights, PER_FIGHT, fights * PER_FIGHT)
	if str(summary.get("result", "")) == "won":
		_line(lines, "GATE BEATEN", 1, GATE_BONUS, GATE_BONUS)
	var ore: int = maxi(0, int((summary.get("gained", {}) as Dictionary).get("ore", 0)))
	_line(lines, "ORE RECOVERED", ore, ORE_PER_POINT, ore / ORE_PER_POINT, true)
	var total: int = 0
	for l: Dictionary in lines:
		total += int(l["points"])
	return {"lines": lines, "total": total}


## Just the total.
static func earned(summary: Dictionary) -> int:
	return int(compute(summary)["total"])


static func _line(lines: Array[Dictionary], label: String, count: int, each: int, points: int, per: bool = false) -> void:
	if points <= 0:
		return
	lines.append({"label": label, "count": count, "each": each, "points": points, "per": per})
