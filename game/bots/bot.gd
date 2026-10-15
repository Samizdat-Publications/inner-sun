class_name Bot
extends RefCounted
## Bots play through the same command chain as the player: they read the sim and push commands,
## and never change the sim directly. The base bot ("auto") gives no orders and leaves the crew's own
## judgement on.


func act(_sim: Sim) -> void:
	pass


static func make(bot_name: String) -> Bot:
	match bot_name:
		"scripted_fire_drill":
			return FireDrillBot.new()
		"idle":
			return IdleBot.new()
		"random":
			return RandomBot.new()
		"drill":
			return DrillBot.new()
		"run":
			return RunBot.new()
	return Bot.new()


## Turn every crew member's own judgement off (bots that give all orders themselves).
static func take_control(sim: Sim) -> void:
	for c: CrewMember in sim.ship.crew:
		sim.push({"type": "auto", "crew": c.id, "on": false})
