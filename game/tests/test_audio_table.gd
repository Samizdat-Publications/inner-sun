extends TestCase
## The audio table points at real files, covers the sim events that matter, and the director stays
## silent (no players, no buses) under the headless display server.

const REQUIRED_KEYS: Array[String] = [
	"pocket_burst", "bit_change_started", "bit_broken", "power_cut", "system_damaged", "crew_died",
	"breach", "resource_hull_loss", "phase_dead", "fight_start", "projectile_hit",
]


func test_every_sound_file_exists_and_loads() -> void:
	for stem: String in SoundTable.all_stems():
		var path: String = SoundTable.path_of(stem)
		check(ResourceLoader.exists(path), "sound file exists: " + path)
		var s: AudioStream = load(path) as AudioStream
		check(s != null, "sound loads as an AudioStream: " + path)


func test_table_covers_listed_events() -> void:
	for k: String in REQUIRED_KEYS:
		check(SoundTable.EVENTS.has(k), "event table has " + k)
	for k: String in SoundTable.EVENTS.keys():
		var d: Dictionary = SoundTable.EVENTS[k]
		check(SoundTable.BUS_DB.has(str(d["bus"])), "known bus for " + k)
		check(float(d["db"]) <= 6.0, "one-shot level sane for " + k)


func test_event_keys() -> void:
	check_eq(SoundTable.key_for({"kind": "resource", "res": "hull", "amount": -2}), "resource_hull_loss", "hull loss key")
	check_eq(SoundTable.key_for({"kind": "resource", "res": "hull", "amount": 2}), "", "hull gain is silent")
	check_eq(SoundTable.key_for({"kind": "resource", "res": "ore", "amount": -2}), "", "ore spend is silent")
	check_eq(SoundTable.key_for({"kind": "phase", "to": "dead"}), "phase_dead", "phase key")
	check_eq(SoundTable.key_for({"kind": "breach"}), "breach", "plain kind")


func test_grind_crossfade() -> void:
	check_eq(AudioDirector.grind_weights(0.0), Vector3.ZERO, "air makes no grind")
	check_eq(AudioDirector.grind_weights(0.8), Vector3(1.0, 0.0, 0.0), "shale is soft")
	check_eq(AudioDirector.grind_weights(1.8), Vector3(0.0, 1.0, 0.0), "gneiss is hard")
	var basalt: Vector3 = AudioDirector.grind_weights(4.0)
	check_eq(basalt, Vector3(0.0, 0.0, 1.0), "basalt squeals")
	var mid: Vector3 = AudioDirector.grind_weights(1.5)
	check_gt(mid.x, 0.0, "mid hardness blends soft")
	check_gt(mid.y, 0.0, "mid hardness blends hard")
	check_lt(absf(mid.x + mid.y + mid.z - 1.0), 0.0001, "weights sum to one")


func test_pursuer_intensity() -> void:
	var s := Sim.new(db(), 3, "test_tower")
	check_eq(AudioDirector.pursuer_intensity(s), 0.0, "scenario mode is silent")


func test_headless_director_makes_no_players() -> void:
	var s := Sim.new(db(), 3, "test_tower")
	var d := AudioDirector.new()
	var buses: int = AudioServer.bus_count
	d.bind(s)
	if AudioDirector.is_headless():
		check_eq(d.player_count(), 0, "no audio players under the headless display server")
		check_eq(AudioServer.bus_count, buses, "no buses created under the headless display server")
	d.free()
