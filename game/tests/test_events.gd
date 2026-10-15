extends TestCase
## The event runner: picks, outcomes, requirements, once_per_run, phases, replays, and the three
## real crust events played through every option (docs/plans/specs/step5_events.md).

const REAL: Array[String] = ["byrd_signal", "kola_tapes", "mohole_core"]


func _sim(p_seed: int = 7, d: DataDB = null, mode: String = "run") -> Sim:
	return Sim.new(d if d != null else db(), p_seed, "light_drill", {"mode": mode})


## Choose and step once.
func _choose(s: Sim, option: int) -> void:
	s.push({"type": "choose", "option": option})
	s.step()


func _last_bad(s: Sim) -> String:
	for i: int in range(s.events.size() - 1, -1, -1):
		if str(s.events[i]["kind"]) == "bad_command":
			return str(s.events[i].get("why", ""))
	return ""


func test_real_events_lint_clean() -> void:
	var d: DataDB = db()
	var errs := PackedStringArray()
	Encounter.lint(d, errs)
	check(errs.is_empty(), "encounter lint: " + " | ".join(errs))
	for id: String in REAL:
		check(d.table("events").has(id), "event %s is loaded" % id)
	check(d.table("stores").has("crust_trader"), "the crust store is loaded")
	check(d.table("crew").has("survivors"), "the survivors pool is loaded")


func test_lint_catches_broken_events() -> void:
	var d: DataDB = db()
	d.table("events")["broken"] = {
		"id": "broken", "kind": "dream", "layer": "crust", "rows": [5, 2], "title": "x", "file": "y",
		"start": "nowhere",
		"pages": {
			"a": {"text": "Hi {captain} [[no_such:word]].", "options": [
				{"text": "Go.", "requires": {"res": {"plutonium": 1}, "system": {"warp": 1}, "skill": {"charm": 1.0}},
				"outcomes": [{"weight": 0, "page": "zz", "effects": [
					{"type": "fight", "enemy": "battleship"}, {"type": "teleport"},
					{"type": "crew_join", "pool": "pirates"}, {"type": "codex", "id": "atlantis"},
					{"type": "hazard", "kind": "fire", "room": "system:warp", "level": 3.0}]}]}]},
			"orphan": {"text": "Nobody comes here."},
		},
	}
	var errs := PackedStringArray()
	Encounter.lint(d, errs)
	var all: String = "\n".join(errs)
	for needle: String in ["kind \"dream\"", "rows must be", "start page \"nowhere\"", "{crew}", "no_such",
			"plutonium", "\"warp\"", "charm", "weight must be", "page \"zz\" does not exist", "battleship",
			"teleport", "pirates", "atlantis", "system:warp", "level must be", "\"orphan\" is never reached"]:
		check(all.contains(needle), "lint catches " + needle)
	check(all.contains("events"), "errors name the file")


func test_pick_is_deterministic_and_filtered() -> void:
	var seen: Dictionary = {}
	var d: DataDB = db()
	for sd: int in range(1, 41):
		var s1: Sim = _sim(sd, d)
		var s2: Sim = _sim(sd, d)
		var p1: String = s1.encounter.pick_event(s1, "event", 3)
		check_eq(s2.encounter.pick_event(s2, "event", 3), p1, "same seed, same pick (seed %d)" % sd)
		check(p1 == "byrd_signal" or p1 == "kola_tapes", "only crust events of kind event: " + p1)
		seen[p1] = true
	check(seen.has("byrd_signal") and seen.has("kola_tapes"), "both candidates come up over seeds")
	var s: Sim = _sim()
	check_eq(s.encounter.pick_event(s, "cavern", 1), "", "mohole_core starts at row 2")
	check_eq(s.encounter.pick_event(s, "cavern", 2), "mohole_core", "row 2 is in range")
	check_eq(s.encounter.pick_event(s, "event", 9), "", "no event past row 7")
	check_eq(s.encounter.pick_event(s, "event", 3, "mantle"), "", "layer must match")
	check_eq(s.encounter.pick_event(s, "hazard", 3), "", "no hazard events yet")


