extends GutTest


func test_new_town_has_named_citizens_deterministically() -> void:
	var a: Simulation = SimFixture.new_sim()
	var b: Simulation = SimFixture.new_sim()
	assert_eq(a.state.citizens.size(), CitizenSystem.target_count(a))
	assert_gte(a.state.citizens.size(), 6)
	assert_eq(a.state.citizens[0].full_name(), b.state.citizens[0].full_name())
	var c: Citizen = a.state.citizens[0]
	assert_ne(c.home_block, "")
	assert_false(c.interests.is_empty())
	assert_true(c.traits.has("civic"))


func test_citizens_grow_with_population_at_midnight() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var before: int = sim.state.citizens.size()
	sim.state.money_cents = 5_000_000 * 100
	SimFixture.place(sim, "residential_tower", Vector2i(25, 25))
	SimFixture.place(sim, "office_tower", Vector2i(25, 19))
	SimFixture.run(sim, 144 * 6)
	assert_gt(sim.state.citizens.size(), before)
	# Counted at midnight and nobody is ever removed, so it may exceed a later target.
	assert_gte(sim.state.citizens.size(), CitizenSystem.target_count(sim) - 1)


func test_mood_follows_interests() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var driver := Citizen.new()
	driver.interests = ["traffic"]
	var gardener := Citizen.new()
	gardener.interests = ["parks"]
	sim.state.traffic = 900
	sim.state.green = 900
	assert_lt(CitizenSystem.mood_target(sim, driver), CitizenSystem.mood_target(sim, gardener))


func test_decisions_are_remembered_by_those_who_care() -> void:
	var sim: Simulation = SimFixture.new_sim()
	SimFixture.place(sim, "pocket_park", Vector2i(25, 25))
	var lovers: int = 0
	for c: Citizen in sim.state.citizens:
		var remembers: bool = not c.memory.is_empty() and String(c.memory[-1].kind) == "building_placed"
		if c.has_interest(["parks", "kids", "environment"]):
			assert_true(remembers, "%s cares about parks" % c.full_name())
			assert_gt(int(c.memory[-1].valence), 0)
			lovers += 1
		else:
			assert_false(remembers)
	assert_gt(lovers, 0, "fixture town should have some park lovers")


func test_memory_is_bounded() -> void:
	var c := Citizen.new()
	for i: int in 20:
		c.remember({"tick": i, "kind": "x", "ref": "", "valence": i}, 6)
	assert_eq(c.memory.size(), 6)
	assert_eq(int(c.memory[0].tick), 14)


func test_letters_arrive_and_respect_limits() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var events: Array[SimEvent] = SimFixture.run(sim, 144 * 14)
	var received: int = SimFixture.count(events, "letter_received")
	assert_gt(received, 3, "two weeks should bring several letters")
	assert_lte(CitizenSystem.open_letters(sim.state), sim.content.bal_int("citizens.max_open_letters"))
	for raw: Variant in sim.state.letters:
		var l: Dictionary = raw
		var c: Citizen = CitizenSystem.citizen_by_id(sim.state, int(l.citizen))
		assert_true(c.has_interest(CitizenSystem.topic_def(sim, String(l.topic)).interests), "writer cares about the topic")


func test_unanswered_letters_expire_and_sting() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var events: Array[SimEvent] = SimFixture.run(sim, 144 * 14)
	assert_gt(SimFixture.count(events, "letter_expired"), 0)
	var stung: bool = false
	for c: Citizen in sim.state.citizens:
		for m: Variant in c.memory:
			if String((m as Dictionary).kind) == "letter_ignored":
				stung = true
	assert_true(stung)


func _first_open_letter(sim: Simulation) -> Dictionary:
	for i: int in 144 * 10:
		sim.step()
		for raw: Variant in sim.state.letters:
			if String((raw as Dictionary).status) == "open":
				return raw
	return {}


func test_reply_applies_option_and_is_remembered() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var l: Dictionary = _first_open_letter(sim)
	assert_false(l.is_empty(), "a letter should arrive within 10 days")
	var topic: Dictionary = CitizenSystem.topic_def(sim, String(l.topic))
	var opt: String = String(topic.options[0].id)
	var c: Citizen = CitizenSystem.citizen_by_id(sim.state, int(l.citizen))
	var r: Dictionary = sim.apply_command(ReplyLetterCommand.create(int(l.id), opt))
	assert_true(r.ok, r.error)
	assert_eq(String(l.status), "answered")
	assert_eq(String(l.reply), opt)
	assert_eq(String(c.memory[-1].kind), "letter_answered")
	assert_eq(sim.apply_command(ReplyLetterCommand.create(int(l.id), opt)).error, "ERR_LETTER_CLOSED")


func test_reply_validation() -> void:
	var sim: Simulation = SimFixture.new_sim()
	assert_eq(sim.apply_command(ReplyLetterCommand.create(999, "x")).error, "ERR_NO_SUCH_LETTER")
	var l: Dictionary = _first_open_letter(sim)
	assert_eq(sim.apply_command(ReplyLetterCommand.create(int(l.id), "nope")).error, "ERR_UNKNOWN_REPLY")


func test_city_with_letters_and_replies_replays_exactly() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var l: Dictionary = _first_open_letter(sim)
	sim.apply_command(ReplyLetterCommand.create(int(l.id), String(CitizenSystem.topic_def(sim, String(l.topic)).options[-1].id)))
	SimFixture.run(sim, 300)
	assert_true(sim.verify_replay())
	var back: SimState = SimState.from_dict(JSON.parse_string(JSON.stringify(sim.state.to_dict())))
	assert_eq(back.hash(), sim.state.hash())


func test_letter_topics_valid() -> void:
	assert_eq(SimFixture.content().errors, [] as Array[String])
	assert_gt((SimFixture.content().citizens.topics as Array).size(), 8)
