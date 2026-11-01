extends GutTest
## The performance test must never touch the player's city.


func test_preview_does_not_touch_real_city() -> void:
	SimRunner.new_city(9090)
	var real: Simulation = SimRunner.sim
	var hash_before: int = real.state.hash()
	var preview: Simulation = BenchmarkCity.build(SimRunner.content, real.state.start_unix, real.state.utc_offset_s)
	SimRunner.begin_preview(preview)
	assert_true(SimRunner.in_preview())
	assert_eq(SimRunner.submit(PlaceBuildingCommand.create("cafe", Vector2i(25, 25))).ok, false, "no commands in preview")
	SimRunner.save_now()
	await wait_process_frames(3)
	SimRunner.end_preview()
	assert_eq(SimRunner.sim, real)
	assert_eq(real.state.hash(), hash_before)
