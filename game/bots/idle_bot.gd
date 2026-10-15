class_name IdleBot
extends Bot
## Nobody responds: the crew's judgement is switched off and no orders are given. The baseline that
## shows what hazards do when ignored.

var _started: bool = false


func act(sim: Sim) -> void:
	if not _started:
		_started = true
		Bot.take_control(sim)
