extends GutTest

var palette: SkyPalette


func before_each() -> void:
	palette = SkyPalette.load_from_file("res://data/environment/sky_palette.json")


func test_night_is_dark_and_day_is_bright() -> void:
	assert_almost_eq(palette.sample(-40.0).darkness, 1.0, 0.001)
	assert_almost_eq(palette.sample(45.0).darkness, 0.0, 0.001)


func test_sample_is_continuous() -> void:
	var prev: SkyPalette.Sample = palette.sample(-30.0)
	var e: float = -30.0
	while e < 60.0:
		e += 0.5
		var cur: SkyPalette.Sample = palette.sample(e)
		assert_lt(absf(cur.darkness - prev.darkness), 0.1)
		assert_lt(absf(cur.light_energy - prev.light_energy), 0.1)
		prev = cur


func test_sample_clamps_outside_range() -> void:
	assert_eq(palette.sample(-200.0).sky_top, palette.sample(-90.0).sky_top)
	assert_eq(palette.sample(200.0).sky_top, palette.sample(90.0).sky_top)


func test_windows_more_lit_in_evening_than_midday() -> void:
	var evening: float = palette.window_light(palette.sample(-20.0).darkness, 20.0)
	var midday: float = palette.window_light(palette.sample(50.0).darkness, 13.0)
	assert_gt(evening, midday * 4.0)


func test_window_occupancy_wraps_midnight() -> void:
	assert_almost_eq(palette.window_occupancy(24.0), palette.window_occupancy(0.0), 0.001)
	assert_almost_eq(palette.window_occupancy(-1.0), palette.window_occupancy(23.0), 0.001)


func test_street_lamps_off_by_day_on_by_night() -> void:
	assert_almost_eq(palette.street_lamps(0.0), 0.0, 0.001)
	assert_almost_eq(palette.street_lamps(1.0), 1.0, 0.001)


func test_weather_profiles_complete_and_blend() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/weather_visuals.json"))
	var sim_weather: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/weather.json"))
	for season: String in (sim_weather.seasons as Dictionary):
		for w: String in (sim_weather.seasons[season] as Dictionary):
			assert_true((data.profiles as Dictionary).has(w), "visual profile for " + w)
	var clear: Dictionary = WeatherView.profile_for("clear", data.profiles)
	var storm: Dictionary = WeatherView.profile_for("storm", data.profiles)
	var half: Dictionary = WeatherView.blend(clear, storm, 0.5)
	assert_almost_eq(float(half.light), (1.0 + 0.3) / 2.0, 0.001)
	assert_eq(WeatherView.profile_for("unknown", data.profiles).light, 1.0)
