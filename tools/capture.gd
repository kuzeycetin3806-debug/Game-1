extends SceneTree
## Renders the main scene at given local hours and saves PNGs (visual checks / CI art review).
## Usage: godot --path . -s tools/capture.gd -- --out=DIR --hours=8,13,19.5,23 [--quality=2] [--date=2026-06-21]

var _out: String = "user://captures"
var _hours: Array[float] = [9.0, 13.0, 19.0, 23.0]
var _quality: int = 2
var _date: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--hours="):
			_hours.clear()
			for h: String in arg.trim_prefix("--hours=").split(","):
				_hours.append(float(h))
		elif arg.begins_with("--quality="):
			_quality = int(arg.trim_prefix("--quality="))
		elif arg.begins_with("--date="):
			var p: PackedStringArray = arg.trim_prefix("--date=").split("-")
			_date = {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var settings: Node = root.get_node("Settings")
	settings.call("set_quality", _quality)
	change_scene_to_file("res://scenes/main.tscn")
	for i: int in 5:
		await process_frame
	var clock: Node = root.get_node("Clock")
	var base: Dictionary = Time.get_datetime_dict_from_system()
	if not _date.is_empty():
		base.merge(_date, true)
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	for h: float in _hours:
		var d: Dictionary = base.duplicate()
		d.hour = int(h)
		d.minute = int((h - floorf(h)) * 60.0)
		d.second = 0
		clock.set("frozen_unix_time", float(Time.get_unix_time_from_datetime_dict(d) - bias))
		var dn: Node = current_scene.get_node("City/DayNight")
		dn.call("refresh")
		for i: int in 20:
			await process_frame
		var img: Image = root.get_texture().get_image()
		var path: String = "%s/city_%05.2f.png" % [_out, h]
		img.save_png(path)
		print("saved ", path)
	quit()
