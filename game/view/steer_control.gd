class_name SteerControl
extends RefCounted
## The drilling steering keys, kept apart from Main so they can be tested without a window:
##   A or Left / D or Right   step the target heading 15 degrees per press, repeating about 8 times a
##                            second while held (after a short pause)
##   S or Down                straight down
##   Shift plus A or D        hold depth: all the way to -90 or +90 (cutting sideways)
## Every method returns the new target heading in degrees, or NAN when the key means nothing here.
## Main sends the result to the scanner's `queue_steer` (a command, like the bots use).

const STEP_DEG: float = 15.0
const FIRST_REPEAT_S: float = 0.28
const REPEAT_S: float = 0.125  ## About 8 steps a second.

var _held: Dictionary = {}
var _wait_s: float = 0.0


static func key_dir(code: Key) -> int:
	if code == KEY_A or code == KEY_LEFT:
		return -1
	if code == KEY_D or code == KEY_RIGHT:
		return 1
	return 0


static func step_target(cur: float, dir: int, limit: float) -> float:
	return clampf(cur + float(dir) * STEP_DEG, -limit, limit)


func clear() -> void:
	_held.clear()
	_wait_s = 0.0


## A key went down. `cur` is the heading being steered to now, `limit` the sim's largest heading.
func press(code: Key, shift: bool, cur: float, limit: float) -> float:
	if code == KEY_S or code == KEY_DOWN:
		return 0.0
	var dir: int = key_dir(code)
	if dir == 0:
		return NAN
	if shift:
		_held.erase(code)
		return float(dir) * limit
	_held[code] = true
	_wait_s = FIRST_REPEAT_S
	return step_target(cur, dir, limit)


func release(code: Key) -> void:
	_held.erase(code)


## The direction the held keys ask for (opposite keys cancel).
func held_dir() -> int:
	var dir: int = 0
	for code: Variant in _held.keys():
		dir += key_dir(code as Key)
	return clampi(dir, -1, 1)


## Called every frame: after the first pause, a held A or D steps again every REPEAT_S.
func repeat(delta: float, cur: float, limit: float) -> float:
	var dir: int = held_dir()
	if dir == 0:
		return NAN
	_wait_s -= delta
	if _wait_s > 0.0:
		return NAN
	_wait_s += REPEAT_S
	var out: float = step_target(cur, dir, limit)
	return NAN if out == cur else out
