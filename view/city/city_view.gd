class_name CityView
extends Node3D
## Root of the 3D city scene. Holds references so UI can reach the view
## without brittle node paths.

@onready var camera_rig: CityCamera = %CameraRig
@onready var day_night: DayNight = %DayNight
@onready var city: PlaceholderCity = %PlaceholderCity


func _ready() -> void:
	camera_rig.bounds_half_extent = city.half_extent() * 0.9
