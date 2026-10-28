class_name CityCamera
extends Node3D
## Touch-first orbit camera for the diorama.
## One finger: pan. Two fingers: pinch zoom + twist rotate + midpoint pan.
## Mouse (editor/desktop): left drag pan, right drag rotate, wheel zoom.
## Motion is smoothed and keeps inertia after release.

signal moved

@export var camera: Camera3D
@export_group("Limits")
@export var min_distance: float = 60.0
@export var max_distance: float = 420.0
## Pitch (degrees below horizon) when fully zoomed in / out.
@export var pitch_near_deg: float = 32.0
@export var pitch_far_deg: float = 52.0
## Half-size of the square area the focus point may move in.
@export var bounds_half_extent: float = 140.0
@export_group("Feel")
@export var smoothing: float = 14.0
@export var pan_damping: float = 4.5
@export var yaw_damping: float = 5.0
@export var mouse_rotate_speed: float = 0.008
@export var wheel_zoom_step: float = 1.12
@export_group("Tilt-shift")
@export var dof_enabled: bool = true
@export var dof_amount: float = 0.06

var focus: Vector3 = Vector3.ZERO
var yaw: float = deg_to_rad(45.0)
var distance: float = 220.0

var _target_focus: Vector3 = Vector3.ZERO
var _target_yaw: float = yaw
var _target_distance: float = distance
var _pan_velocity: Vector3 = Vector3.ZERO
var _yaw_velocity: float = 0.0

var _touches: Dictionary = {} # index -> Vector2
var _dragging: bool = false
var _mouse_pan: bool = false
var _mouse_rotate: bool = false
var _attributes: CameraAttributesPractical


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D
	assert(camera != null, "CityCamera needs a Camera3D")
	_attributes = CameraAttributesPractical.new()
	camera.attributes = _attributes
	_target_focus = focus
	_target_yaw = yaw
	_target_distance = distance
	_apply_transform()


func set_dof_enabled(enabled: bool) -> void:
	dof_enabled = enabled
	_update_dof()


func get_pitch() -> float:
	return pitch_for_distance(distance, min_distance, max_distance, pitch_near_deg, pitch_far_deg)


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventMouse and (event as InputEventMouse).device != InputEvent.DEVICE_ID_EMULATION:
		_on_mouse(event as InputEventMouse)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		_pan_velocity = Vector3.ZERO
		_yaw_velocity = 0.0
		_dragging = true
	else:
		_touches.erase(e.index)
		_dragging = not _touches.is_empty()


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		_touches[e.index] = e.position - e.relative
	var prev: Dictionary = _touches.duplicate()
	_touches[e.index] = e.position
	if _touches.size() == 1:
		_pan_by_screen(e.relative)
	elif _touches.size() >= 2:
		var ids: Array = _touches.keys()
		var a_old: Vector2 = prev[ids[0]]
		var b_old: Vector2 = prev[ids[1]]
		var a_new: Vector2 = _touches[ids[0]]
		var b_new: Vector2 = _touches[ids[1]]
		_target_distance = clampf(_target_distance * pinch_zoom_factor(a_old, b_old, a_new, b_new), min_distance, max_distance)
		_rotate_by(twist_angle(a_old, b_old, a_new, b_new))
		_pan_by_screen(((a_new + b_new) - (a_old + b_old)) * 0.5)


