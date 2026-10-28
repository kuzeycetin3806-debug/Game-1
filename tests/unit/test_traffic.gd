extends GutTest


func test_demand_curve_has_rush_hours() -> void:
	var c: ContentDb = SimFixture.content()
	assert_eq(TrafficSystem.demand(480, c), 1000)
	assert_eq(TrafficSystem.demand(1050, c), 1000)
	assert_lt(TrafficSystem.demand(180, c), 150)
	assert_eq(TrafficSystem.demand(450, c), 760)


func test_rush_hour_busier_than_night() -> void:
	var sim: Simulation = SimFixture.new_sim()
	# Tick 0 is 03:00 local. Run to 08:00 (30 ticks) and to 03:00 next day.
	SimFixture.run(sim, 30)
	var rush: int = sim.state.traffic
	SimFixture.run(sim, 114)
	var night: int = sim.state.traffic
	assert_gt(rush, night * 3)


func test_metro_relieves_its_district() -> void:
	var a: Simulation = SimFixture.empty_sim(2_000_000)
	var b: Simulation = SimFixture.empty_sim(2_000_000)
	for sim: Simulation in [a, b]:
		SimFixture.place(sim, "office_tower", Vector2i(1, 1))
		SimFixture.place(sim, "residential_tower", Vector2i(3, 1))
	SimFixture.place(b, "metro_station", Vector2i(1, 4))
	# Metro takes 72 h to build; measure at 08:00 on day 6 once everyone moved in.
	SimFixture.run(a, 144 * 5 + 30)
	SimFixture.run(b, 144 * 5 + 30)
	assert_gt(int(a.state.block_traffic.get("0,0", 0)), 0)
	assert_lt(int(b.state.block_traffic.get("0,0", 0)), int(a.state.block_traffic.get("0,0", 0)))
