extends GutTest


func test_civil_from_days() -> void:
	assert_eq(SimClockMath.civil_from_days(0), {"year": 1970, "month": 1, "day": 1})
	assert_eq(SimClockMath.civil_from_days(20754), {"year": 2026, "month": 10, "day": 28})
	assert_eq(SimClockMath.civil_from_days(11016), {"year": 2000, "month": 2, "day": 29})


func test_matches_engine_calendar() -> void:
	for days: int in range(18000, 22000, 37):
		var d: Dictionary = Time.get_datetime_dict_from_unix_time(days * 86400)
		var c: Dictionary = SimClockMath.civil_from_days(days)
		assert_eq([c.year, c.month, c.day], [d.year, d.month, d.day])


func test_minute_of_day_with_offset() -> void:
	var start: int = 1_700_000_000 - (1_700_000_000 % 86400) # UTC midnight
	var local: int = SimClockMath.local_seconds(start, 3 * 3600, 6) # +3h, 6 ticks = 1h
	assert_eq(SimClockMath.minute_of_day(local), 4 * 60)


func test_seasons() -> void:
	assert_eq(SimClockMath.season_for_month(1), SimClockMath.Season.WINTER)
	assert_eq(SimClockMath.season_for_month(4), SimClockMath.Season.SPRING)
	assert_eq(SimClockMath.season_for_month(7), SimClockMath.Season.SUMMER)
	assert_eq(SimClockMath.season_for_month(10), SimClockMath.Season.AUTUMN)
