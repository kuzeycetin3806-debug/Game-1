extends GutTest


func test_count_scales_with_population_curve_and_weather() -> void:
	assert_eq(LifeMath.count(100, 10, 5, 0, 1000, 1.0), 10)
	assert_eq(LifeMath.count(100, 10, 5, 2000, 1000, 1.0), 100, "capped by quality")
	assert_eq(LifeMath.count(100, 10, 5, 200, 500, 1.0), 25)
	assert_eq(LifeMath.count(100, 10, 5, 200, 1000, 0.5), 25)
	assert_eq(LifeMath.count(100, 10, 5, 200, 0, 1.0), 0)


func test_curve_interpolates() -> void:
	var c: Array = [[0, 0], [600, 1000], [1440, 0]]
	assert_eq(LifeMath.curve(c, 300.0), 500)
	assert_eq(LifeMath.curve(c, 600.0), 1000)
	assert_eq(LifeMath.curve([], 10.0), 1000)


func test_along_loops_and_is_stable() -> void:
	for i: int in 50:
		var p: float = LifeMath.along(i, 123.4, 256.0, 12.0, 1)
		assert_between(p, 0.0, 256.0)
		assert_eq(p, LifeMath.along(i, 123.4, 256.0, 12.0, 1))
	var a: float = LifeMath.along(3, 0.0, 256.0, 10.0, 1)
	var b: float = LifeMath.along(3, 1.0, 256.0, 10.0, 1)
	assert_almost_eq(fposmod(b - a, 256.0), 10.0, 0.001)


func test_ping_pong_dwells_and_reverses() -> void:
	var p0: Dictionary = LifeMath.ping_pong(0.0, 100.0, 10.0, 5.0)
	assert_eq(int(p0.dir), 1)
	assert_almost_eq(float(LifeMath.ping_pong(5.0, 100.0, 10.0, 5.0).pos), 50.0, 0.001)
	assert_almost_eq(float(LifeMath.ping_pong(12.0, 100.0, 10.0, 5.0).pos), 100.0, 0.001, "dwelling at the end")
	var back: Dictionary = LifeMath.ping_pong(20.0, 100.0, 10.0, 5.0)
	assert_eq(int(back.dir), -1)
	assert_almost_eq(float(back.pos), 50.0, 0.001)


func test_rand01_range() -> void:
	for i: int in 500:
		var r: float = LifeMath.rand01(i, 7)
		assert_true(r >= 0.0 and r < 1.0)
