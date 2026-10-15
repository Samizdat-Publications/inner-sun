class_name RunRecord
extends RefCounted
## A finished (or abandoned) run on disk: seed, ship, run options, the full command log, the final
## tick and state hash, and the summary. Replaying a record rebuilds the run exactly, so every run
## Stewart plays is a bug reproduction. Saved under <profile dir>/runs/. File I/O lives here, never
## in game/sim.

const VERSION: int = 1


## Save the run and return the file path ("" on failure). `stamp` names the file (the caller passes
## a date string; the sim has no clock).
static func save(p_dir: String, sim: Sim, summary: Dictionary, stamp: String) -> String:
	var runs_dir: String = p_dir.path_join("runs")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(runs_dir))
	var path: String = runs_dir.path_join("%s_%d.json" % [stamp, sim.run_seed])
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("run record: cannot write %s" % path)
		return ""
	var data: Dictionary = {
		"version": VERSION, "seed": sim.run_seed, "ship": sim.ship_id, "options": sim.options,
		"ticks": sim.tick, "hash": sim.state_hash(), "commands": sim.command_log, "summary": summary,
	}
	f.store_string(JSON.stringify(data, "", true, true))
	f.close()
	return path


static func load_record(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}


## Rebuild the run from a loaded record. JSON turns integers into floats; the sim reads every
## command field with int() or float(), and the tick stamps are converted here.
static func replay(db: DataDB, record: Dictionary) -> Sim:
	var cmds: Array[Dictionary] = []
	for c: Variant in record.get("commands", []):
		if c is Dictionary:
			var cmd: Dictionary = (c as Dictionary).duplicate(true)
			cmd["t"] = int(cmd.get("t", 0))
			cmds.append(cmd)
	var opts: Dictionary = record.get("options", {})
	return Sim.replay(db, int(record.get("seed", 0)), str(record.get("ship", "")), cmds, int(record.get("ticks", 0)), opts)
