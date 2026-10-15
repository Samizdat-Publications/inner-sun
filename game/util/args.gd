class_name Args
extends RefCounted
## The game's own command-line arguments: everything after `--`, as `--key=value` or `--flag`.

var values: Dictionary = {}


static func from_cmdline() -> Args:
	return Args.parse(OS.get_cmdline_user_args())


static func parse(argv: PackedStringArray) -> Args:
	var a := Args.new()
	for raw: String in argv:
		if not raw.begins_with("--"):
			continue
		var body: String = raw.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			a.values[body] = "true"
		else:
			a.values[body.substr(0, eq)] = body.substr(eq + 1)
	return a


func has(key: String) -> bool:
	return values.has(key)


func get_str(key: String, fallback: String = "") -> String:
	return String(values[key]) if values.has(key) else fallback


func get_int(key: String, fallback: int = 0) -> int:
	return String(values[key]).to_int() if values.has(key) else fallback


func get_float(key: String, fallback: float = 0.0) -> float:
	return String(values[key]).to_float() if values.has(key) else fallback


func get_list(key: String) -> PackedStringArray:
	if not values.has(key):
		return PackedStringArray()
	return String(values[key]).split(",", false)
