extends GutTest


func test_population_grows_towards_target_and_respects_capacity() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	SimFixture.place(sim, "apartment_mid", Vector2i(1, 1))
	SimFixture.place(sim, "office_mid", Vector2i(2, 1))
	SimFixture.run(sim, 2 * 144)
	var cap: int = sim.aggregates.residents_capacity
	assert_gt(sim.state.population, cap / 3)
	assert_lte(sim.state.population, cap)


func test_happier_city_targets_more_residents() -> void:
	var c: ContentDb = SimFixture.content()
	assert_gt(PopulationSystem.target(1000, 900, c), PopulationSystem.target(1000, 300, c))
	assert_eq(PopulationSystem.target(0, 900, c), 0)


func test_employment_limited_by_jobs() -> void:
	var sim: Simulation = SimFixture.empty_sim()
	SimFixture.place(sim, "apartment_mid", Vector2i(1, 1))
	SimFixture.place(sim, "cafe", Vector2i(2, 1))
	SimFixture.run(sim, 3 * 144)
	assert_lte(sim.state.employed, sim.aggregates.jobs_total)
	assert_gt(PopulationSystem.unemployment_permille(sim.state, sim.content), 0)
