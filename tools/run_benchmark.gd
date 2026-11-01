extends SceneTree
## Runs the in-game performance test once and saves a screenshot of the result.
## xvfb-run -a godot --path . --rendering-method mobile --resolution 540x960 -s tools/run_benchmark.gd -- --out=DIR


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = "user://bench"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("SaveService").set("save_dir", "user://bench_saves")
	root.get_node("SaveService").call("delete_all")
	change_scene_to_file("res://scenes/main.tscn")
	for i: int in 10:
		await process_frame
	for n: Node in current_scene.find_children("*", "NewspaperView", true, false):
		(n as Control).visible = false
	var runner: Node = root.get_node("SimRunner")
	var before: int = runner.get("sim").state.hash()
	var quality_before: int = root.get_node("Settings").get("graphics_quality")
	var b: Node = current_scene.call("run_benchmark")
	await b.finished
	for i: int in 5:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("benchmark.png"))
	var ok: bool = runner.get("sim").state.hash() == before and int(root.get_node("Settings").get("graphics_quality")) == quality_before and not bool(runner.call("in_preview"))
	print("restored real city and quality: ", ok)
	quit(0 if ok else 1)
