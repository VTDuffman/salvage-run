extends GutTest
## Guards against a test script silently vanishing: GUT skips a script that
## fails to parse and still exits 0. Every test_*.gd under res://test/ must
## load, be instantiable, and extend GutTest.

const TEST_ROOT: String = "res://test/"


func test_every_test_script_loads_as_gut_test() -> void:
	var paths: Array[String] = _test_scripts(TEST_ROOT)
	assert_gt(paths.size(), 0, "no test scripts found")
	for path: String in paths:
		var script: Script = load(path) as Script
		if script == null:
			fail_test("%s did not load" % path)
			continue
		if not script.can_instantiate():
			fail_test("%s cannot be instantiated (parse error?)" % path)
			continue
		var instance: Object = script.new()
		assert_true(instance is GutTest, "%s does not extend GutTest" % path)
		instance.free()


func _test_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(dir_path):
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		found.append_array(_test_scripts(dir_path.path_join(sub)))
	return found
