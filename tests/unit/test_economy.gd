extends GutTest


func test_daily_accrual_is_exact() -> void:
	var sim: Simulation = SimFixture.new_sim()
	SimFixture.run(sim, 144 * 3) # settle population
	var agg: CityAggregates = sim.aggregates
	# Freeze population so income per day is constant for the check.
	var s: SimState = sim.state
	var expected_income: int = EconomySystem.daily_income(s, agg, sim.content) * 100
	var expected_expense: int = agg.upkeep_per_day * 100
	var inc0: int = 0
	var exp0: int = 0
	s.income_frac = 0
	s.expense_frac = 0
	for i: int in 144:
		var before: int = s.money_cents
		var di: int = s.day_income_cents
		var de: int = s.day_expense_cents
		EconomySystem.step(s, agg, sim.content)
		inc0 += s.day_income_cents - di
		exp0 += s.day_expense_cents - de
		assert_eq(s.money_cents - before, (s.day_income_cents - di) - (s.day_expense_cents - de))
	assert_eq(inc0, expected_income)
	assert_eq(exp0, expected_expense)


func test_upkeep_charged_while_under_construction() -> void:
	var sim: Simulation = SimFixture.empty_sim(500_000)
	SimFixture.place(sim, "metro_station", Vector2i(1, 1))
	var before: int = sim.state.money_cents
	SimFixture.run(sim, 144)
	assert_eq(before - sim.state.money_cents, 700 * 100)


func test_day_started_reports_yesterday() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var events: Array[SimEvent] = SimFixture.run(sim, 144 * 2)
	assert_eq(SimFixture.count(events, "day_started"), 2)
	for e: SimEvent in events:
		if e.type == "day_started":
			assert_true(e.data.has("income") and e.data.has("population"))
