extends TestCase
## Content checks: the real data lints clean, and the lint really catches broken data.


func test_real_data_lints_clean() -> void:
	var d: DataDB = DataDB.load_all()
	var errs: PackedStringArray = d.lint()
	check(errs.is_empty(), "lint errors: " + " | ".join(errs))
	check(d.ships.has("light_drill"), "light_drill ship is present")
	check(d.ships.has("test_tower"), "test_tower ship is present")
	check(d.scenarios.has("fire_drill"), "fire_drill scenario is present")


func test_lint_names_file_and_broken_reference() -> void:
	var d: DataDB = DataDB.load_all("res://tests/fixtures/data_bad")
	var all: String = "\n".join(d.lint())
	check(all.contains("bad_ship.json"), "errors name the file")
	check(all.contains("\"cellar\" does not exist"), "a hatch to a missing room is caught")
	check(all.contains("\"attic\" does not exist"), "a crew start room that is missing is caught")
	check(all.contains("warp_core"), "an unknown system is caught")
	check(all.contains("em dash"), "an em dash in data text is caught")
	check(all.contains("missing number"), "missing tuning numbers are caught")


func test_every_tuning_number_is_used() -> void:
	var d: DataDB = DataDB.load_all()
	var used: Array[String] = []
	used.append_array(HazardSim.TUNING_KEYS)
	used.append_array(CrewAI.TUNING_KEYS)
	used.append_array(DrillSim.TUNING_KEYS)
	used.append_array(DrillSim.helm_table_keys())
	used.append_array(DrillMiner.TUNING_KEYS)
	used.append_array(Systems.TUNING_KEYS)
	used.append_array(RunState.TUNING_KEYS)
	used.append_array(CombatSim.TUNING_KEYS)
	for k: String in d.tuning.keys():
		check(used.has(k), "tuning number \"%s\" is not read by any system (typo or dead number?)" % k)


## Gemini audit: scenarios used drill.json's old rock heat slope (0.08 C per m) while runs use the
## Crust layer's (0.033). The scenario fallback must match the first layer.
func test_scenario_rock_heat_matches_the_crust() -> void:
	var d: DataDB = db()
	var crust: Dictionary = d.table("layers")["crust"]
	check_eq(d.tune("drill.rock_temp_c_per_m"), float(crust["rock_temp_c_per_m"]), "rock heat slope")
	check_eq(d.tune("drill.rock_temp_base_c"), float(crust["rock_temp_base_c"]), "rock heat at the surface")
