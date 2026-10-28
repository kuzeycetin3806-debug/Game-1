extends GutTest

const LAT: float = 40.74
const SUMMER_SOLSTICE: int = 172
const WINTER_SOLSTICE: int = 355


func test_noon_sun_is_high_in_summer() -> void:
	var e: float = SunModel.elevation_deg(SunModel.sun_direction(12.0, SUMMER_SOLSTICE, LAT))
	assert_almost_eq(e, 90.0 - LAT + 23.44, 0.6)


func test_noon_sun_is_low_in_winter() -> void:
	var e: float = SunModel.elevation_deg(SunModel.sun_direction(12.0, WINTER_SOLSTICE, LAT))
	assert_almost_eq(e, 90.0 - LAT - 23.44, 0.6)


func test_midnight_sun_below_horizon() -> void:
	assert_lt(SunModel.elevation_deg(SunModel.sun_direction(0.0, SUMMER_SOLSTICE, LAT)), 0.0)
	assert_lt(SunModel.elevation_deg(SunModel.sun_direction(0.0, WINTER_SOLSTICE, LAT)), 0.0)


func test_morning_sun_rises_in_the_east() -> void:
	var d: Vector3 = SunModel.sun_direction(8.0, 80, LAT)
	assert_gt(d.x, 0.0, "morning sun should be east (+X)")


func test_noon_sun_is_south_in_northern_hemisphere() -> void:
	var d: Vector3 = SunModel.sun_direction(12.0, 80, LAT)
	assert_gt(d.z, 0.0, "south is +Z")


func test_summer_days_longer_than_winter() -> void:
	assert_gt(_daylight_hours(SUMMER_SOLSTICE), _daylight_hours(WINTER_SOLSTICE) + 4.0)


func test_north_offset_rotates_but_keeps_elevation() -> void:
	var a: Vector3 = SunModel.sun_direction(9.5, 120, LAT, 0.0)
	var b: Vector3 = SunModel.sun_direction(9.5, 120, LAT, 30.0)
	assert_almost_eq(a.y, b.y, 0.0001)
	assert_gt(a.distance_to(b), 0.1)


func _daylight_hours(doy: int) -> float:
	var hours: float = 0.0
	for i: int in range(24 * 12):
		if SunModel.sun_direction(float(i) / 12.0, doy, LAT).y > 0.0:
			hours += 1.0 / 12.0
	return hours
