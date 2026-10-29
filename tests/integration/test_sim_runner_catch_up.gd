extends GutTest
## Drives the real SimRunner with a frozen clock: close the app, move time, reopen.

const T0: float = 1_761_609_600.0 # 2025-10-28 00:00 UTC
const DAY: float = 86400.0
const SEED: int = 31337

var _old_dir: String


func before_each() -> void:
	_old_dir = SaveService.save_dir
	SaveService.save_dir = "user://test_saves/runner"
	SaveService.delete_all()
	Clock.frozen_unix_time = T0
	SimRunner.new_city(SEED)


func after_each() -> void:
	await _finish_catch_up()
	Clock.frozen_unix_time = -1.0
	SaveService.delete_all()
	SaveService.save_dir = _old_dir


func _finish_catch_up() -> void:
	var guard: int = 0
	while SimRunner.catching_up and guard < 2000:
		await wait_frames(1)
		guard += 1


## Reference: the same city stepped directly, no saves, no threads.
func _reference(ticks: int) -> Simulation:
	var s: SimState = SimRunner.sim.state
	var ref: Simulation = Simulation.new_game(SimRunner.content, SEED, s.start_unix, s.utc_offset_s)
	for i: int in ticks:
		ref.step()
	return ref


func test_reopen_after_three_days_catches_up_exactly() -> void:
	var ref: Simulation = _reference(3 * 144)
	Clock.frozen_unix_time = T0 + 3.0 * DAY
	watch_signals(EventBus)
	SimRunner.load_or_create()
	assert_true(SimRunner.catching_up, "3 days should use the background catch-up")
	await _finish_catch_up()
	assert_signal_emitted(EventBus, "catch_up_finished")
	assert_eq(SimRunner.sim.state.tick, 3 * 144)
	assert_eq(SimRunner.sim.state.hash(), ref.state.hash())
	var summary: CatchUpSummary = get_signal_parameters(EventBus, "catch_up_finished")[0]
	assert_eq(summary.simulated_ticks(), 432)
	assert_eq(summary.days.size(), 3)


func test_catch_up_result_is_saved() -> void:
	Clock.frozen_unix_time = T0 + DAY
	SimRunner.load_or_create()
	await _finish_catch_up()
	var r: Dictionary = SaveService.load_city(SimRunner.content)
	assert_true(r.ok)
	assert_eq((r.sim as Simulation).state.tick, 144)


func test_long_absence_is_capped_and_slept() -> void:
	Clock.frozen_unix_time = T0 + 20.0 * DAY
	watch_signals(EventBus)
	SimRunner.load_or_create()
	await _finish_catch_up()
	var summary: CatchUpSummary = get_signal_parameters(EventBus, "catch_up_finished")[0]
	assert_eq(summary.simulated_ticks(), CatchUp.MAX_TICKS)
	assert_eq(summary.slept_ticks, 6 * 144)
	assert_eq(summary.away_ticks(), 20 * 144)
	# Sim time now matches the wall clock again.
	var s: SimState = SimRunner.sim.state
	assert_eq(s.start_unix + s.tick * SimConfig.TICK_SECONDS, int(T0 + 20.0 * DAY))


func test_small_clock_rollback_waits() -> void:
	Clock.frozen_unix_time = T0 + DAY
	SimRunner.load_or_create()
	await _finish_catch_up()
	var tick: int = SimRunner.sim.state.tick
	Clock.frozen_unix_time = T0 + DAY - 3600.0
	await wait_frames(3)
	assert_eq(SimRunner.sim.state.tick, tick, "never rewinds")
	assert_false(SimRunner.catching_up)


func test_big_clock_rollback_rebases() -> void:
	Clock.frozen_unix_time = T0 + 5.0 * DAY
	SimRunner.load_or_create()
	await _finish_catch_up()
	var tick: int = SimRunner.sim.state.tick
	Clock.frozen_unix_time = T0 + 2.0 * DAY
	await wait_frames(3)
	await _finish_catch_up()
	assert_eq(SimRunner.sim.state.tick, tick, "state is kept")
	var last: Command = SimRunner.sim.command_log[-1]
	assert_true(last is RealignClockCommand)
	await wait_frames(2)
	assert_eq(SimRunner.sim.state.tick, tick, "and the city runs on from the new 'now'")


func test_live_ticks_step_inline() -> void:
	watch_signals(EventBus)
	Clock.frozen_unix_time = T0 + 30.0 * 60.0
	await wait_frames(3)
	assert_eq(SimRunner.sim.state.tick, 3)
	assert_signal_not_emitted(EventBus, "catch_up_started")


func test_commands_rejected_while_catching_up() -> void:
	Clock.frozen_unix_time = T0 + 10.0 * DAY
	SimRunner.load_or_create()
	if not SimRunner.catching_up:
		pending("catch-up finished before we could test")
		return
	var r: Dictionary = SimRunner.submit(PlaceBuildingCommand.create("cafe", Vector2i(25, 25)))
	assert_eq(r.error, "ERR_CITY_BUSY")


func test_duration_text() -> void:
	assert_eq(CatchUpOverlay.duration(3), "30 dakika")
	assert_eq(CatchUpOverlay.duration(6 * 4 + 2), "4 saat 20 dakika")
	assert_eq(CatchUpOverlay.duration(144 * 2 + 18), "2 gün 3 saat")