func test_start_node_opens_dialog_and_picks_crew() -> void:
	var s: Sim = _sim()
	s.encounter.start_node(s, "cavern", 3)
	check_eq(s.run.phase, "dialog", "an event node opens a dialog")
	check_eq(s.encounter.event_id, "mohole_core", "the only cavern event")
	check_eq(s.encounter.page, "intro", "on its start page")
	check_eq(s.encounter.picked, 0, "the first live crew member is picked")
	check_eq(s.encounter.fill_text(s, "Send {crew} out."), "Send Vasquez out.", "{crew} is filled in")
	var s2: Sim = _sim()
	EventEffects.kill(s2, s2.ship.crew[0])
	s2.encounter.start_node(s2, "cavern", 3)
	check_eq(s2.encounter.picked, 1, "the dead are never picked")
	var s3: Sim = _sim()
	s3.encounter.start_node(s3, "hazard", 3)
	check_eq(s3.run.phase, "idle", "no fitting event: nothing opens")
	check(has_event(s3, "no_event"), "and it says so")
	var s4: Sim = _sim()
	s4.encounter.start_node(s4, "store", 3)
	check_eq(s4.run.phase, "store", "a store node opens the store")
	check_eq(s4.encounter.store_id, "crust_trader", "the crust store by default")


func test_outcomes_are_deterministic_and_weighted() -> void:
	var pages: Dictionary = {}
	var d: DataDB = db()
	for sd: int in range(1, 31):
		var finals: PackedStringArray = PackedStringArray()
		for _rep: int in range(2):
			var s: Sim = _sim(sd, d)
			s.encounter.start_event(s, "kola_tapes")
			_choose(s, 0)
			finals.append(s.encounter.page)
		check_eq(finals[0], finals[1], "same seed, same outcome (seed %d)" % sd)
		pages[finals[0]] = int(pages.get(finals[0], 0)) + 1
	check(pages.has("logs") and pages.has("answer"), "both outcomes come up: %s" % str(pages))
	check_gt(float(pages.get("logs", 0)), float(pages.get("answer", 0)), "weight 3 beats weight 1")


func test_requirements_gate_options() -> void:
	var s: Sim = _sim()
	s.encounter.start_event(s, "byrd_signal")
	s.step()
	check_eq(room(s, "bridge").effective_bars(), 1, "the helm runs on one bar")
	check(not s.encounter.option_block(s, 1).is_empty(), "the scanner option is greyed out")
	var enc0: Array = s.encounter.state()
	var run0: Array = s.run.state()
	var rng0: Dictionary = s.rng.state()
	_choose(s, 1)
	check(_last_bad(s).contains("helm"), "a gated choice is refused with the reason")
	check_eq(s.encounter.state(), enc0, "the encounter did not change")
	check_eq(s.run.state(), run0, "the run did not change")
	check_eq(s.rng.state(), rng0, "no dice were rolled")
	_choose(s, 7)
	check_eq(s.encounter.state(), enc0, "an option that does not exist changes nothing")
	s.push({"type": "power", "room": "bridge", "bars": 2})
	s.step()
	check(s.encounter.option_block(s, 1).is_empty(), "with two bars the option opens")
	_choose(s, 1)
	check_eq(s.encounter.page, "mast", "and it can be chosen")
	check(s.run.knows("byrd_1947"), "its effects applied")


func test_requirement_kinds() -> void:
	var s: Sim = _sim()
	check_eq(EventEffects.requirement_failure(s, {"res": {"gems": 15}}), "", "exactly enough gems")
	check(not EventEffects.requirement_failure(s, {"res": {"gems": 16}}).is_empty(), "one gem short")
	check_eq(EventEffects.requirement_failure(s, {"skill": {"repair": 1.3}}), "", "Lindqvist repairs at 1.3")
	check(not EventEffects.requirement_failure(s, {"skill": {"repair": 1.31}}).is_empty(), "nobody repairs at 1.31")
	EventEffects.kill(s, s.ship.crew[2])
	check(not EventEffects.requirement_failure(s, {"skill": {"repair": 1.3}}).is_empty(), "the dead do not count")
	check(not EventEffects.requirement_failure(s, {"codex": "kola_well"}).is_empty(), "codex unknown")
	s.run.learn(s, "kola_well")
	check_eq(EventEffects.requirement_failure(s, {"codex": "kola_well"}), "", "codex learned")
	check_eq(EventEffects.requirement_failure(s, {"system": {"reactor": 8}}), "", "reactor at 8")
	room(s, "reactor").sys_damage = 0.5
	check(not EventEffects.requirement_failure(s, {"system": {"reactor": 8}}).is_empty(), "damage costs a bar")


func test_page_without_options_ends_to_idle() -> void:
	for mode: String in ["run", "scenario"]:
		var s: Sim = _sim(3, null, mode)
		s.encounter.start_event(s, "kola_tapes")
		check_eq(s.run.phase, "dialog", "dialog in %s mode" % mode)
		_choose(s, 2)
		check_eq(s.encounter.page, "leave", "the leave page")
		_choose(s, 1)
		check(_last_bad(s).contains("option 0"), "only option 0 continues")
		check_eq(s.run.phase, "dialog", "still open")
		_choose(s, 0)
		check_eq(s.run.phase, "idle", "back to idle in %s mode" % mode)
		check_eq(s.encounter.event_id, "", "the event is closed")
		_choose(s, 0)
		check(_last_bad(s).contains("no event"), "choosing with nothing open is refused")


