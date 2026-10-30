extends GutTest
## Guards against a Godot 4.4.1 engine bug we hit in M4: iterating (or
## reading) a const typed Array from per-tick static code corrupted the heap
## ("double free"), randomly and far from the cause. Rule: no const Array /
## Dictionary in sim/ except in load-time validation files.

const ALLOWED: Array[String] = [
	"res://sim/events/event_schema.gd",
	"res://sim/content/policy_schema.gd",
	"res://sim/content/building_def.gd",
	"res://sim/systems/modifier_set.gd", # STATS: validation only
]


func _sim_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_sim_files(dir.path_join(d)))
	return out


func test_no_const_containers_in_sim_hot_code() -> void:
	var decl := RegEx.create_from_string("(?m)^const [A-Z_0-9]+\\s*:\\s*(Array|Dictionary)")
	var offenders: Array[String] = []
	for path: String in _sim_files("res://sim"):
		if ALLOWED.has(path):
			continue
		if decl.search(FileAccess.get_file_as_string(path)) != null:
			offenders.append(path)
	assert_eq(offenders, [] as Array[String], "const Array/Dictionary in sim hot code")


func test_no_loops_over_constants_in_sim() -> void:
	var loop := RegEx.create_from_string("for [a-z_]+(\\s*:\\s*\\w+)? in [A-Z][A-Z_0-9]*\\s*:")
	var offenders: Array[String] = []
	for path: String in _sim_files("res://sim"):
		if loop.search(FileAccess.get_file_as_string(path)) != null:
			offenders.append(path)
	assert_eq(offenders, [] as Array[String])