func _on_mouse(e: InputEventMouse) -> void:
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		match b.button_index:
			MOUSE_BUTTON_LEFT:
				_mouse_pan = b.pressed
				_dragging = b.pressed
				if b.pressed:
					_pan_velocity = Vector3.ZERO
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_mouse_rotate = b.pressed
				if b.pressed:
					_yaw_velocity = 0.0
			MOUSE_BUTTON_WHEEL_UP:
				if b.pressed:
					_target_distance = clampf(_target_distance / wheel_zoom_step, min_distance, max_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					_target_distance = clampf(_target_distance * wheel_zoom_step, min_distance, max_distance)
	elif e is InputEventMouseMotion:
		var m := e as InputEventMouseMotion
		if _mouse_pan:
			_pan_by_screen(m.relative)
		elif _mouse_rotate:
			_rotate_by(m.relative.x * mouse_rotate_speed)


func _pan_by_screen(delta_px: Vector2) -> void:
	var viewport_h: float = get_viewport().get_visible_rect().size.y
	var world: Vector3 = screen_delta_to_ground(delta_px, viewport_h, camera.fov, distance, _target_yaw, get_pitch())
	_target_focus = _clamp_focus(_target_focus + world)
	var dt: float = maxf(get_process_delta_time(), 1.0 / 240.0)
	_pan_velocity = _pan_velocity.lerp(world / dt, 0.35)


func _rotate_by(angle: float) -> void:
	_target_yaw += angle
	var dt: float = maxf(get_process_delta_time(), 1.0 / 240.0)
	_yaw_velocity = lerpf(_yaw_velocity, angle / dt, 0.35)


# --- Update ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _dragging:
		if _pan_velocity.length_squared() > 0.0001:
			_target_focus = _clamp_focus(_target_focus + _pan_velocity * delta)
			_pan_velocity *= exp(-pan_damping * delta)
		if absf(_yaw_velocity) > 0.0001 and not _mouse_rotate:
			_target_yaw += _yaw_velocity * delta
			_yaw_velocity *= exp(-yaw_damping * delta)
	var k: float = 1.0 - exp(-smoothing * delta)
	var old_focus: Vector3 = focus
	var old_yaw: float = yaw
	var old_distance: float = distance
	focus = focus.lerp(_target_focus, k)
	yaw = lerpf(yaw, _target_yaw, k)
	distance = lerpf(distance, _target_distance, k)
	if not focus.is_equal_approx(old_focus) or not is_equal_approx(yaw, old_yaw) or not is_equal_approx(distance, old_distance):
		_apply_transform()
		moved.emit()


func _apply_transform() -> void:
	var basis: Basis = orbit_basis(yaw, get_pitch())
	global_transform = Transform3D(Basis.IDENTITY, focus)
	camera.global_transform = Transform3D(basis, focus + basis * Vector3(0.0, 0.0, distance))
	_update_dof()


func _update_dof() -> void:
	if _attributes == null:
		return
	_attributes.dof_blur_far_enabled = dof_enabled
	_attributes.dof_blur_near_enabled = dof_enabled
	_attributes.dof_blur_far_distance = distance * 1.12
	_attributes.dof_blur_far_transition = distance * 0.55
	_attributes.dof_blur_near_distance = distance * 0.8
	_attributes.dof_blur_near_transition = distance * 0.35
	_attributes.dof_blur_amount = dof_amount


func _clamp_focus(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -bounds_half_extent, bounds_half_extent), 0.0, clampf(p.z, -bounds_half_extent, bounds_half_extent))


# --- Pure helpers (unit tested) ------------------------------------------------

## Camera basis for an orbit at `yaw` (radians around +Y) looking down by `pitch` (radians).
static func orbit_basis(yaw_rad: float, pitch_rad: float) -> Basis:
	return Basis(Vector3.UP, yaw_rad) * Basis(Vector3.RIGHT, -pitch_rad)


## Zooming in lowers the camera for a more intimate street-level angle.
static func pitch_for_distance(dist: float, near_dist: float, far_dist: float, near_deg: float, far_deg: float) -> float:
	var t: float = clampf(inverse_lerp(near_dist, far_dist, dist), 0.0, 1.0)
	return deg_to_rad(lerpf(near_deg, far_deg, t))


## World-space ground offset that keeps the ground under the finger.
static func screen_delta_to_ground(delta_px: Vector2, viewport_h: float, fov_deg: float, dist: float, yaw_rad: float, pitch_rad: float) -> Vector3:
	var units_per_px: float = 2.0 * dist * tan(deg_to_rad(fov_deg) * 0.5) / maxf(viewport_h, 1.0)
	var right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, yaw_rad)
	var forward: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, yaw_rad)
	var foreshorten: float = 1.0 / maxf(sin(pitch_rad), 0.2)
	return -right * delta_px.x * units_per_px + forward * delta_px.y * units_per_px * foreshorten


## >1 when fingers move together (zoom out), <1 when they spread (zoom in).
static func pinch_zoom_factor(a_old: Vector2, b_old: Vector2, a_new: Vector2, b_new: Vector2) -> float:
	var d_new: float = a_new.distance_to(b_new)
	if d_new < 1.0:
		return 1.0
	return a_old.distance_to(b_old) / d_new


## Signed twist in radians (screen space, clockwise positive).
static func twist_angle(a_old: Vector2, b_old: Vector2, a_new: Vector2, b_new: Vector2) -> float:
	return wrapf((b_new - a_new).angle() - (b_old - a_old).angle(), -PI, PI)
