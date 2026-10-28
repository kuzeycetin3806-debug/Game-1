extends GutTest


func test_place_building_spends_money_and_logs() -> void:
	var sim: Simulation = SimFixture.empty_sim(50_000)
	var r: Dictionary = SimFixture.place(sim, "cafe", Vector2i(1, 1))
	assert_true(r.ok, r.error)
	assert_eq(sim.state.money_cents, (50_000 - 9_000) * 100)
	assert_eq(sim.state.buildings.size(), 1)
	assert_eq(sim.command_log.size(), 1)
	assert_eq((r.events[0] as SimEvent).type, "building_placed")


func test_cannot_place_on_road() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	assert_eq(SimFixture.place(sim, "cafe", Vector2i(6, 3)).error, "ERR_ON_ROAD")


func test_cannot_overlap() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	assert_true(SimFixture.place(sim, "city_park", Vector2i(1, 1)).ok)
	assert_eq(SimFixture.place(sim, "cafe", Vector2i(2, 2)).error, "ERR_CELL_OCCUPIED")


func test_large_building_cannot_straddle_road() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	assert_eq(SimFixture.place(sim, "office_tower", Vector2i(5, 1)).error, "ERR_ON_ROAD")


func test_out_of_bounds() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	assert_eq(SimFixture.place(sim, "cafe", Vector2i(-1, 1)).error, "ERR_OUT_OF_BOUNDS")
	assert_eq(SimFixture.place(sim, "city_park", Vector2i(31, 31)).error, "ERR_OUT_OF_BOUNDS")


func test_not_enough_money() -> void:
	var sim: Simulation = SimFixture.empty_sim(1_000)
	assert_eq(SimFixture.place(sim, "cafe", Vector2i(1, 1)).error, "ERR_NOT_ENOUGH_MONEY")
	assert_eq(sim.command_log.size(), 0, "rejected commands are not logged")


func test_unknown_building() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	assert_eq(SimFixture.place(sim, "space_elevator", Vector2i(1, 1)).error, "ERR_UNKNOWN_BUILDING")


func test_demolish_refunds_part_of_cost() -> void:
	var sim: Simulation = SimFixture.empty_sim(50_000)
	SimFixture.place(sim, "cafe", Vector2i(1, 1))
	var id: int = sim.state.buildings[0].id
	var r: Dictionary = sim.apply_command(DemolishCommand.create(id))
	assert_true(r.ok)
	assert_eq(sim.state.buildings.size(), 0)
	assert_eq(sim.state.money_cents, (50_000 - 9_000 + 2_700) * 100)
	assert_eq(sim.grid.building_at(Vector2i(1, 1)), -1)


func test_demolish_missing_building() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	assert_eq(sim.apply_command(DemolishCommand.create(999)).error, "ERR_NO_SUCH_BUILDING")


func test_command_roundtrip() -> void:
	var c := PlaceBuildingCommand.create("cafe", Vector2i(3, 4))
	c.tick = 17
	var back: Command = Command.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_true(back is PlaceBuildingCommand)
	assert_eq(back.tick, 17)
	assert_eq((back as PlaceBuildingCommand).cell, Vector2i(3, 4))
