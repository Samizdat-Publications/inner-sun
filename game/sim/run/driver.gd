class_name Driver
extends RefCounted
## What drives a Sim forward: a ScenarioRun (one situation with a timeline) or a FullRun (a whole
## run). The game's main scene, the capture director and the readouts talk to this base, so they
## work the same for both. A driver holds the sim, its bot, and how the play ended.

var sim: Sim
var bot: Bot
var bot_name: String = ""
var duration_ticks: int = 0  ## When a capture or timed run should stop (a cap for full runs).
var outcome: String = ""  ## "" while running.
var cause: String = ""


func done() -> bool:
	return outcome != ""


## One tick: the bot acts (commands), then the sim steps.
func step() -> void:
	pass
