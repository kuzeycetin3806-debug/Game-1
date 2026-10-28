extends GutTest


func test_spreading_fingers_zooms_in() -> void:
	var f: float = CityCamera.pinch_zoom_factor(Vector2(100, 100), Vector2(200, 100), Vector2(50, 100), Vector2(250, 100))
	assert_almost_eq(f, 0.5, 0.0001)


func test_pinch_ignores_degenerate_touches() -> void:
	assert_eq(CityCamera.pinch_zoom_factor(Vector2.ZERO, Vector2(10, 0), Vector2(5, 5), Vector2(5, 5)), 1.0)


func test_twist_is_clockwise_positive_and_wraps() -> void:
	var a := Vector2(0, 0)
	assert_almost_eq(CityCamera.twist_angle(a, Vector2(100, 0), a, Vector2(0, 100)), PI / 2.0, 0.0001)
	# Crossing the ±PI seam must not jump by a full turn.
	var t: float = CityCamera.twist_angle(a, Vector2(-100, 1), a, Vector2(-100, -1))
	assert_lt(absf(t), 0.1)


func test_pan_moves_focus_opposite_to_finger() -> void:
	var w: Vector3 = CityCamera.screen_delta_to_ground(Vector2(10, 0), 960.0, 25.0, 200.0, 0.0, deg_to_rad(45.0))
	assert_lt(w.x, 0.0)
	assert_almost_eq(w.y, 0.0, 0.0001)


func test_pan_scales_with_distance() -> void:
	var near: Vector3 = CityCamera.screen_delta_to_ground(Vector2(10, 0), 960.0, 25.0, 100.0, 0.3, 0.7)
	var far: Vector3 = CityCamera.screen_delta_to_ground(Vector2(10, 0), 960.0, 25.0, 200.0, 0.3, 0.7)
	assert_almost_eq(far.length(), near.length() * 2.0, 0.0001)


func test_orbit_basis_looks_down_at_focus() -> void:
	var b: Basis = CityCamera.orbit_basis(0.7, deg_to_rad(40.0))
	var look: Vector3 = -b.z
	assert_almost_eq(rad_to_deg(asin(-look.y)), 40.0, 0.01)


func test_pitch_rises_when_zoomed_out() -> void:
	var near: float = CityCamera.pitch_for_distance(60.0, 60.0, 400.0, 32.0, 52.0)
	var far: float = CityCamera.pitch_for_distance(400.0, 60.0, 400.0, 32.0, 52.0)
	assert_almost_eq(rad_to_deg(near), 32.0, 0.001)
	assert_almost_eq(rad_to_deg(far), 52.0, 0.001)
