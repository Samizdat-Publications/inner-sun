extends Node
## First autoload: decides whether the window may take keyboard focus.
## The project creates every window unfocusable (display/window/size/no_focus=true), because a
## window that can take focus grabs the foreground even when parked off-screen (measured in M0:
## 65 of 71 samples). Bot-driven runs (captures, shots, perf, timed runs) stay unfocusable so they
## never steal Stewart's keyboard. Normal play gets focus back here, before the first frame.

const BOT_FLAGS: Array[String] = ["--shots", "--capture", "--perf", "--run-ticks"]


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if is_bot_run():
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
	DisplayServer.window_move_to_foreground()


static func is_bot_run() -> bool:
	for a: String in OS.get_cmdline_user_args():
		for f: String in BOT_FLAGS:
			if a.begins_with(f):
				return true
	return false
