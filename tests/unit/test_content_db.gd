extends GutTest


func _valid_building(id: String = "test_house") -> Dictionary:
	return {
		"id": id, "version": 1, "name_key": "BLD_TEST", "category": "residential", "size": 1,
		"cost": 100, "upkeep_per_day": 1, "build_hours": 1, "residents": 10,
		"visual": {"kind": "building", "height": 5.0},
	}


func _map(starting: Array = []) -> Dictionary:
	return {"grid_size": 32, "road_every": 6, "starting_buildings": starting}


func _balance() -> Dictionary:
	return {"start_money": 1000, "tax_per_worker_per_day": 1, "workforce_permille": 600}


func test_default_content_is_valid() -> void:
	var db: ContentDb = ContentDb.load_default()
	assert_eq(db.errors, [] as Array[String])
	assert_gt(db.buildings.size(), 5)


func test_every_building_has_translation_key_format() -> void:
	var db: ContentDb = ContentDb.load_default()
	for id: String in db.building_order:
		assert_string_starts_with(db.get_building(id).name_key, "BLD_")


func test_missing_field_reported() -> void:
	var d: Dictionary = _valid_building()
	d.erase("cost")
	var db: ContentDb = ContentDb.from_dicts([d], _balance(), _map())
	assert_eq(db.errors.size(), 1)
	assert_string_contains(db.errors[0], "cost")


func test_bad_id_and_category_reported() -> void:
	var d: Dictionary = _valid_building("Bad-Id")
	d.category = "spaceport"
	var db: ContentDb = ContentDb.from_dicts([d], _balance(), _map())
	assert_eq(db.errors.size(), 2)


func test_duplicate_id_reported() -> void:
	var db: ContentDb = ContentDb.from_dicts([_valid_building(), _valid_building()], _balance(), _map())
	assert_eq(db.errors.size(), 1)
	assert_string_contains(db.errors[0], "duplicate")


func test_unknown_starting_building_reported() -> void:
	var db: ContentDb = ContentDb.from_dicts([_valid_building()], _balance(), _map([{"def": "nope", "cell": [1, 1]}]))
	assert_false(db.is_valid())


func test_bal_path_lookup() -> void:
	var db: ContentDb = ContentDb.load_default()
	assert_gt(db.bal_int("population.move_divisor"), 0)
	assert_eq(db.bal_int("does.not.exist", 7), 7)
