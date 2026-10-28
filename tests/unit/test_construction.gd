extends GutTest


func test_building_completes_after_build_time() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	SimFixture.place(sim, "house_small", Vector2i(1, 1)) # 6 hours
	var b: BuildingInstance = sim.state.buildings[0]
	assert_eq(b.ready_tick, 36)
	var events: Array[SimEvent] = SimFixture.run(sim, 36)
	assert_eq(SimFixture.count(events, "building_completed"), 0)
	assert_eq(sim.aggregates.residents_capacity, 0, "homes count only when finished")
	events = SimFixture.run(sim, 1)
	assert_eq(SimFixture.count(events, "building_completed"), 1)
	assert_eq(sim.aggregates.residents_capacity, 14)


func test_starting_buildings_are_complete_and_silent() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var events: Array[SimEvent] = SimFixture.run(sim, 3)
	assert_eq(SimFixture.count(events, "building_completed"), 0)
	assert_gt(sim.aggregates.residents_capacity, 0)
	assert_gt(sim.state.population, 0, "new town starts lived-in")
