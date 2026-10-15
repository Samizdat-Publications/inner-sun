class_name RngStreams
extends RefCounted
## Independent, named, seeded random streams. Drawing from one stream never shifts another, so a
## new random event in one system cannot change the outcome of an unrelated system.

var base_seed: int = 0
var _streams: Dictionary = {}


func _init(p_seed: int) -> void:
	base_seed = p_seed


func get_stream(stream: String) -> RandomNumberGenerator:
	if _streams.has(stream):
		return _streams[stream]
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d/%s" % [base_seed, stream])
	_streams[stream] = r
	return r


## Snapshot for the state hash. Names are sorted as plain Strings (never sort StringNames: their
## order is not stable between runs).
func state() -> Dictionary:
	var names := PackedStringArray()
	for k: String in _streams.keys():
		names.append(k)
	names.sort()
	var out: Dictionary = {}
	for n: String in names:
		var r: RandomNumberGenerator = _streams[n]
		out[n] = r.state
	return out
