class_name RunBot
extends Bot
## Plays a whole run through commands only. Between nodes it picks the next node by a simple policy
## (a store when the hull is low, fights when healthy, never an overtaken node if there is a choice,
## unknown nodes count as middling); while drilling it drives like DrillBot (reused); it keeps the
## drill at drill_bars; on event pages it takes the first option and it leaves stores at once.
## Deterministic: ties go to the first link in map order. Crew keep their own judgement.

var drill_bars: int = 2
var low_hull_frac: float = 0.5  ## Below this, stores are worth the most.
var healthy_frac: float = 0.6  ## At or above this, fights are welcome.
var retry_ticks: int = 30  ## Wait between repeated commands while a phase lasts.

var _drill_bot: DrillBot = DrillBot.new()
var _next_choose: int = 0
var _next_page: int = 0
var _next_power: int = 0


func act(sim: Sim) -> void:
	var run: RunState = sim.run
	if run.is_over():
		return
	if sim.tick >= _next_power:
		_next_power = sim.tick + 60
		var di: int = sim.ship.room_with_system("drill")
		if di >= 0 and sim.ship.rooms[di].sys_power != drill_bars:
			sim.push({"type": "power", "room": sim.ship.rooms[di].id, "bars": drill_bars})
	match run.phase:
		"drill":
			_drill_bot.act(sim)
		"idle":
			if sim.tick >= _next_choose:
				_next_choose = sim.tick + retry_ticks
				var id: String = choose(sim)
				if not id.is_empty():
					sim.push({"type": "choose_node", "node": id})
		"dialog":
			if sim.tick >= _next_page:
				_next_page = sim.tick + retry_ticks
				sim.push({"type": "choose", "option": 0})
		"store":
			if sim.tick >= _next_page:
				_next_page = sim.tick + retry_ticks
				sim.push({"type": "leave"})


## The best linked node from the current one ("" if none).
func choose(sim: Sim) -> String:
	var run: RunState = sim.run
	var hull_frac: float = float(run.get_res("hull")) / maxf(1.0, float(sim.ship.hull_max))
	var best: String = ""
	var best_score: float = -INF
	for id: String in run.links_from_current():
		var n: Dictionary = run.node(id)
		var score: float = 0.5
		if run.is_revealed(n):
			score = _type_score(str(n["type"]), hull_frac)
		if run.is_overtaken(n):
			score -= 100.0
		if score > best_score:
			best_score = score
			best = id
	return best


func _type_score(kind: String, hull_frac: float) -> float:
	match kind:
		"store":
			return 4.0 if hull_frac < low_hull_frac else 0.5
		"fight":
			return 2.0 if hull_frac >= healthy_frac else -2.0
		"event":
			return 1.0
		"cavern":
			return 1.2
		"hazard":
			return -0.5
		"gate":
			return 10.0
	return 0.0
