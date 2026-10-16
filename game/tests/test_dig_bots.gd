extends TestCase
## The policy bots use the M1c dig verbs: greedy blasts for loot, cautious keeps bracing up, nobody
## sits at the segment wall, every segment finishes.


func _count(s: Sim, kind: String) -> int:
	var n: int = 0
	for e: Dictionary in s.events:
		if str(e["kind"]) == kind:
			n += 1
	return n


## A policy bot drives one segment (run mode, no map). Returns [blasts, wall ticks, rockfalls,
## ticks with a bracing layer up, still active].
func _bot_segment(policy: String, p_seed: int) -> Array:
	var s := Sim.new(db(), p_seed, "light_drill", {"mode": "run"})
	s.run.add(s, "charges", 6)
	s.step()
	s.push({"type": "begin_segment", "segment": "bot%d" % p_seed, "depth_m": 60.0, "lateral_m": 2.0,
			"survey": {"faults": true, "gas": true, "richness": 1.6}})
	s.step()
	var bot: PolicyBot = PolicyBot.make_policy(policy)
	var wall: int = 0
	var braced: int = 0
	var cap: int = 60 * 300
	while s.drill.active and cap > 0 and not s.run.is_over():
		bot.act(s)
		s.step()
		cap -= 1
		if s.drill.at_wall:
			wall += 1
		if s.systems.bracing_layers(s.player) > 0:
			braced += 1
	return [_count(s, "blast"), wall, _count(s, "rockfall"), braced, s.drill.active]


func test_policy_bots_use_the_dig_verbs() -> void:
	var blasts: Dictionary = {}
	var braced: Dictionary = {}
	for policy: String in ["cautious", "greedy", "balanced"]:
		var nb: int = 0
		var nbr: int = 0
		for p_seed: int in [1, 2, 3]:
			var r: Array = _bot_segment(policy, p_seed)
			nb += int(r[0])
			nbr += int(r[3])
			check_lt(float(r[1]), 30.0, "%s seed %d never sits at the wall (%d ticks)" % [policy, p_seed, int(r[1])])
			check(not bool(r[4]), "%s seed %d finishes the segment" % [policy, p_seed])
		blasts[policy] = nb
		braced[policy] = nbr
	print("DIGVERBS blasts per policy: ", blasts, " ticks braced: ", braced)
	check_gt(float(int(blasts["greedy"])), 0.0, "greedy blasts for loot")
	check_gt(float(int(braced["cautious"])), float(int(braced["greedy"])), "cautious keeps bracing up longer than greedy")
