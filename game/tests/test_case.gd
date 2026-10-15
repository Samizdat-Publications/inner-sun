class_name TestCase
extends RefCounted
## Base for tests. Checks record failures in `failures` (the runner reads them) instead of stopping,
## so one test reports everything that is wrong with it.

var failures: PackedStringArray = PackedStringArray()


func check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func check_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		failures.append("%s: got %s, want %s" % [what, str(got), str(want)])


func check_gt(got: float, than: float, what: String) -> void:
	if not (got > than):
		failures.append("%s: got %s, wanted more than %s" % [what, str(got), str(than)])


func check_lt(got: float, than: float, what: String) -> void:
	if not (got < than):
		failures.append("%s: got %s, wanted less than %s" % [what, str(got), str(than)])


## A fresh content database, with tuning numbers overridden for this test only.
func db(overrides: Dictionary = {}) -> DataDB:
	var d: DataDB = DataDB.load_all()
	for k: String in overrides.keys():
		d.tuning[k] = float(overrides[k])
	return d


func run_seconds(s: Sim, seconds: float) -> void:
	for i: int in range(roundi(seconds * Sim.TICK_HZ)):
		s.step()


func room(s: Sim, room_id: String) -> Room:
	return s.ship.rooms[s.ship.room_index(room_id)]


func has_event(s: Sim, kind: String) -> bool:
	for e: Dictionary in s.events:
		if str(e["kind"]) == kind:
			return true
	return false


func crew_auto_off(s: Sim) -> void:
	for c: CrewMember in s.ship.crew:
		s.push({"type": "auto", "crew": c.id, "on": false})
