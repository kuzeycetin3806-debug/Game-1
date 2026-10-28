class_name GraphicsQuality
extends Node
## Applies the Settings.graphics_quality profile to the 3D view.

@export var camera_rig: CityCamera
@export var light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var city: PlaceholderCity

## Keys match Settings.Quality (LOW, MEDIUM, HIGH).
## VARSAYIM: LOW caps at 30 FPS to save battery on weak phones.
const PROFILES: Dictionary = {
	0: {"msaa": Viewport.MSAA_DISABLED, "scale": 0.75, "shadows": true, "shadow_size": 1024,
		"soft_filter": RenderingServer.SHADOW_QUALITY_HARD, "dof": false, "glow": false, "foliage": 0.45, "fps": 30},
	1: {"msaa": Viewport.MSAA_2X, "scale": 0.9, "shadows": true, "shadow_size": 2048,
		"soft_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "dof": true, "glow": true, "foliage": 0.8, "fps": 60},
	2: {"msaa": Viewport.MSAA_4X, "scale": 1.0, "shadows": true, "shadow_size": 4096,
		"soft_filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "dof": true, "glow": true, "foliage": 1.0, "fps": 60},
}


func _ready() -> void:
	EventBus.graphics_quality_changed.connect(_on_quality_changed)
	camera_rig.moved.connect(_update_shadow_distance)
	apply(Settings.graphics_quality)


func apply(q: int) -> void:
	var p: Dictionary = PROFILES[q]
	var vp: Viewport = get_viewport()
	vp.msaa_3d = p.msaa
	vp.scaling_3d_scale = p.scale
	light.shadow_enabled = p.shadows
	RenderingServer.directional_shadow_atlas_set_size(p.shadow_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p.soft_filter)
	camera_rig.set_dof_enabled(p.dof)
	world_environment.environment.glow_enabled = p.glow
	city.foliage_density = p.foliage
	Engine.max_fps = p.fps
	_update_shadow_distance()


func _update_shadow_distance() -> void:
	# Tight shadow range = sharper shadows from a single cascade.
	light.directional_shadow_max_distance = camera_rig.distance * 1.6


func _on_quality_changed(q: int) -> void:
	apply(q)
