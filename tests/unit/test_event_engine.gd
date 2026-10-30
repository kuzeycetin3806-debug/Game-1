extends GutTest


func _sim_with_park() -> Simulation:
	var sim: Simulation = SimFixture.new_sim() # starting town has a city park + pocket park
	return sim


func test_all_event_data_is_valid() -> void:
	var c: ContentDb = SimFixture.content()
	assert_eq(c.errors, [] as Array[String])
	assert_gt(c.events.size(), 10)


func test_conditions_season_weather_hour() -> void:
	var sim: Simulation = _sim_with_park()
	var local_s: int = sim.local_seconds_now() # 2025-10-28 03:00 local, autumn
	assert_true(EventEngine.conditions_met(sim, {"season": ["autumn"]}, local_s))
	assert_false(EventEngine.conditions_met(sim, {"season": ["summer"]}, local_s))
	sim.state.weather = "rain"
	assert_true(EventEngine.conditions_met(sim, {"weather": ["rain", "storm"]}, local_s))
	assert_true(EventEngine.conditions_met(sim, {"hour_between": [2, 4]}, local_s))
	assert_false(EventEngine.conditions_met(sim, {"hour_between": [9, 18]}, local_s))
	assert_true(EventEngine.conditions_met(sim, {"hour_between": [22, 5]}, local_s), "wraps midnight")


func test_conditions_stats_buildings_flags_policies() -> void:
	var sim: Simulation = _sim_with_park()
	var ls: int = sim.local_seconds_now()
	assert_true(EventEngine.conditions_met(sim, {"min": {"population": 10}}, ls))
	assert_false(EventEngine.conditions_met(sim, {"min": {"population": 100000}}, ls))
	assert_true(EventEngine.conditions_met(sim, {"has_building": {"category:park": 2, "cafe": 1}}, ls))
	assert_false(EventEngine.conditions_met(sim, {"has_building": {"metro_station": 1}}, ls))
	assert_false(EventEngine.conditions_met(sim, {"flags_all": ["x"]}, ls))
	sim.state.flags["x"] = 1
	assert_true(EventEngine.conditions_met(sim, {"flags_all": ["x"]}, ls))
	assert_false(EventEngine.conditions_met(sim, {"flags_none": ["x"]}, ls))
	assert_true(EventEngine.conditions_met(sim, {"policies_none": ["bike_lanes"]}, ls))


func test_weekday() -> void:
	assert_eq(EventEngine.weekday(0), 4, "1970-01-01 was a Thursday")
	assert_eq(EventEngine.weekday(20754 * 86400), 3, "2026-10-28 is a Wednesday")


func test_fire_applies_effects_cooldown_and_follow_up() -> void:
	var sim: Simulation = _sim_with_park()
	var events: Array[SimEvent] = []
	var money: int = sim.state.money_cents
	EventEngine.fire(sim, "street_festival", sim.local_seconds_now(), SimRng.new(1), "", events)
	assert_eq(events.size(), 1)
	var story: SimEvent = events[0]
	assert_eq(story.type, "story")
	assert_eq(String(story.data.id), "street_festival")
	assert_ne(String(story.data.district), "", "district resolved for the newspaper")
	assert_eq(sim.state.money_cents, money - 300_000)
	assert_eq(sim.state.modifiers.size(), 1)
	assert_gt(int(sim.state.cooldowns.street_festival), sim.state.tick)
	assert_false(EventEngine.is_eligible(sim, "street_festival", sim.local_seconds_now()), "on cooldown")


func test_follow_up_fires_after_delay() -> void:
	var sim: Simulation = _sim_with_park()
	sim.state.pending.append({"tick": 5, "event": "festival_cleanup", "cause": "street_festival", "seq": 99})
	var events: Array[SimEvent] = SimFixture.run(sim, 5)
	assert_eq(_stories(events, "festival_cleanup"), 0)
	events = SimFixture.run(sim, 1)
	assert_eq(_stories(events, "festival_cleanup"), 1)
	assert_eq(sim.state.pending.size(), 0)


func test_follow_up_dropped_when_conditions_fail() -> void:
	var sim: Simulation = _sim_with_park()
	sim.state.policies["bike_lanes"] = {"since": 0, "active_from": 0}
	sim.state.pending.append({"tick": 1, "event": "bike_lane_petition", "cause": "jam_complaints", "seq": 1})
	var events: Array[SimEvent] = SimFixture.run(sim, 3)
	assert_eq(_stories(events, "bike_lane_petition"), 0)
	assert_eq(sim.state.pending.size(), 0)


func test_modifier_expires() -> void:
	var sim: Simulation = _sim_with_park()
	sim.state.modifiers.append({"source": "t", "stat": "happiness", "amount": 100, "until": 3})
	assert_eq(int(ModifierSet.collect(sim.state, sim.content).happiness) - _weather_happiness(sim), 100)
	SimFixture.run(sim, 3)
	assert_eq(sim.state.modifiers.size(), 0)


func test_week_of_events_is_reproducible_and_lively() -> void:
	var a: Simulation = _sim_with_park()
	var b: Simulation = _sim_with_park()
	var ea: Array[SimEvent] = SimFixture.run(a, 7 * 144)
	var eb: Array[SimEvent] = SimFixture.run(b, 7 * 144)
	var sa: Array = []
	var sb: Array = []
	for e: SimEvent in ea:
		if e.type == "story":
			sa.append([e.tick, e.data.id])
	for e: SimEvent in eb:
		if e.type == "story":
			sb.append([e.tick, e.data.id])
	assert_eq(sa, sb)
	assert_gt(sa.size(), 3, "a week should produce several stories")
	assert_eq(a.state.hash(), b.state.hash())


func _stories(events: Array[SimEvent], id: String) -> int:
	var n: int = 0
	for e: SimEvent in events:
		if e.type == "story" and String(e.data.id) == id:
			n += 1
	return n


func _weather_happiness(sim: Simulation) -> int:
	return int((sim.content.weather.effects as Dictionary).get(sim.state.weather, {}).get("happiness", 0))
