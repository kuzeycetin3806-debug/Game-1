extends GutTest

var rules: Dictionary


func before_all() -> void:
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/notifications.json"))


func _state() -> SimState:
	var s := SimState.new()
	s.start_unix = SimFixture.START_UNIX # 00:00 UTC
	s.utc_offset_s = SimFixture.UTC_OFFSET # local = UTC+3
	return s


## Candidate at local hh:mm on day 0.
func _cand(hour: int, minute: int, key: String, priority: int) -> Dictionary:
	var local_minutes: int = hour * 60 + minute
	var tick: int = (local_minutes * 60 - SimFixture.UTC_OFFSET) / SimConfig.TICK_SECONDS
	return {"tick": tick, "key": key, "args": [], "priority": priority}


func _local_minute(s: SimState, at_unix: int) -> int:
	return posmod(at_unix + s.utc_offset_s, 86400) / 60


func test_quiet_hours_move_to_morning() -> void:
	var s: SimState = _state()
	var out: Array[Dictionary] = NotificationPlanner.choose([_cand(23, 30, "NOTIF_LETTER", 70)] as Array[Dictionary], s, rules)
	assert_eq(out.size(), 1)
	assert_eq(_local_minute(s, int(out[0].at_unix)), 8 * 60 + 30)


func test_daily_cap_and_gap_keep_the_most_important() -> void:
	var s: SimState = _state()
	var c: Array[Dictionary] = [
		_cand(10, 0, "NOTIF_STORY", 50), _cand(10, 30, "NOTIF_MILESTONE", 80), _cand(14, 0, "NOTIF_LETTER", 70),
		_cand(17, 0, "NOTIF_POLICY", 65), _cand(20, 0, "NOTIF_TRAFFIC", 45),
	]
	var out: Array[Dictionary] = NotificationPlanner.choose(c, s, rules)
	assert_eq(out.size(), 3, "max 3 per day")
	var keys: Array = out.map(func(n: Dictionary) -> String: return String(n.key))
	assert_eq(keys, ["NOTIF_MILESTONE", "NOTIF_LETTER", "NOTIF_POLICY"])
	for i: int in range(1, out.size()):
		assert_gte(int(out[i].at_unix) - int(out[i - 1].at_unix), 180 * 60)


func test_morning_paper_lands_at_breakfast() -> void:
	var s: SimState = _state()
	var out: Array[Dictionary] = NotificationPlanner.choose([_cand(0, 0, "NOTIF_PAPER", 35)] as Array[Dictionary], s, rules)
	assert_eq(_local_minute(s, int(out[0].at_unix)), 8 * 60 + 30)


func test_plan_on_a_real_city_is_deterministic_and_bounded() -> void:
	var a: Simulation = SimFixture.new_sim()
	SimFixture.run(a, 144 * 2)
	var p1: Array[Dictionary] = NotificationPlanner.plan(a.clone(), rules)
	var p2: Array[Dictionary] = NotificationPlanner.plan(a.clone(), rules)
	assert_eq(p1, p2)
	assert_gt(p1.size(), 0, "a day ahead should hold at least the morning paper")
	assert_lte(p1.size(), 3 * 2)
	assert_eq(a.state.tick, 288, "planning never advances the real city")
	for n: Dictionary in p1:
		var m: int = posmod(int(n.at_unix) + a.state.utc_offset_s, 86400) / 60
		assert_false(m >= 22 * 60 or m < 8 * 60, "no pings during quiet hours")
