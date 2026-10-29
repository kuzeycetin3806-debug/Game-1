extends SceneTree
## Replays a save from its seed + command log and checks it reproduces the same
## state hash. Exit code 1 on divergence.
## Usage: godot --headless --path . -s tools/verify_save.gd -- [path]   (default: user://saves/city.json)


func _initialize() -> void:
	var path: String = "user://saves/city.json"
	for arg: String in OS.get_cmdline_user_args():
		path = arg
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		printerr("cannot read ", path)
		quit(1)
		return
	var r: Dictionary = SaveCodec.decode(parsed as Dictionary, ContentDb.load_default())
	if not r.ok:
		printerr("decode failed: ", r.error)
		quit(1)
		return
	var sim: Simulation = r.sim
	var t0: int = Time.get_ticks_msec()
	var ok: bool = sim.verify_replay()
	print("%s: tick %d, %d commands, replay %s in %d ms" % [path, sim.state.tick, sim.command_log.size(), "MATCHES" if ok else "DIVERGES", Time.get_ticks_msec() - t0])
	quit(0 if ok else 1)
