extends GutTest


func before_each() -> void:
	Clock.frozen_unix_time = 1_761_609_600.0
	SimRunner.new_city(8080)


func after_each() -> void:
	Clock.frozen_unix_time = -1.0
	Settings.set_notifications(true)


func test_pause_schedules_texts_and_resume_cancels() -> void:
	var plan: Array[Dictionary] = SimRunner.schedule_notifications()
	assert_eq(SimRunner.notifier.scheduled.size(), plan.size())
	assert_gt(plan.size(), 0)
	for n: Dictionary in SimRunner.notifier.scheduled:
		assert_false(String(n.body).contains("%"), "text formatted: " + String(n.body))
		assert_ne(String(n.body), "")
	SimRunner._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(SimRunner.notifier.scheduled.size(), 0)


func test_disabled_notifications_schedule_nothing() -> void:
	Settings.set_notifications(false)
	assert_eq(SimRunner.schedule_notifications().size(), 0)
	assert_eq(SimRunner.notifier.scheduled.size(), 0)
