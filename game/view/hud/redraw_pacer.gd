class_name RedrawPacer
extends RefCounted
## Caps a HUD panel's per-frame redraw at 60 per second (the sim's tick rate, so no shown value can
## change faster). Uncapped, every panel redrew its text and bars every frame: about 3 ms a frame at
## 150 fps. Each new pacer starts a quarter period after the previous one, so the panels redraw on
## different frames instead of all at once. Orders and binds still redraw at once (queue_redraw).

const PERIOD_USEC: int = 16667
const PHASES: int = 4

static var _made: int = 0

var _next: int = 0


func _init() -> void:
	_next = Time.get_ticks_usec() + (_made % PHASES) * PERIOD_USEC / PHASES
	_made += 1


## True if the panel should redraw this frame. Keeps its own phase after a slow frame.
func due() -> bool:
	var now: int = Time.get_ticks_usec()
	if now < _next:
		return false
	_next += PERIOD_USEC
	if _next <= now:
		_next += ((now - _next) / PERIOD_USEC + 1) * PERIOD_USEC
	return true
