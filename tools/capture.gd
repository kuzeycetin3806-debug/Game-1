extends SceneTree
## Renders the main scene at given local hours and saves PNGs (visual checks / CI art review).
## Usage: godot --path . -s tools/capture.gd -- --out=DIR --hours=8,13,19.5,23 [--quality=2] [--date=2026-06-21]
##   [--build=def@x,y;def@x,y]  place buildings first   [--advance=ticks]  run the sim forward
##   [--placing=def]  enter placement mode               [--select=x,y]  select the building on a cell
##   [--zoom=distance] [--focus=cellx,celly] [--prefix=name] [--drawer]  open the build drawer
##   [--away=hours]  close the app, let time pass, reopen (opens the newspaper)
##   [--weather=rain|snow|storm|fog|cloudy|clear]  [--policies]  open decisions  [--no-paper]  close any open paper
##   [--mailbox]  open the letters list  [--letter]  open the first open letter (use with --away)

var _out: String = "user://captures"
var _hours: Array[float] = [9.0, 13.0, 19.0, 23.0]
var _quality: int = 2
var _date: Dictionary = {}
var _build: Array[String] = []
var _advance: int = 0
var _placing: String = ""
var _select: Vector2i = Vector2i(-1, -1)
var _zoom: float = -1.0
var _focus: Vector2i = Vector2i(-1, -1)
var _prefix: String = "city"
var _drawer: bool = false
var _away_hours: float = 0.0
var _weather: String = ""
var _policies: bool = false
var _close_paper: bool = false
var _mailbox: String = ""


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
		elif arg.begins_with("--build="):
			_build.assign(arg.trim_prefix("--build=").split(";"))
		elif arg.begins_with("--advance="):
			_advance = int(arg.trim_prefix("--advance="))
		elif arg.begins_with("--placing="):
			_placing = arg.trim_prefix("--placing=")
		elif arg.begins_with("--select="):
			var p2: PackedStringArray = arg.trim_prefix("--select=").split(",")
			_select = Vector2i(int(p2[0]), int(p2[1]))
		elif arg.begins_with("--zoom="):
			_zoom = float(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--focus="):
			var p3: PackedStringArray = arg.trim_prefix("--focus=").split(",")
			_focus = Vector2i(int(p3[0]), int(p3[1]))
		elif arg.begins_with("--away="):
			_away_hours = float(arg.trim_prefix("--away="))
		elif arg.begins_with("--weather="):
			_weather = arg.trim_prefix("--weather=")
		elif arg == "--policies":
			_policies = true
		elif arg == "--mailbox" or arg == "--letter":
			_mailbox = arg.trim_prefix("--")
		elif arg == "--no-paper":
			_close_paper = true
		elif arg == "--drawer":
			_drawer = true
		elif arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
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
	# Fresh, reproducible city in a scratch save dir (never the real save).
	root.get_node("SaveService").set("save_dir", "user://capture_saves")
	root.get_node("SaveService").call("delete_all")
	var runner: Node = root.get_node("SimRunner")
	runner.call("new_city", 20261028)
	var sim: RefCounted = runner.get("sim")
	sim.state.money_cents = maxi(sim.state.money_cents, 5_000_000 * 100)
	for spec: String in _build:
		if spec.is_empty():
			continue
		var parts: PackedStringArray = spec.split("@")
		var xy: PackedStringArray = parts[1].split(",")
		var r: Dictionary = runner.call("submit", PlaceBuildingCommand.create(parts[0], Vector2i(int(xy[0]), int(xy[1]))))
		if not r.ok:
			printerr("build failed: ", spec, " ", r.error)
	for i: int in _advance:
		sim.step()
	root.get_node("EventBus").emit_signal("city_changed")
	if _away_hours > 0.0:
		runner.call("save_now")
		var clock0: Node = root.get_node("Clock")
		clock0.set("frozen_unix_time", float(sim.state.start_unix + sim.state.tick * SimConfig.TICK_SECONDS) + _away_hours * 3600.0)
		runner.call("load_or_create")
		while bool(runner.get("catching_up")):
			await process_frame
		for i: int in 3:
			await process_frame
		sim = runner.get("sim")
	# Freeze the city: the capture clock below only drives the lighting.
	runner.set_process(false)
	if _weather != "":
		sim.state.weather = _weather

	# Untyped on purpose: this script compiles before autoloads exist.
	var city: Node = current_scene.get_node("City")
	var rig: Node = city.get("camera_rig")
	var focus: Vector3 = rig.get("focus")
	if _focus.x >= 0:
		focus = city.get("renderer").call("cell_center", _focus)
	rig.call("snap_to", focus, _zoom if _zoom > 0.0 else float(rig.get("distance")))
	if _placing != "":
		city.get("build_controller").call("start_placing", _placing)
	if _drawer:
		current_scene.get_node("%Hud").call("open_drawer")
	if _policies:
		current_scene.get_node("%Hud").get("_policies").set("visible", true)
	if _select.x >= 0:
		city.get("build_controller").call("select", sim.grid.building_at(_select))
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
		# Weather fades in over a few seconds; give it time (and particles) to settle.
		for i: int in (90 if _weather != "" else 20):
			await process_frame
		if _close_paper:
			for n: Node in current_scene.find_children("*", "NewspaperView", true, false):
				(n as Control).visible = false
			for i: int in 2:
				await process_frame
		if _mailbox != "":
			var mb: Node = current_scene.find_children("*", "MailboxView", true, false)[0]
			mb.call("open")
			if _mailbox == "letter":
				for raw: Variant in sim.state.letters:
					if String((raw as Dictionary).status) == "open":
						mb.call("show_letter", int((raw as Dictionary).id))
						break
			for i: int in 3:
				await process_frame
		var img: Image = root.get_texture().get_image()
		var path: String = "%s/%s_%05.2f.png" % [_out, _prefix, h]
		img.save_png(path)
		print("saved ", path)
	quit()
