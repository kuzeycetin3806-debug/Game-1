extends GutTest
## Newspaper publishing through the real services with a frozen clock.

const T0: float = 1_761_609_600.0
const DAY: float = 86400.0

var _old_dir: String


func before_each() -> void:
	_old_dir = SaveService.save_dir
	SaveService.save_dir = "user://test_saves/text"
	SaveService.delete_all()
	Clock.frozen_unix_time = T0
	SimRunner.new_city(4242)


func after_each() -> void:
	while SimRunner.catching_up:
		await wait_process_frames(1)
	Clock.frozen_unix_time = -1.0
	SaveService.delete_all()
	SaveService.save_dir = _old_dir


func _reopen_after(days: float) -> void:
	Clock.frozen_unix_time = T0 + days * DAY
	SimRunner.load_or_create()
	while SimRunner.catching_up:
		await wait_process_frames(1)
	await wait_process_frames(2)


func test_absence_publishes_an_edition_and_saves_it() -> void:
	watch_signals(EventBus)
	await _reopen_after(3.0)
	assert_signal_emitted(EventBus, "newspaper_published")
	var ed: Dictionary = TextService.latest()
	assert_false(ed.is_empty())
	assert_true(TextService.has_unread())
	var r: Dictionary = SaveService.load_city(SimRunner.content)
	assert_eq(int((r.meta.newspapers as Array)[-1].edition), int(ed.edition), "archive persisted")


func test_seven_day_absence_paper_is_reproducible() -> void:
	await _reopen_after(7.0)
	var first: String = JSON.stringify(TextService.render(TextService.latest(), "tr"))
	SaveService.delete_all()
	Clock.frozen_unix_time = T0
	SimRunner.new_city(4242)
	await _reopen_after(7.0)
	var second: String = JSON.stringify(TextService.render(TextService.latest(), "tr"))
	assert_eq(first, second)
	assert_string_contains(first, "Nefeskent Postası")


func test_editions_are_numbered_and_windows_do_not_overlap() -> void:
	await _reopen_after(2.0)
	var a: Dictionary = TextService.latest()
	await _reopen_after(4.0)
	var b: Dictionary = TextService.latest()
	assert_eq(int(b.edition), int(a.edition) + 1)
	assert_eq(int(b.from_tick), int(a.to_tick))


func test_live_morning_paper_on_day_start() -> void:
	await _reopen_after(0.5) # 12:00 local+offset doesn't matter; get the city running
	var before: int = int(SimRunner.meta.get("edition_no", 0))
	# Step live across the next midnight in small increments.
	var target: float = Clock.frozen_unix_time + DAY
	while Clock.frozen_unix_time < target:
		Clock.frozen_unix_time += 1800.0
		await wait_process_frames(1)
		while SimRunner.catching_up:
			await wait_process_frames(1)
	assert_gt(int(SimRunner.meta.get("edition_no", 0)), before)
