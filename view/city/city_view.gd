class_name CityView
extends Node3D
## Root of the 3D city scene. Holds references so UI can reach the view
## without brittle node paths.

## Opening shot: close enough to read the starting town.
const OPENING_DISTANCE: float = 330.0

@onready var camera_rig: CityCamera = %CameraRig
@onready var day_night: DayNight = %DayNight
@onready var renderer: CityRenderer = %CityRenderer
@onready var build_controller: BuildController = %BuildController


func _ready() -> void:
	EventBus.city_loaded.connect(_frame_city)
	_frame_city()


func _frame_city() -> void:
	camera_rig.bounds_half_extent = renderer.half_extent() * 0.9
	var sim: Simulation = SimRunner.sim
	if sim == null or sim.state.buildings.is_empty():
		return
	var sum := Vector3.ZERO
	for b: BuildingInstance in sim.state.buildings:
		sum += renderer.cell_center(b.cell)
	camera_rig.snap_to(sum / sim.state.buildings.size(), OPENING_DISTANCE)
