class_name Profile
extends RefCounted
## The player's progress across runs: the codex they have learned (it lifts redactions and can
## unlock event options), run history, best depth, deaths by cause, unlocks. File I/O lives here,
## never in game/sim. The profile folder is user:// in normal play; bots, tests and balance runs pass
## --profile-dir=<repo path> so they never touch Stewart's profile (all worktrees share the Godot
## user folder). A missing or corrupt file gives a fresh profile, never a crash.

const VERSION: int = 1
const FILE_NAME: String = "profile.json"
const HISTORY_MAX: int = 50

var dir: String = "user://"
var known_codex: PackedStringArray = PackedStringArray()
var runs: int = 0
var wins: int = 0
var best_depth_m: float = 0.0
var deaths: Dictionary = {}  ## cause -> count
var unlocks: PackedStringArray = PackedStringArray()
var history: Array[Dictionary] = []


## The profile folder from the command line (--profile-dir=<path>), else user://.
static func dir_from_args(args: Args) -> String:
	return args.get_str("profile-dir", "user://")


static func load_from(p_dir: String) -> Profile:
	var p := Profile.new()
	p.dir = p_dir
	var path: String = p_dir.path_join(FILE_NAME)
	if not FileAccess.file_exists(path):
		return p
	var json := JSON.new()
	var ok: bool = json.parse(FileAccess.get_file_as_string(path)) == OK  # parse() fails quietly; parse_string() logs an error
	var parsed: Variant = json.data if ok else null
	if not (parsed is Dictionary):
		push_warning("profile: %s is unreadable; starting a fresh profile (the old file is kept as .bad)" % path)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bad"))
		return p
	var d: Dictionary = parsed
	for k: Variant in d.get("known_codex", []):
		p.known_codex.append(str(k))
	p.known_codex.sort()
	p.runs = int(d.get("runs", 0))
	p.wins = int(d.get("wins", 0))
	p.best_depth_m = float(d.get("best_depth_m", 0.0))
	var dd: Variant = d.get("deaths", {})
	if dd is Dictionary:
		var deaths_in: Dictionary = dd
		for cause: Variant in deaths_in.keys():
			p.deaths[str(cause)] = int(deaths_in[cause])
	for u: Variant in d.get("unlocks", []):
		p.unlocks.append(str(u))
	for h: Variant in d.get("history", []):
		if h is Dictionary:
			p.history.append(h)
	return p


## The options a new run starts with (what the profile already knows is part of the replay header).
func run_options() -> Dictionary:
	return {"mode": "run", "known_codex": Array(known_codex)}


## Fold a finished run into the profile: what it learned, how it ended, how deep it got.
func merge_run(summary: Dictionary, learned: PackedStringArray) -> void:
	for c: String in learned:
		if not known_codex.has(c):
			known_codex.append(c)
	known_codex.sort()
	runs += 1
	var result: String = str(summary.get("result", ""))
	if result == "won":
		wins += 1
	elif result == "dead":
		var cause: String = str(summary.get("cause", "unknown"))
		deaths[cause] = int(deaths.get(cause, 0)) + 1
	best_depth_m = maxf(best_depth_m, float(summary.get("depth_m", 0.0)))
	history.append(summary.duplicate(true))
	while history.size() > HISTORY_MAX:
		history.pop_front()


## Write atomically (temp file, then rename). Returns false on failure.
func save() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path: String = dir.path_join(FILE_NAME)
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("profile: cannot write %s" % tmp)
		return false
	var data: Dictionary = {
		"version": VERSION, "known_codex": Array(known_codex), "runs": runs, "wins": wins,
		"best_depth_m": best_depth_m, "deaths": deaths, "unlocks": Array(unlocks), "history": history,
	}
	f.store_string(JSON.stringify(data, "  ", true, true))
	f.close()
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path) == OK
