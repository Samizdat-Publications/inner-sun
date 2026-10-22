class_name Encounter
extends SimModule
## What happens at a node: dossier events with choices and weighted outcomes, and the store. Runs in
## the "dialog" and "store" phases (the world is frozen while a page or the store is open). The
## event format and the effect list are defined in docs/STYLE_GUIDE.md; effects live in
## EventEffects, the store rules in EncounterStore, the data checks in EncounterLint.
## Randomness only from the "events" and "store" streams. Holds no reference to the Sim.
##
## API the run module calls: start_node, pick_event, start_event, open_store. A buried structure's
## break-in (DrillStructures) calls pick_structure_event, start_event and open_store mid-segment:
## when that store is left or that event ends the run goes back to "drill", not "idle" (the drill is
## still active), and the segment carries on where it was.
## Commands: {"type": "choose", "option": i}, {"type": "buy", "item": i, "qty": n},
## {"type": "sell", "what": "weapon" | "gear", "id": id}, {"type": "leave"}.
## A store visit's stock is rolled when it opens (StoreRoll, "store" stream) at the ship's map row.

const COMMANDS: Array[String] = ["choose", "buy", "sell", "leave"]
const NODE_EVENT_KINDS: Array[String] = ["event", "cavern", "hazard"]
const DEFAULT_STORE: String = "crust_trader"

var db: DataDB
# Event state.
var event_id: String = ""
var page: String = ""
var picked: int = -1  ## Index into ship.crew of the crew member the event picked (-1 = none).
var used: PackedStringArray = PackedStringArray()  ## Events started this run, in order.
var pending_fight: String = ""  ## Enemy ship id a fight effect queued for when the event ends.
var pending_boss: bool = false
var pending_store: String = ""  ## Store id a store effect queued for when the event ends.
# Store state (one visit).
var store_id: String = ""
var visit: Array[Dictionary] = []  ## This visit's lines (StoreRoll.line format), rolled at open.
var purchases: PackedInt32Array = PackedInt32Array()  ## Units bought per visit line this visit.
var hire_member: String = ""  ## Pool member id the store's crew hire offers this visit.
# Crew that joined this run.
var joined: PackedStringArray = PackedStringArray()  ## Pool member ids that came aboard, in order.


func _init(p_db: DataDB) -> void:
	db = p_db


func commands() -> PackedStringArray:
	return PackedStringArray(COMMANDS)


# Run module API --------------------------------------------------------------------------------

## Start what a node holds: "event", "cavern" and "hazard" pick an event of that kind; "store" opens
## the store. Other node types hold no encounter and do nothing.
func start_node(sim: Sim, node_type: String, row: int, p_store_id: String = DEFAULT_STORE) -> void:
	if NODE_EVENT_KINDS.has(node_type):
		var id: String = pick_event(sim, node_type, row)
		if id.is_empty():
			sim.emit("no_event", {"kind": node_type, "row": row})
			return
		start_event(sim, id)
	elif node_type == "store":
		open_store(sim, p_store_id)


## A weighted pick (from the "events" stream) among events of this kind and layer whose rows hold
## `row`, skipping once_per_run events already used. Empty if none fits.
func pick_event(sim: Sim, kind: String, row: int, layer: String = "crust") -> String:
	var table: Dictionary = db.table("events")
	var ids := PackedStringArray()
	for k: Variant in table.keys():
		ids.append(str(k))
	ids.sort()  # Plain Strings: a stable order whatever order the table was filled in.
	var cands := PackedStringArray()
	var weights := PackedFloat64Array()
	var total: float = 0.0
	for id: String in ids:
		var ev: Dictionary = table[id]
		if str(ev.get("kind", "")) != kind or str(ev.get("layer", "")) != layer:
			continue
		var rows: Array = ev.get("rows", [])
		if rows.size() != 2 or row < int(rows[0]) or row > int(rows[1]):
			continue
		if bool(ev.get("once_per_run", false)) and used.has(id):
			continue
		var w: float = float(ev.get("weight", 1.0))
		if w <= 0.0:
			continue
		cands.append(id)
		weights.append(w)
		total += w
	if cands.is_empty():
		return ""
	var roll: float = sim.rng.get_stream("events").randf() * total
	for i: int in range(cands.size()):
		roll -= weights[i]
		if roll < 0.0:
			return cands[i]
	return cands[cands.size() - 1]


