extends GutTest


func test_open_letters_and_pending_policy_show_up() -> void:
	var sim: Simulation = SimFixture.new_sim()
	sim.apply_command(ChoosePolicyCommand.create("night_market", true))
	sim.state.letters.append({"id": 1, "citizen": sim.state.citizens[0].id, "topic": "park_request", "tone": "request", "tick": 0, "status": "open"})
	var items: Array[Dictionary] = Agenda.items(sim)
	var keys: Array = items.map(func(i: Dictionary) -> String: return String(i.key))
	assert_true(keys.has("AGENDA_LETTERS"))
	assert_true(keys.has("AGENDA_POLICY_PENDING"))
	assert_eq(String(items[0].action), "mailbox")


func test_weakest_spot_priorities() -> void:
	var sim: Simulation = SimFixture.new_sim()
	sim.state.money_cents = -1
	assert_eq(String(Agenda.weakest_spot(sim).key), "AGENDA_TIP_BUDGET")
	sim.state.money_cents = 100
	sim.state.traffic = 600
	assert_eq(String(Agenda.weakest_spot(sim).action), "decisions")
	sim.state.traffic = 0
	sim.state.green = 100
	sim.state.employed = sim.state.population * 6 / 10
	assert_eq(String(Agenda.weakest_spot(sim).action), "build:park")


func test_items_are_capped() -> void:
	var sim: Simulation = SimFixture.new_sim()
	sim.state.money_cents = 10_000_000_00
	for id: String in ["night_market", "bike_lanes", "green_roofs", "tax_relief"]:
		sim.apply_command(ChoosePolicyCommand.create(id, true))
	assert_lte(Agenda.items(sim).size(), Agenda.MAX_ITEMS)
