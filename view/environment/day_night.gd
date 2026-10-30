class_name DayNight
extends Node
## Drives sun/moon light, sky, fog, ambient and the global window/lamp shader
## values from the real local time (via Clock). Visual only, never touches sim.

@export var light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export_file("*.json") var palette_path: String = "res://data/environment/sky_palette.json"
@export_file("*.json") var location_path: String = "res://data/environment/city_location.json"
## Keeps shadows from stretching across the whole map at sunrise/sunset.
@export var min_light_elevation_deg: float = 7.0
@export var moon_elevation_deg: float = 42.0
## Sun elevation where the light switches between sun and moon (palette energy is 0 here).
@export var light_swap_elevation_deg: float = -4.0
## Seconds between environment refreshes when time is flowing normally.
@export var refresh_interval: float = 1.0

const BASE_FOG_DENSITY: float = 0.00035
const BASE_SATURATION: float = 1.15

var palette: SkyPalette
var latitude_deg: float = 41.0
var north_offset_deg: float = 0.0
var current: SkyPalette.Sample
var sun_dir: Vector3 = Vector3.UP
var sun_elevation: float = 90.0
## Set every frame by WeatherView: light/ambient multipliers, extra fog, saturation.
var weather_profile: Dictionary = {}:
	set(value):
		weather_profile = value
		_force_refresh = true

var _sky_mat: ShaderMaterial
var _accum: float = 0.0
var _force_refresh: bool = true


func _ready() -> void:
	palette = SkyPalette.load_from_file(palette_path)
	var loc: Variant = JSON.parse_string(FileAccess.get_file_as_string(location_path))
	if loc is Dictionary:
		latitude_deg = float((loc as Dictionary).get("latitude_deg", latitude_deg))
		north_offset_deg = float((loc as Dictionary).get("north_offset_deg", 0.0))
	_setup_environment()
	EventBus.debug_time_offset_changed.connect(func(_o: float) -> void: _force_refresh = true)
	refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _force_refresh or _accum >= refresh_interval:
		_accum = 0.0
		_force_refresh = false
		refresh()


func refresh() -> void:
	var hour: float = Clock.local_hour_float()
	var doy: int = Clock.local_day_of_year()
	sun_dir = SunModel.sun_direction(hour, doy, latitude_deg, north_offset_deg)
	sun_elevation = SunModel.elevation_deg(sun_dir)
	current = palette.sample(sun_elevation)
	_apply_light()
	_apply_environment()
	RenderingServer.global_shader_parameter_set("window_light", palette.window_light(current.darkness, hour))
	RenderingServer.global_shader_parameter_set("street_lamp", palette.street_lamps(current.darkness))


func _apply_light() -> void:
	var dir: Vector3
	if sun_elevation > light_swap_elevation_deg:
		dir = _with_min_elevation(sun_dir, min_light_elevation_deg)
	else:
		# Moonlight comes from the antipode of the sun at a fixed, flattering height.
		var flat := Vector3(-sun_dir.x, 0.0, -sun_dir.z)
		if flat.length_squared() < 0.0001:
			flat = Vector3(0, 0, 1)
		dir = _with_min_elevation(flat.normalized(), moon_elevation_deg)
	light.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	light.light_color = current.light_color
	light.light_energy = current.light_energy * float(weather_profile.get("light", 1.0))


func _apply_environment() -> void:
	var env: Environment = world_environment.environment
	env.ambient_light_color = current.ambient_color
	env.ambient_light_energy = current.ambient_energy * float(weather_profile.get("ambient", 1.0))
	env.fog_light_color = current.fog_color
	env.fog_density = BASE_FOG_DENSITY + float(weather_profile.get("fog_add", 0.0))
	env.adjustment_saturation = BASE_SATURATION * float(weather_profile.get("saturation", 1.0))
	_sky_mat.set_shader_parameter("top_color", current.sky_top)
	_sky_mat.set_shader_parameter("horizon_color", current.sky_horizon)
	_sky_mat.set_shader_parameter("bottom_color", current.sky_bottom)
	# Push glow a little at night so lit windows bloom softly.
	env.glow_intensity = lerpf(0.35, 0.9, current.darkness)


func _setup_environment() -> void:
	if world_environment.environment == null:
		world_environment.environment = Environment.new()
	var env: Environment = world_environment.environment
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://assets/shaders/sky_gradient.gdshader") as Shader
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_density = BASE_FOG_DENSITY
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = BASE_SATURATION
	env.adjustment_contrast = 1.06
	light.shadow_enabled = true
	light.shadow_blur = 1.6
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.2


static func _with_min_elevation(dir: Vector3, min_deg: float) -> Vector3:
	var elev: float = asin(clampf(dir.y, -1.0, 1.0))
	var target: float = maxf(elev, deg_to_rad(min_deg))
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.000001:
		return Vector3.UP
	flat = flat.normalized()
	return (flat * cos(target) + Vector3.UP * sin(target)).normalized()
