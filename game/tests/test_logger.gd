class_name TestLogger
extends Logger
## Collects every engine error so the runner can fail the test that caused it. The engine may call
## this from any thread, so it is guarded by a mutex, and it never prints (printing would recurse).

var _lines: PackedStringArray = PackedStringArray()
var _mutex: Mutex = Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var what: String = rationale if not rationale.is_empty() else code
	_mutex.lock()
	_lines.append("%s (%s:%d in %s)" % [what, file, line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func count() -> int:
	_mutex.lock()
	var n: int = _lines.size()
	_mutex.unlock()
	return n


func since(mark: int) -> PackedStringArray:
	_mutex.lock()
	var out: PackedStringArray = _lines.slice(mark)
	_mutex.unlock()
	return out
