extends GutTest


func test_parks_raise_green_and_cut_pollution() -> void:
	var a: Simulation = SimFixture.empty_sim()
	var b: Simulation = SimFixture.empty_sim()
	for sim: Simulation in [a, b]:
		SimFixture.place(sim, "apartment_mid", Vector2i(1, 1))
		SimFixture.place(sim, "office_mid", Vector2i(2, 1))
	SimFixture.place(b, "city_park", Vector2i(1, 3))
	SimFixture.run(a, 144 * 3)
	SimFixture.run(b, 144 * 3)
	assert_gt(b.state.green, a.state.green)
	assert_lte(b.state.pollution, a.state.pollution)


func test_values_stay_in_permille_range() -> void:
	var sim: Simulation = SimFixture.new_sim()
	SimFixture.run(sim, 144 * 2)
	for v: int in [sim.state.green, sim.state.pollution, sim.state.happiness, sim.state.traffic]:
		assert_between(v, 0, 1000)
