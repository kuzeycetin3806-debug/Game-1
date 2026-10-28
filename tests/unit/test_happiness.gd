extends GutTest


func test_amenities_raise_happiness_target() -> void:
	var a: Simulation = SimFixture.empty_sim()
	var b: Simulation = SimFixture.empty_sim()
	for sim: Simulation in [a, b]:
		SimFixture.place(sim, "apartment_mid", Vector2i(1, 1))
		SimFixture.place(sim, "office_mid", Vector2i(2, 1))
	SimFixture.place(b, "cafe", Vector2i(1, 2))
	SimFixture.place(b, "pocket_park", Vector2i(2, 2))
	SimFixture.run(a, 144 * 2)
	SimFixture.run(b, 144 * 2)
	assert_gt(b.state.happiness, a.state.happiness)


func test_traffic_lowers_target() -> void:
	var sim: Simulation = SimFixture.new_sim()
	SimFixture.run(sim, 10)
	var s: SimState = sim.state
	s.traffic = 0
	var calm: int = HappinessSystem.target(s, sim.aggregates, sim.content)
	s.traffic = 1000
	var jammed: int = HappinessSystem.target(s, sim.aggregates, sim.content)
	assert_eq(calm - jammed, 220)


func test_happiness_moves_slowly() -> void:
	var sim: Simulation = SimFixture.new_sim()
	sim.state.happiness = 0
	sim.step()
	assert_lt(sim.state.happiness, 100, "one tick should not swing the mood")
