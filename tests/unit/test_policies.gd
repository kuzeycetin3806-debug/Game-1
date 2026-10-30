extends GutTest


func _sim() -> Simulation:
	var sim: Simulation = SimFixture.quiet_sim()
	sim.state.money_cents = 1_000_000 * 100
	sim.state.population = 1000
	return sim


func test_enact_costs_money_and_takes_effect_after_delay() -> void:
	var sim: Simulation = _sim()
	var before: int = sim.state.money_cents
	var r: Dictionary = sim.apply_command(ChoosePolicyCommand.create("bike_lanes", true))
	assert_true(r.ok, r.error)
	assert_eq(before - sim.state.money_cents, 30_000 * 100)
	assert_eq((r.events[0] as SimEvent).type, "policy_enacted")
	assert_eq(int(ModifierSet.collect(sim.state, sim.content).traffic_relief), 0, "not yet")
	var events: Array[SimEvent] = SimFixture.run(sim, 72 * 6 + 1)
	assert_eq(SimFixture.count(events, "policy_took_effect"), 1)
	assert_eq(int(ModifierSet.collect(sim.state, sim.content).traffic_relief), 120)


func test_daily_cost_starts_at_once() -> void:
	var sim: Simulation = _sim()
	sim.apply_command(ChoosePolicyCommand.create("free_transit", true))
	assert_eq(int(ModifierSet.collect(sim.state, sim.content).daily_cost), 1500)


func test_conflicts_and_duplicates_rejected() -> void:
	var sim: Simulation = _sim()
	assert_true(sim.apply_command(ChoosePolicyCommand.create("tax_relief", true)).ok)
	assert_eq(sim.apply_command(ChoosePolicyCommand.create("tax_relief", true)).error, "ERR_POLICY_ACTIVE")
	assert_eq(sim.apply_command(ChoosePolicyCommand.create("tax_hike", true)).error, "ERR_POLICY_CONFLICT")


func test_repeal() -> void:
	var sim: Simulation = _sim()
	assert_eq(sim.apply_command(ChoosePolicyCommand.create("night_market", false)).error, "ERR_POLICY_NOT_ACTIVE")
	sim.apply_command(ChoosePolicyCommand.create("night_market", true))
	var r: Dictionary = sim.apply_command(ChoosePolicyCommand.create("night_market", false))
	assert_true(r.ok)
	assert_false(sim.state.policies.has("night_market"))


func test_min_population() -> void:
	var sim: Simulation = _sim()
	sim.state.population = 10
	assert_eq(sim.apply_command(ChoosePolicyCommand.create("free_transit", true)).error, "ERR_POLICY_TOO_SMALL")


func test_tax_relief_raises_happiness_over_days() -> void:
	var a: Simulation = SimFixture.new_sim()
	var b: Simulation = SimFixture.new_sim()
	b.apply_command(ChoosePolicyCommand.create("tax_relief", true))
	SimFixture.run(a, 144 * 4)
	SimFixture.run(b, 144 * 4)
	assert_gt(b.state.happiness, a.state.happiness)


func test_policy_command_replays() -> void:
	var sim: Simulation = SimFixture.new_sim()
	SimFixture.run(sim, 10)
	sim.apply_command(ChoosePolicyCommand.create("bike_lanes", true))
	SimFixture.run(sim, 500)
	assert_true(sim.verify_replay())
