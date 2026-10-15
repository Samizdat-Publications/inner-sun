extends TestCase
## Project-level guards: every script compiles, strict typing is on, and the settings the autonomous
## loop depends on have not drifted.

const SKIP_DIRS: Array[String] = ["fixtures", "addons"]


func test_every_script_compiles() -> void:
	for path: String in _scripts("res://"):
		var s: Variant = load(path)
		check(s is GDScript, "compiles: " + path)


func test_strict_typing_is_enforced() -> void:
	check_eq(int(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration", 0)), 2, "untyped code is a compile error")


func test_loop_settings_are_in_place() -> void:
	check_eq(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 0)), Sim.TICK_HZ, "physics tick matches the sim tick")
	check_eq(str(ProjectSettings.get_setting("rendering/rendering_device/driver.windows", "")), "vulkan", "Vulkan on Windows")
	check_eq(bool(ProjectSettings.get_setting("rendering/rendering_device/fallback_to_d3d12", true)), false, "no silent fallback to D3D12")
	check_eq(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)), true, "own user folder, never shared with other projects")
	check_eq(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")), "InnerSun", "user folder name")


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if not SKIP_DIRS.has(d):
			out.append_array(_scripts(dir.path_join(d)))
	return out
