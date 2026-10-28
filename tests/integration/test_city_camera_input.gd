extends GutTest
## Feeds synthetic touch events into a real CityCamera node.

var rig: CityCamera


func before_each() -> void:
	rig = CityCamera.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 28.0
	rig.add_child(cam)
	add_child_autofree(rig)
	await wait_physics_frames(1)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	rig._unhandled_input(e)


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = to
	e.relative = to - from
	rig._unhandled_input(e)


func _settle(seconds: float) -> void:
	var steps: int = int(seconds * 60.0)
	for i: int in steps:
		rig._process(1.0 / 60.0)


func test_one_finger_drag_pans() -> void:
	var start: Vector3 = rig.focus
	_touch(0, Vector2(200, 400), true)
	_drag(0, Vector2(200, 400), Vector2(260, 400))
	_touch(0, Vector2(260, 400), false)
	_settle(1.0)
	assert_gt(rig.focus.distance_to(start), 1.0)
	assert_almost_eq(rig.focus.y, 0.0, 0.0001)


func test_pan_keeps_inertia_then_stops() -> void:
	_touch(0, Vector2(200, 400), true)
	for i: int in 5:
		rig._process(1.0 / 60.0)
		_drag(0, Vector2(200 + i * 20, 400), Vector2(220 + i * 20, 400))
	_touch(0, Vector2(300, 400), false)
	_settle(0.05)
	var just_after: Vector3 = rig.focus
	_settle(0.5)
	var later: Vector3 = rig.focus
	assert_gt(later.distance_to(just_after), 0.5, "focus should glide after release")
	_settle(4.0)
	var settled: Vector3 = rig.focus
	_settle(1.0)
	assert_lt(rig.focus.distance_to(settled), 0.05, "glide should come to rest")


func test_pinch_spread_zooms_in() -> void:
	var start: float = rig.distance
	_touch(0, Vector2(200, 400), true)
	_touch(1, Vector2(300, 400), true)
	_drag(0, Vector2(200, 400), Vector2(150, 400))
	_drag(1, Vector2(300, 400), Vector2(350, 400))
	_settle(1.0)
	assert_lt(rig.distance, start)


func test_twist_rotates() -> void:
	var start: float = rig.yaw
	_touch(0, Vector2(200, 400), true)
	_touch(1, Vector2(300, 400), true)
	_drag(1, Vector2(300, 400), Vector2(250, 450))
	_touch(0, Vector2(200, 400), false)
	_touch(1, Vector2(250, 450), false)
	_settle(1.0)
	assert_ne(snappedf(rig.yaw, 0.001), snappedf(start, 0.001))


func test_focus_stays_in_bounds() -> void:
	rig.bounds_half_extent = 50.0
	_touch(0, Vector2(0, 0), true)
	for i: int in 50:
		_drag(0, Vector2(0, 0), Vector2(-400, -400))
	_touch(0, Vector2(0, 0), false)
	_settle(3.0)
	assert_lte(absf(rig.focus.x), 50.0 + 0.001)
	assert_lte(absf(rig.focus.z), 50.0 + 0.001)


func test_zoom_respects_limits() -> void:
	_touch(0, Vector2(100, 400), true)
	_touch(1, Vector2(400, 400), true)
	for i: int in 30:
		_drag(0, Vector2(100, 400), Vector2(240, 400))
		_drag(1, Vector2(400, 400), Vector2(260, 400))
		_drag(0, Vector2(240, 400), Vector2(100, 400))
	_settle(2.0)
	assert_lte(rig.distance, rig.max_distance + 0.01)
	assert_gte(rig.distance, rig.min_distance - 0.01)
