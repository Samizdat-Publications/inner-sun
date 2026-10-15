class_name FullRun
extends RefCounted
## A whole run (map, travel, nodes, pursuer, death or the gate) played by a bot, like ScenarioRun is
## for single situations. Used by tests and headless balance runs. No file I/O here: callers save the
## profile (Profile.merge_run) and the record (RunRecord.save) from game/meta.

const DEFAULT_CAP_S: float = 3600.0  ## Hard cap on simulated time; a run that reaches it is "stuck".

var sim: Sim
var bot: Bot
var bot_name: String = ""
var cap_ticks: int = 0
var outcome: String = ""  ## "" while running, then "dead", "won" or "stuck".
var cause: String = ""


## options: Profile.run_options() (mode is forced to "run"), plus "layer" if not the default.
static func start(db: DataDB, run_seed: int, p_bot_name: String = "run", options: Dictionary = {},
		ship_id: String = "light_drill", cap_s: float = DEFAULT_CAP_S) -> FullRun:
	var opts: Dictionary = options.duplicate(true)
	opts["mode"] = "run"
	var fr := FullRun.new()
	fr.sim = Sim.new(db, run_seed, ship_id, opts)
	fr.bot_name = p_bot_name
	fr.bot = Bot.make(p_bot_name)
	fr.cap_ticks = roundi(cap_s * Sim.TICK_HZ)
	return fr


func done() -> bool:
	return outcome != ""


func step() -> void:
	if done():
		return
	bot.act(sim)
	sim.step()
	if sim.run.is_over():
		outcome = sim.run.phase
		cause = sim.run.end_cause


## Play to the end with a hard tick cap, so a broken bot or module can never spin forever: if the sim
## stops advancing or the cap is reached, the run ends as "stuck".
func play_to_end() -> void:
	var last_tick: int = -1
	while not done():
		step()
		if done():
			return
		if sim.tick == last_tick:
			outcome = "stuck"
			cause = "the sim stopped advancing (see engine errors)"
			return
		if sim.tick >= cap_ticks:
			outcome = "stuck"
			cause = "tick cap (%d s) reached in phase %s" % [roundi(float(cap_ticks) / Sim.TICK_HZ), sim.run.phase]
			return
		last_tick = sim.tick


## The run summary (RunState.summary) plus the bot, tick count and final state hash.
func summary() -> Dictionary:
	var s: Dictionary = sim.run.summary(sim)
	if outcome == "stuck":
		s["result"] = "stuck"
		s["cause"] = cause
	s["bot"] = bot_name
	s["ticks"] = sim.tick
	s["hash"] = sim.state_hash()
	return s
