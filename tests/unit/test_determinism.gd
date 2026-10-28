extends GutTest
## The core promise: a city is a pure function of (seed, commands, ticks).

const TOTAL: int = 144 * 4 + 37


## Commands issued at fixed ticks during a run.
func _script() -> Dictionary:
	return {
		5: [PlaceBuildingCommand.create("apartment_mid", Vector2i(25, 25))],
		60: [PlaceBuildingCommand.create("office_mid", Vector2i(25, 19)), PlaceBuildingCommand.create("cafe", Vector2i(27, 25))],
		200: [PlaceBuildingCommand.create("metro_station", Vector2i(26, 26))],
		333: [DemolishCommand.create(1)],
		400: [PlaceBuildingCommand.create("city_park", Vector2i(1, 1))],
	}


func _apply_script_at(sim: Simulation, script: Dictionary) -> void:
	for cmd: Command in script.get(sim.state.tick, []):
		var copy: Command = Command.from_dict(cmd.to_dict())
		assert_true(sim.apply_command(copy).ok, "scripted command failed at %d" % sim.state.tick)


func _run_straight() -> Simulation:
	var sim: Simulation = SimFixture.new_sim()
	var script: Dictionary = _script()
	while sim.state.tick < TOTAL:
		_apply_script_at(sim, script)
		sim.step()
	return sim


func test_same_seed_same_city() -> void:
	assert_eq(_run_straight().state.hash(), _run_straight().state.hash())


func test_different_seed_different_city() -> void:
	var a: Simulation = SimFixture.new_sim(1)
	var b: Simulation = SimFixture.new_sim(2)
	SimFixture.run(a, 300)
	SimFixture.run(b, 300)
	# Same layout, so totals may match; the seed must at least be part of the state.
	assert_ne(a.state.hash(), b.state.hash())


func test_chunked_with_save_load_matches_straight_run() -> void:
	var straight: int = _run_straight().state.hash()
	var script: Dictionary = _script()
	var sim: Simulation = SimFixture.new_sim()
	var chunks: Array[int] = [1, 7, 50, 144, 3, 200, 90]
	var ci: int = 0
	while sim.state.tick < TOTAL:
		var n: int = chunks[ci % chunks.size()]
		ci += 1
		for i: int in n:
			if sim.state.tick >= TOTAL:
				break
			_apply_script_at(sim, script)
			sim.step()
		# Save -> JSON text -> load, exactly like closing and reopening the app.
		var saved: String = JSON.stringify({"state": sim.state.to_dict(), "commands": _commands_to_array(sim)})
		var parsed: Dictionary = JSON.parse_string(saved)
		var loaded := Simulation.create(SimState.from_dict(parsed.state), SimFixture.content())
		for raw: Variant in parsed.commands:
			loaded.command_log.append(Command.from_dict(raw as Dictionary))
		sim = loaded
	assert_eq(sim.state.hash(), straight)


func test_replay_from_command_log_matches() -> void:
	var live: Simulation = _run_straight()
	var replayed: Simulation = Simulation.replay(SimFixture.content(), SimFixture.SEED, SimFixture.START_UNIX, SimFixture.UTC_OFFSET, live.command_log, TOTAL)
	assert_eq(replayed.state.hash(), live.state.hash())
	assert_eq(replayed.state.to_dict(), live.state.to_dict())


func test_state_roundtrip_is_lossless() -> void:
	var sim: Simulation = _run_straight()
	var back: SimState = SimState.from_dict(JSON.parse_string(JSON.stringify(sim.state.to_dict())))
	assert_eq(back.hash(), sim.state.hash())


func _commands_to_array(sim: Simulation) -> Array:
	var out: Array = []
	for c: Command in sim.command_log:
		out.append(c.to_dict())
	return out
