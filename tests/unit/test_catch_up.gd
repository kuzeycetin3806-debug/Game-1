extends GutTest

const T: int = SimConfig.TICK_SECONDS


func test_plan_small_gap_steps_everything() -> void:
	var p: Dictionary = CatchUp.plan(10, 0, 25 * T + 59)
	assert_eq(p, {"steps": 15, "shift_seconds": 0})


func test_plan_caps_and_sleeps_the_rest() -> void:
	var gap: int = CatchUp.MAX_TICKS + 500
	var p: Dictionary = CatchUp.plan(0, 0, gap * T)
	assert_eq(p.steps, CatchUp.MAX_TICKS)
	assert_eq(p.shift_seconds, 500 * T)


func test_plan_small_backward_jump_waits() -> void:
	var p: Dictionary = CatchUp.plan(100, 0, 90 * T)
	assert_eq(p, {"steps": 0, "shift_seconds": 0})


func test_plan_big_backward_jump_rebases() -> void:
	var p: Dictionary = CatchUp.plan(1000, 0, 100 * T)
	assert_eq(p, {"steps": 0, "shift_seconds": -900 * T})


func test_plan_before_start_handles_negative_elapsed() -> void:
	var p: Dictionary = CatchUp.plan(0, 10_000, 10_000 - 3 * 86400)
	assert_lt(p.shift_seconds, 0)
	# After applying the shift the city is exactly on time.
	var after: Dictionary = CatchUp.plan(0, 10_000 + int(p.shift_seconds), 10_000 - 3 * 86400)
	assert_eq(after, {"steps": 0, "shift_seconds": 0})


func test_sleep_realign_keeps_sim_time_equal_to_wall_time() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var now: int = SimFixture.START_UNIX + (CatchUp.MAX_TICKS + 1000) * T + 17
	var p: Dictionary = CatchUp.plan(sim.state.tick, sim.state.start_unix, now)
	assert_true(sim.apply_command(RealignClockCommand.create(p.shift_seconds)).ok)
	SimFixture.run(sim, p.steps)
	assert_eq(CatchUp.plan(sim.state.tick, sim.state.start_unix, now), {"steps": 0, "shift_seconds": 0})
	var sim_now: int = sim.state.start_unix + sim.state.tick * T
	assert_between(now - sim_now, 0, T - 1)


func test_job_matches_direct_stepping() -> void:
	var a: Simulation = SimFixture.new_sim()
	var b: Simulation = SimFixture.new_sim()
	SimFixture.place(a, "office_mid", Vector2i(25, 25))
	SimFixture.place(b, "office_mid", Vector2i(25, 25))
	SimFixture.run(a, 500)
	var job := CatchUpJob.create(b.clone(), 500)
	job.run()
	assert_true(job.finished)
	assert_eq(job.done, 500)
	assert_eq(job.sim.state.hash(), a.state.hash())
	assert_eq(job.summary.simulated_ticks(), 500)
	assert_eq(int(job.summary.counts.get("day_started", 0)), 3)


func test_job_on_worker_thread_matches() -> void:
	var a: Simulation = SimFixture.new_sim()
	SimFixture.run(a, 300)
	var job := CatchUpJob.create(SimFixture.new_sim(), 300)
	var task: int = WorkerThreadPool.add_task(job.run)
	WorkerThreadPool.wait_for_task_completion(task)
	assert_eq(job.sim.state.hash(), a.state.hash())


func test_clone_is_independent() -> void:
	var a: Simulation = SimFixture.new_sim()
	var b: Simulation = a.clone()
	SimFixture.run(b, 10)
	assert_eq(a.state.tick, 0)
	assert_eq(b.state.tick, 10)


func test_summary_tracks_changes_and_highlights() -> void:
	var sim: Simulation = SimFixture.new_sim()
	SimFixture.place(sim, "cafe", Vector2i(25, 25))
	var job := CatchUpJob.create(sim, 144)
	job.run()
	var s: CatchUpSummary = job.summary
	assert_eq(int(s.counts.get("building_completed", 0)), 1)
	assert_eq(s.highlights[0].type, "building_completed")
	assert_eq(s.days.size(), 1)
	assert_true(s.after.has("population") and s.before.has("money"))


func test_replay_with_sleep_matches_live() -> void:
	var live: Simulation = SimFixture.new_sim()
	SimFixture.run(live, 50)
	live.apply_command(RealignClockCommand.create(3 * 86400))
	SimFixture.place(live, "cafe", Vector2i(25, 25))
	SimFixture.run(live, 200)
	var replayed: Simulation = Simulation.replay(SimFixture.content(), SimFixture.SEED, SimFixture.START_UNIX, SimFixture.UTC_OFFSET, live.command_log, live.state.tick)
	assert_eq(replayed.state.hash(), live.state.hash())


func test_realign_rejects_odd_shift() -> void:
	var sim: Simulation = SimFixture.new_sim()
	assert_eq(sim.apply_command(RealignClockCommand.create(601)).error, "ERR_BAD_TIME_SHIFT")
	assert_eq(sim.apply_command(RealignClockCommand.create(0)).error, "ERR_BAD_TIME_SHIFT")