## A weighted pick (from `rng`, the structure's own stream) among events of kind "structure" whose
## "structures" list holds this structure id, each at most once per run. Empty if none fits.
func pick_structure_event(sim: Sim, structure_id: String, rng: RandomNumberGenerator) -> String:
	var table: Dictionary = db.table("events")
	var ids := PackedStringArray()
	for k: Variant in table.keys():
		ids.append(str(k))
	ids.sort()  # Plain Strings: a stable order whatever order the table was filled in.
	var cands := PackedStringArray()
	var weights := PackedFloat64Array()
	var total: float = 0.0
	for id: String in ids:
		var ev: Dictionary = table[id]
		if str(ev.get("kind", "")) != "structure" or used.has(id):
			continue
		if not (ev.get("structures", []) as Array).has(structure_id):
			continue
		var w: float = float(ev.get("weight", 1.0))
		if w <= 0.0:
			continue
		cands.append(id)
		weights.append(w)
		total += w
	if cands.is_empty() or sim.run.is_over():
		return ""
	var roll: float = rng.randf() * total
	for i: int in range(cands.size()):
		roll -= weights[i]
		if roll < 0.0:
			return cands[i]
	return cands[cands.size() - 1]


## Open an event's start page: picks its crew member and enters the "dialog" phase.
func start_event(sim: Sim, p_event_id: String) -> void:
	var ev: Dictionary = db.table("events").get(p_event_id, {})
	if ev.is_empty():
		push_error("Encounter.start_event: unknown event \"%s\"" % p_event_id)
		return
	if is_busy():
		push_error("Encounter.start_event: \"%s\" while \"%s%s\" is still open" % [p_event_id, event_id, store_id])
		return
	event_id = p_event_id
	page = str(ev.get("start", ""))
	pending_fight = ""
	pending_boss = false
	pending_store = ""
	used.append(p_event_id)
	picked = _pick_crew(sim, str(ev.get("crew", "first")))
	sim.run.set_phase(sim, "dialog")
	sim.emit("event_started", {"event": p_event_id, "page": page})


## Open a store for one visit: phase "store", purchase counts reset, the crew hire rolled.
func open_store(sim: Sim, p_store_id: String) -> void:
	var st: Dictionary = db.table("stores").get(p_store_id, {})
	if st.is_empty():
		push_error("Encounter.open_store: unknown store \"%s\"" % p_store_id)
		return
	if not event_id.is_empty() or not store_id.is_empty():
		push_error("Encounter.open_store: \"%s\" while something else is open" % p_store_id)
		return
	store_id = p_store_id
	visit = StoreRoll.roll(sim, st, sim.run.current_row(), sim.run.map.size())
	purchases = PackedInt32Array()
	purchases.resize(visit.size())
	hire_member = ""
	# The hire is rolled for the store's first crew pool whether or not its section showed, so the
	# number of draws does not depend on the section roll.
	var crew_pool: String = _crew_pool(st)
	if not crew_pool.is_empty():
		hire_member = EventEffects.roll_member(sim, self, crew_pool, "store")
	sim.run.set_phase(sim, "store")
	sim.emit("store_opened", {"store": p_store_id})


static func _crew_pool(st: Dictionary) -> String:
	for sv: Variant in st.get("sections", []):
		for line: Variant in ((sv as Dictionary).get("pool", []) as Array):
			if str((line as Dictionary).get("item", "")) == "crew":
				return str((line as Dictionary).get("pool", ""))
	return ""


func _close_store() -> void:
	store_id = ""
	visit = []
	purchases = PackedInt32Array()
	hire_member = ""


func is_busy() -> bool:
	return not event_id.is_empty() or not store_id.is_empty()


# Commands --------------------------------------------------------------------------------------

func apply(sim: Sim, cmd: Dictionary) -> void:
	var kind: String = str(cmd.get("type", ""))
	match kind:
		"choose":
			_choose(sim, int(cmd.get("option", -1)))
		"buy":
			EncounterStore.buy(sim, self, int(cmd.get("item", -1)), int(cmd.get("qty", 1)))
		"sell":
			EncounterStore.sell(sim, self, str(cmd.get("what", "")), str(cmd.get("id", "")))
		"leave":
			if store_id.is_empty() or sim.run.phase != "store":
				_bad(sim, "leave", "no store is open")
				return
			sim.emit("store_closed", {"store": store_id})
			_close_store()
			_to_idle(sim)


func _choose(sim: Sim, option: int) -> void:
	if event_id.is_empty() or sim.run.phase != "dialog":
		_bad(sim, "choose", "no event is open")
		return
	var pg: Dictionary = current_page()
	var options: Array = pg.get("options", [])
	if options.is_empty():
		if option != 0:
			_bad(sim, "choose", "this page only continues (option 0)")
			return
		_end_event(sim)
		return
	if option < 0 or option >= options.size():
		_bad(sim, "choose", "no option %d" % option)
		return
	var opt: Dictionary = options[option]
	var why: String = EventEffects.requirement_failure(sim, opt.get("requires", {}))
	if not why.is_empty():
		_bad(sim, "choose", why)
		return
	var outcome: Dictionary = _roll_outcome(sim, opt.get("outcomes", []))
	sim.emit("event_choice", {"event": event_id, "page": page, "option": option})
	for e: Variant in outcome.get("effects", []):
		EventEffects.apply(sim, self, e as Dictionary)
	var next: String = str(outcome.get("page", ""))
	if next.is_empty() or sim.run.is_over():
		_end_event(sim)
		return
	page = next
	sim.emit("event_page", {"event": event_id, "page": page})


