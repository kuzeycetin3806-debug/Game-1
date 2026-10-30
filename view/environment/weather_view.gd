class_name WeatherView
extends Node3D
## Shows the sim's weather: rain/snow particles that follow the camera,
## dimmer light and haze through DayNight, and lightning flashes in storms.
## Profiles live in data/environment/weather_visuals.json.

const KEYS: Array[String] = ["light", "ambient", "fog_add", "saturation", "rain", "snow", "lightning"]

@export var day_night: DayNight
@export var camera_rig: CityCamera
@export_file("*.json") var visuals_path: String = "res://data/environment/weather_visuals.json"

## 0..1 particle budget, set by GraphicsQuality.
var particle_density: float = 1.0:
	set(value):
		particle_density = value
		_apply_amounts()

var current: Dictionary = {}
var _profiles: Dictionary = {}
var _transition: float = 4.0
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _flash: float = 0.0
var _next_flash: float = 5.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(visuals_path))
	if data is Dictionary:
		_profiles = (data as Dictionary).get("profiles", {})
		_transition = float((data as Dictionary).get("transition_seconds", 4.0))
	current = profile_for("clear", _profiles)
	_rain = _make_rain()
	_snow = _make_snow()
	add_child(_rain)
	add_child(_snow)
	_apply_amounts()


## Profile for a weather id with every key present (missing ones default to clear).
static func profile_for(weather: String, profiles: Dictionary) -> Dictionary:
	var base: Dictionary = {"light": 1.0, "ambient": 1.0, "fog_add": 0.0, "saturation": 1.0, "rain": 0.0, "snow": 0.0, "lightning": 0.0}
	var p: Dictionary = profiles.get(weather, {})
	for k: String in KEYS:
		if p.has(k):
			base[k] = float(p[k])
	return base


## Moves `from` towards `to` by `t` (0..1) for every key.
static func blend(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	for k: String in KEYS:
		out[k] = lerpf(float(from.get(k, 0.0)), float(to.get(k, 0.0)), clampf(t, 0.0, 1.0))
	return out


func _process(delta: float) -> void:
	var weather: String = SimRunner.sim.state.weather if SimRunner.sim != null else "clear"
	var target: Dictionary = profile_for(weather, _profiles)
	current = blend(current, target, delta / maxf(_transition, 0.01))
	_update_lightning(delta)
	var shown: Dictionary = current.duplicate()
	shown.light = float(shown.light) + _flash * 2.5
	shown.ambient = float(shown.ambient) + _flash * 1.2
	day_night.weather_profile = shown
	_rain.emitting = float(current.rain) > 0.05
	_snow.emitting = float(current.snow) > 0.05
	_rain.amount_ratio = clampf(float(current.rain) / 1.6, 0.0, 1.0)
	_snow.amount_ratio = clampf(float(current.snow), 0.0, 1.0)
	var focus: Vector3 = camera_rig.focus
	_rain.global_position = focus + Vector3(0, 90, 0)
	_snow.global_position = focus + Vector3(0, 70, 0)


func _update_lightning(delta: float) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	if float(current.lightning) < 0.5:
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_flash = 1.0
		_next_flash = _rng.randf_range(5.0, 14.0)


func _apply_amounts() -> void:
	if _rain == null:
		return
	_rain.amount = maxi(int(3200 * particle_density), 1)
	_snow.amount = maxi(int(1600 * particle_density), 1)


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(140, 1, 140)
	m.direction = Vector3(0.08, -1, 0.04)
	m.spread = 2.0
	m.initial_velocity_min = 85.0
	m.initial_velocity_max = 105.0
	m.gravity = Vector3(0, -30, 0)
	p.process_material = m
	p.lifetime = 1.3
	p.visibility_aabb = AABB(Vector3(-160, -120, -160), Vector3(320, 140, 320))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 3.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.88, 0.92, 1.0, 0.45)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p


func _make_snow() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(140, 1, 140)
	m.direction = Vector3(0.2, -1, 0.1)
	m.spread = 25.0
	m.initial_velocity_min = 7.0
	m.initial_velocity_max = 11.0
	m.gravity = Vector3(0, -1.5, 0)
	m.scale_min = 0.6
	m.scale_max = 1.3
	p.process_material = m
	p.lifetime = 9.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-160, -90, -160), Vector3(320, 110, 320))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p
