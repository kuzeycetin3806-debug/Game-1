extends GutTest

const FIXTURE_V1: String = "res://tests/fixtures/saves/v1_city.json"


func _played_sim() -> Simulation:
	var sim: Simulation = SimFixture.new_sim()
	SimFixture.run(sim, 40)
	SimFixture.place(sim, "metro_station", Vector2i(25, 25))
	SimFixture.run(sim, 200)
	return sim


func _roundtrip(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


func test_encode_has_required_root_fields() -> void:
	var d: Dictionary = SaveCodec.encode(_played_sim(), 1_700_000_000, "0.1.0")
	for k: String in ["save_version", "game_version", "city_seed", "last_tick", "last_wall_time", "state", "commands"]:
		assert_true(d.has(k), k)
	assert_eq(d.save_version, SaveMigrations.CURRENT)


func test_roundtrip_through_json_continues_identically() -> void:
	var sim: Simulation = _played_sim()
	var r: Dictionary = SaveCodec.decode(_roundtrip(SaveCodec.encode(sim, 1, "0.1.0")), SimFixture.content())
	assert_true(r.ok, r.error)
	var loaded: Simulation = r.sim
	assert_eq(loaded.state.hash(), sim.state.hash())
	assert_eq(loaded.command_log.size(), sim.command_log.size())
	assert_eq(loaded.event_log.events.size(), sim.event_log.events.size())
	SimFixture.run(sim, 300)
	SimFixture.run(loaded, 300)
	assert_eq(loaded.state.hash(), sim.state.hash())


func test_tampered_state_is_rejected() -> void:
	var d: Dictionary = _roundtrip(SaveCodec.encode(_played_sim(), 1, "0.1.0"))
	d.state.money_cents = 999_999_999_00
	assert_eq(SaveCodec.decode(d, SimFixture.content()).error, "ERR_SAVE_CORRUPT")


func test_missing_fields_rejected() -> void:
	var d: Dictionary = _roundtrip(SaveCodec.encode(_played_sim(), 1, "0.1.0"))
	d.erase("commands")
	assert_eq(SaveCodec.decode(d, SimFixture.content()).error, "ERR_SAVE_CORRUPT")


func test_future_version_rejected() -> void:
	var d: Dictionary = _roundtrip(SaveCodec.encode(_played_sim(), 1, "0.1.0"))
	d.save_version = SaveMigrations.CURRENT + 1
	assert_eq(SaveCodec.decode(d, SimFixture.content()).error, "ERR_SAVE_TOO_NEW")


func test_migration_chain_runs_in_order() -> void:
	var table: Dictionary = {
		1: func(d: Dictionary) -> Dictionary:
			d.trail = "a"
			return d,
		2: func(d: Dictionary) -> Dictionary:
			d.trail = String(d.trail) + "b"
			return d,
	}
	var r: Dictionary = SaveMigrations.migrate_with({"save_version": 1}, table, 3)
	assert_true(r.ok)
	assert_eq(r.data.trail, "ab")
	assert_eq(r.data.save_version, 3)
	assert_eq(r.from_version, 1)


func test_missing_migration_step_fails() -> void:
	var r: Dictionary = SaveMigrations.migrate_with({"save_version": 1}, {}, 2)
	assert_eq(r.error, "ERR_SAVE_NO_MIGRATION")


func test_v1_fixture_still_loads() -> void:
	# Frozen v1 save. If this breaks, write a migration — do not edit the fixture.
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	assert_true(d is Dictionary, "fixture missing")
	var r: Dictionary = SaveCodec.decode(d as Dictionary, SimFixture.content())
	assert_true(r.ok, r.error)
	var sim: Simulation = r.sim
	assert_gt(sim.state.buildings.size(), 10)
	SimFixture.run(sim, 144)
	assert_gt(sim.state.population, 0)


func test_v1_fixture_migrates_to_current() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	var r: Dictionary = SaveCodec.decode(d, SimFixture.content())
	assert_true(r.ok, r.error)
	assert_eq(r.migrated_from, 1)
	var s: SimState = (r.sim as Simulation).state
	assert_eq(s.weather, "clear")
	assert_eq(s.policies, {})


func test_canonical_hash_matches_state_hash() -> void:
	var sim: Simulation = _played_sim()
	var parsed: Dictionary = _roundtrip(sim.state.to_dict())
	assert_eq(SimJson.canonical_hash(parsed), sim.state.hash())


func test_meta_roundtrips_without_affecting_hash() -> void:
	var sim: Simulation = _played_sim()
	var r: Dictionary = SaveCodec.decode(_roundtrip(SaveCodec.encode(sim, 1, "0.1.0", {"read_tick": 42})), SimFixture.content())
	assert_true(r.ok)
	assert_eq(int(r.meta.read_tick), 42)