func test_once_per_run_over_a_run() -> void:
	var d: DataDB = db()
	var rep: Dictionary = (d.table("events")["kola_tapes"] as Dictionary).duplicate(true)
	rep["id"] = "zz_repeat"
	rep["once_per_run"] = false
	d.table("events")["zz_repeat"] = rep
	var s: Sim = _sim(5, d)
	var counts: Dictionary = {}
	for i: int in range(12):
		var id: String = s.encounter.pick_event(s, "event", 4)
		check(not id.is_empty(), "the repeatable event keeps the pool non-empty")
		counts[id] = int(counts.get(id, 0)) + 1
		s.encounter.start_event(s, id)
		_choose(s, 2)
		_choose(s, 0)
		check_eq(s.run.phase, "idle", "event %d ended" % i)
	check(int(counts.get("byrd_signal", 0)) <= 1, "byrd_signal at most once")
	check(int(counts.get("kola_tapes", 0)) <= 1, "kola_tapes at most once")
	check_eq(int(counts.get("zz_repeat", 0)), 12 - int(counts.get("byrd_signal", 0)) - int(counts.get("kola_tapes", 0)), "the rest repeat")
	check_eq(s.encounter.used.size(), 12, "every started event is recorded in order")


func test_frozen_world_during_dialog_and_store() -> void:
	var s: Sim = _sim()
	s.push({"type": "ignite", "room": "drill", "level": 0.4})
	s.step()
	s.encounter.start_event(s, "kola_tapes")
	var fire: float = room(s, "drill").fire
	run_seconds(s, 3.0)
	check_eq(room(s, "drill").fire, fire, "fire waits while the dossier is open")
	_choose(s, 2)
	_choose(s, 0)
	s.encounter.open_store(s, "crust_trader")
	fire = room(s, "drill").fire
	run_seconds(s, 3.0)
	check_eq(room(s, "drill").fire, fire, "and while the store is open")


func test_replay_matches() -> void:
	var opts: Dictionary = {"mode": "run"}
	var s := Sim.new(db(), 21, "light_drill", opts)
	var log_starts: Dictionary = {30: "mohole_core"}
	for _t: int in range(200):
		if log_starts.has(s.tick):
			s.encounter.start_event(s, str(log_starts[s.tick]))
		if s.tick == 40:
			s.push({"type": "choose", "option": 0})
		if s.tick == 50:
			s.push({"type": "choose", "option": 0})
		s.step()
	check(s.run.knows("mohole"), "the event ran")
	check_eq(s.run.phase, "idle", "and ended")
	# Rebuild from the seed and the command log; the run module would call start_event again at
	# the same tick (it is driven by commands), so the test does the same.
	var r := Sim.new(db(), 21, "light_drill", opts)
	var i: int = 0
	while r.tick < s.tick:
		if log_starts.has(r.tick):
			r.encounter.start_event(r, str(log_starts[r.tick]))
		while i < s.command_log.size() and int(s.command_log[i]["t"]) == r.tick:
			var cmd: Dictionary = s.command_log[i].duplicate()
			cmd.erase("t")
			r.push(cmd)
			i += 1
		r.step()
	check_eq(r.state_hash(), s.state_hash(), "the replay ends in the same hash")
	check_eq(r.run.get_res("gems"), s.run.get_res("gems"), "same gems")


func test_real_events_play_through_every_option() -> void:
	var d: DataDB = db()
	for id: String in REAL:
		var ev: Dictionary = d.table("events")[id]
		var pages: Dictionary = ev["pages"]
		var reached: Dictionary = {str(ev["start"]): true}
		var opts: Array = (pages[str(ev["start"])] as Dictionary)["options"]
		for oi: int in range(opts.size()):
			for sd: int in range(1, 13):
				var s: Sim = _sim(sd, d)
				room(s, "bridge").sys_power = 2
				s.encounter.start_event(s, id)
				_choose(s, oi)
				reached[s.encounter.page] = true
				var guard: int = 0
				while s.run.phase == "dialog" and guard < 10:
					_choose(s, 0)
					guard += 1
				check_eq(s.run.phase, "idle", "%s option %d ends to idle (seed %d)" % [id, oi, sd])
				check_eq(_last_bad(s), "", "%s option %d: no refused command" % [id, oi])
		for pid: Variant in pages.keys():
			check(reached.has(str(pid)), "%s: page %s was reached" % [id, str(pid)])
