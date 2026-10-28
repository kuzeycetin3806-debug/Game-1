extends GutTest


func test_autoloads_present() -> void:
	assert_not_null(get_tree().root.get_node_or_null("EventBus"))
	assert_not_null(get_tree().root.get_node_or_null("Clock"))
	assert_not_null(get_tree().root.get_node_or_null("Settings"))


func test_clock_can_be_frozen() -> void:
	var clock: Node = get_tree().root.get_node("Clock")
	clock.set("frozen_unix_time", 1_700_000_000.0)
	assert_eq(clock.call("now_unix"), 1_700_000_000.0)
	clock.set("frozen_unix_time", -1.0)
