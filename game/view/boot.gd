extends Node
## First autoload: keeps bot-driven windows out of Stewart's way, and gives normal play its focus.
## Bot-driven runs (captures, shots, perf, timed runs) need a real window to render, but:
##  - Godot pulls a window that starts at --position -32000,-32000 back onto the screen (measured in
##    M0: it sat in the top-left corner), so the window is parked off-screen again from here, every
##    frame for the first half second, until it stays put;
##  - a window that can take focus grabs the foreground even off-screen, so the project creates
##    every window unfocusable (display/window/size/no_focus=true).
## Normal play gets focus back here, before the first frame.

const BOT_FLAGS: Array[String] = ["--shots", "--capture", "--perf", "--run-ticks", "--bakeoff", "--gallery"]
const PARK: Vector2i = Vector2i(-32000, -32000)
const PARK_FRAMES: int = 30

var _parked: int = 0


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if is_bot_run():
		DisplayServer.window_set_position(PARK)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
	DisplayServer.window_move_to_foreground()


func _ready() -> void:
	set_process(DisplayServer.get_name() != "headless" and is_bot_run())


func _process(_delta: float) -> void:
	DisplayServer.window_set_position(PARK)
	_parked += 1
	if _parked >= PARK_FRAMES:
		set_process(false)


static func is_bot_run() -> bool:
	for a: String in OS.get_cmdline_user_args():
		for f: String in BOT_FLAGS:
			if a.begins_with(f):
				return true
	return false
