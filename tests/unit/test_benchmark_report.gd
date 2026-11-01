extends GutTest


func test_stats() -> void:
	var t := PackedFloat32Array()
	for i: int in 99:
		t.append(1.0 / 60.0)
	t.append(0.1) # one hitch
	var s: Dictionary = BenchmarkReport.stats(t)
	assert_almost_eq(float(s.low1_fps), 10.0, 0.01, "1 % low catches the hitch")
	assert_gt(float(s.avg_fps), 50.0)
	assert_almost_eq(float(s.worst_ms), 100.0, 0.01)
	assert_eq(float(BenchmarkReport.stats(PackedFloat32Array()).avg_fps), 0.0)


func test_recommend_picks_highest_smooth_quality() -> void:
	var runs: Array = [
		{"quality": 2, "view": "overview", "avg_fps": 40.0, "low1_fps": 30.0},
		{"quality": 1, "view": "overview", "avg_fps": 59.0, "low1_fps": 45.0},
		{"quality": 0, "view": "overview", "avg_fps": 60.0, "low1_fps": 58.0},
	]
	assert_eq(BenchmarkReport.recommend(runs), 1)
	assert_eq(BenchmarkReport.recommend([]), 0)


func test_benchmark_city_is_dense_and_finished() -> void:
	var sim: Simulation = BenchmarkCity.build(SimFixture.content(), SimFixture.START_UNIX, SimFixture.UTC_OFFSET)
	assert_gt(sim.state.buildings.size(), 250)
	for b: BuildingInstance in sim.state.buildings:
		assert_true(b.is_complete(sim.state.tick))
	assert_gt(sim.state.population, 5000)
