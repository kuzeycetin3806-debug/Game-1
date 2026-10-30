extends GutTest

const BLOCK: int = 6 * 3600


func _content() -> ContentDb:
	return SimFixture.content()


func test_roll_is_deterministic() -> void:
	var c: ContentDb = _content()
	for b: int in range(1000, 1100):
		assert_eq(WeatherSystem.roll(c, 42, b, "rain", "autumn"), WeatherSystem.roll(c, 42, b, "rain", "autumn"))


func test_no_snow_outside_winter_and_snow_in_winter() -> void:
	var c: ContentDb = _content()
	var winter_snow: int = 0
	for b: int in 2000:
		assert_ne(WeatherSystem.roll(c, 7, b, "", "summer"), "snow")
		assert_ne(WeatherSystem.roll(c, 7, b, "", "spring"), "snow")
		if WeatherSystem.roll(c, 7, b, "", "winter") == "snow":
			winter_snow += 1
	assert_between(winter_snow, 350, 650, "about 25 % of fresh winter rolls")


func test_persistence_keeps_weather_often() -> void:
	var c: ContentDb = _content()
	var kept: int = 0
	for b: int in 2000:
		if WeatherSystem.roll(c, 9, b, "rain", "autumn") == "rain":
			kept += 1
	# 62 % persistence + 30 % of the rest re-rolling rain ≈ 73 %.
	assert_between(kept, 1350, 1600)


func test_season_names() -> void:
	assert_eq(WeatherSystem.season_name_at(20754 * 86400), "autumn") # 2026-10-28
	assert_eq(WeatherSystem.season_name_at(20650 * 86400), "summer") # July
	assert_eq(WeatherSystem.season_name_at(20470 * 86400), "winter") # January


func test_weather_changes_in_sim_and_forecast_is_exact() -> void:
	var sim: Simulation = SimFixture.new_sim()
	sim.step()
	var local_s: int = sim.local_seconds_now()
	var fc: Array[Dictionary] = WeatherSystem.forecast(sim.state, sim.content, local_s, 6)
	assert_eq(fc.size(), 6)
	var seen: Array[String] = []
	for f: Dictionary in fc:
		while WeatherSystem.block_index(sim.local_seconds_now(), sim.content) < int(f.block):
			sim.step()
		sim.step() # the block's first tick rolls it
		assert_eq(sim.state.weather, String(f.weather), "forecast for block %d" % f.block)
		seen.append(sim.state.weather)


func test_weather_effects_reach_modifiers() -> void:
	var sim: Simulation = SimFixture.new_sim()
	sim.state.weather = "storm"
	var mods: Dictionary = ModifierSet.collect(sim.state, sim.content)
	assert_eq(int(mods.traffic_demand), 260)
	assert_eq(int(mods.happiness), -55)
