class_name ReplayDriver
extends Driver
## Plays a saved run record (game/meta/run_record.gd) back exactly: the same seed, run options and
## commands at the same ticks, so a run Stewart played can be watched or bisected. Used by the game
## (--replay=<record>) and by tools/replay.py (headless, compares the final hash).

var record: Dictionary = {}
var expect_hash: String = ""
var _cmds: Array[Dictionary] = []
var _i: int = 0


static func from_record(db: DataDB, p_record: Dictionary) -> ReplayDriver:
	var rd := ReplayDriver.new()
	rd.record = p_record
	rd.bot_name = "replay"
	rd.bot = Bot.new()
	var opts: Dictionary = p_record.get("options", {})
	rd.sim = Sim.new(db, int(p_record.get("seed", 0)), str(p_record.get("ship", "light_drill")), opts)
	for c: Variant in p_record.get("commands", []):
		if c is Dictionary:
			var cmd: Dictionary = (c as Dictionary).duplicate(true)
			cmd["t"] = int(cmd.get("t", 0))
			rd._cmds.append(cmd)
	rd.duration_ticks = int(p_record.get("ticks", 0))
	rd.expect_hash = str(p_record.get("hash", ""))
	return rd


func step() -> void:
	if done():
		return
	while _i < _cmds.size() and int(_cmds[_i]["t"]) == sim.tick:
		var cmd: Dictionary = _cmds[_i].duplicate()
		cmd.erase("t")
		sim.push(cmd)
		_i += 1
	sim.step()
	if sim.tick >= duration_ticks:
		outcome = "replayed"
		cause = "match" if sim.state_hash() == expect_hash else "MISMATCH"