func _roll_outcome(sim: Sim, outcomes: Array) -> Dictionary:
	if outcomes.is_empty():
		return {}
	if outcomes.size() == 1:
		return outcomes[0]
	var total: float = 0.0
	for o: Variant in outcomes:
		total += maxf(0.0, float((o as Dictionary).get("weight", 0.0)))
	var roll: float = sim.rng.get_stream("events").randf() * total
	for o: Variant in outcomes:
		roll -= maxf(0.0, float((o as Dictionary).get("weight", 0.0)))
		if roll < 0.0:
			return o
	return outcomes[outcomes.size() - 1]


## Close the event; a queued fight or store takes over, otherwise back to idle.
func _end_event(sim: Sim) -> void:
	sim.emit("event_ended", {"event": event_id})
	event_id = ""
	page = ""
	picked = -1
	var fight: String = pending_fight
	var boss: bool = pending_boss
	var store: String = pending_store
	pending_fight = ""
	pending_boss = false
	pending_store = ""
	if sim.run.is_over():
		return
	if not fight.is_empty():
		sim.combat.start_fight(sim, fight, boss)
		if sim.run.phase == "dialog":
			_to_idle(sim)  # The combat stub leaves scenario mode untouched.
	elif not store.is_empty():
		open_store(sim, store)
	else:
		_to_idle(sim)


## Back to "idle", or to "drill" when a structure opened this mid-segment (the drill is still active).
func _to_idle(sim: Sim) -> void:
	if not sim.run.is_over():
		sim.run.set_phase(sim, "drill" if sim.drill.active else "idle")


func _bad(sim: Sim, kind: String, why: String) -> void:
	sim.emit("bad_command", {"type": kind, "why": why})


## A run that ends while a page is open (the crew died, the hull failed) closes the page.
func step(sim: Sim) -> void:
	if sim.run.is_over() and is_busy():
		event_id = ""
		page = ""
		picked = -1
		_close_store()


# Reading (for the view and bots) ---------------------------------------------------------------

func current_event() -> Dictionary:
	return db.table("events").get(event_id, {})


func current_page() -> Dictionary:
	var pages: Dictionary = current_event().get("pages", {})
	return pages.get(page, {})


## The open store: {"id", "name", "blurb", "stock": this visit's lines} ({} when none is open).
## "stock" is the live visit array (read it, never change it: buy and sell are commands).
func current_store() -> Dictionary:
	var st: Dictionary = db.table("stores").get(store_id, {})
	if st.is_empty():
		return {}
	return {"id": store_id, "name": str(st.get("name", "")), "blurb": str(st.get("blurb", "")), "stock": visit}


## Why option i on the open page cannot be chosen right now ("" = it can).
func option_block(sim: Sim, option: int) -> String:
	var options: Array = current_page().get("options", [])
	if option < 0 or option >= options.size():
		return "no such option"
	var opt: Dictionary = options[option]
	return EventEffects.requirement_failure(sim, opt.get("requires", {}))


## Page or option text with {crew} replaced by the picked crew member's name. Redactions
## ([[codex:words]]) are left for the view, which knows how to draw them.
func fill_text(sim: Sim, text: String) -> String:
	var who: String = "the crew"
	if picked >= 0 and picked < sim.ship.crew.size():
		who = sim.ship.crew[picked].name
	return text.replace("{crew}", who)


func _pick_crew(sim: Sim, rule: String) -> int:
	var alive := PackedInt32Array()
	for c: CrewMember in sim.ship.crew:
		if c.alive:
			alive.append(c.index)
	if alive.is_empty():
		return -1
	if rule == "random":
		return alive[sim.rng.get_stream("events").randi_range(0, alive.size() - 1)]
	if rule.begins_with("skill:"):
		var skill: String = rule.substr(6)
		var best: int = alive[0]
		for i: int in alive:
			if EventEffects.skill_of(sim.ship.crew[i], skill) > EventEffects.skill_of(sim.ship.crew[best], skill):
				best = i
		return best
	return alive[0]


func state() -> Array:
	var lines: Array = []
	for d: Dictionary in visit:
		lines.append([str(d["section"]), str(d["item"]), str(d["res"]), str(d["system"]), str(d["gear"]),
			str(d["weapon"]), str(d["pool"]), int(d["price"]), str(d["currency"]), int(d["stock"])])
	return [event_id, page, picked, Array(used), pending_fight, pending_boss, pending_store,
		store_id, Array(purchases), hire_member, Array(joined), lines]


static func lint(p_db: DataDB, errs: PackedStringArray) -> void:
	EncounterLint.lint(p_db, errs)
