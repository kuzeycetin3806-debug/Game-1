extends GutTest

var _old_dir: String


func before_each() -> void:
	_old_dir = SaveService.save_dir
	SaveService.save_dir = "user://test_saves/service"
	SaveService.delete_all()


func after_each() -> void:
	SaveService.delete_all()
	SaveService.save_dir = _old_dir


func _sim() -> Simulation:
	var sim: Simulation = SimFixture.new_sim()
	SimFixture.run(sim, 20)
	return sim


func test_save_and_load() -> void:
	var sim: Simulation = _sim()
	assert_eq(SaveService.save(sim), OK)
	assert_true(FileAccess.file_exists(SaveService.main_path()))
	assert_false(FileAccess.file_exists(SaveService.temp_path()), "tmp is renamed away")
	var r: Dictionary = SaveService.load_city(SimFixture.content())
	assert_true(r.ok, r.error)
	assert_false(r.recovered)
	assert_eq((r.sim as Simulation).state.hash(), sim.state.hash())


func test_second_save_keeps_backup_of_first() -> void:
	var sim: Simulation = _sim()
	SaveService.save(sim)
	var first: int = sim.state.hash()
	SimFixture.run(sim, 5)
	SaveService.save(sim)
	var bak: Dictionary = SaveCodec.decode(JSON.parse_string(FileAccess.get_file_as_string(SaveService.backup_path())), SimFixture.content())
	assert_eq((bak.sim as Simulation).state.hash(), first)


func test_corrupt_main_recovers_from_backup() -> void:
	var sim: Simulation = _sim()
	SaveService.save(sim)
	SimFixture.run(sim, 5)
	SaveService.save(sim)
	var f: FileAccess = FileAccess.open(SaveService.main_path(), FileAccess.WRITE)
	f.store_string("{\"save_version\": 1, \"state\": tru") # truncated write
	f.close()
	var r: Dictionary = SaveService.load_city(SimFixture.content())
	assert_true(r.ok, r.error)
	assert_true(r.recovered)


func test_both_broken_reports_error() -> void:
	DirAccess.make_dir_recursive_absolute(SaveService.save_dir)
	for p: String in [SaveService.main_path(), SaveService.backup_path()]:
		var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
		f.store_string("not json")
		f.close()
	var r: Dictionary = SaveService.load_city(SimFixture.content())
	assert_false(r.ok)
	assert_eq(r.error, "ERR_SAVE_CORRUPT")


func test_missing_save() -> void:
	assert_false(SaveService.has_save())
	assert_eq(SaveService.load_city(SimFixture.content()).error, "ERR_SAVE_MISSING")
