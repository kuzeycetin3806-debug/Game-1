class_name SunModel
extends RefCounted
## Pure solar position math for the day/night visuals. View-layer only:
## it uses trig functions, so it must never feed the deterministic sim.

const AXIAL_TILT_DEG: float = 23.44


## Unit vector pointing from the ground towards the sun, in Godot world space
## (+X east, +Y up, -Z north before north_offset is applied).
## VARSAYIM: local clock time is treated as solar time (no longitude/DST correction).
static func sun_direction(local_hour: float, day_of_year: int, latitude_deg: float, north_offset_deg: float = 0.0) -> Vector3:
	var decl: float = declination(day_of_year)
	var lat: float = deg_to_rad(latitude_deg)
	var hour_angle: float = deg_to_rad(15.0 * (local_hour - 12.0))
	var east: float = -cos(decl) * sin(hour_angle)
	var north: float = sin(decl) * cos(lat) - cos(decl) * cos(hour_angle) * sin(lat)
	var up: float = sin(decl) * sin(lat) + cos(decl) * cos(hour_angle) * cos(lat)
	var dir := Vector3(east, up, -north).normalized()
	return dir.rotated(Vector3.UP, deg_to_rad(north_offset_deg))


## Solar declination in radians.
static func declination(day_of_year: int) -> float:
	return deg_to_rad(-AXIAL_TILT_DEG) * cos(TAU / 365.0 * float(day_of_year + 10))


static func elevation_deg(sun_dir: Vector3) -> float:
	return rad_to_deg(asin(clampf(sun_dir.y, -1.0, 1.0)))
