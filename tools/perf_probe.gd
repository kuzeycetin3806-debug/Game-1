extends SceneTree
## Fills the map, then renders the main scene at each quality and two zoom
## levels, printing draw calls, primitives and frame time. Needs a GPU or
## lavapipe: xvfb-run -a godot --path . --rendering-method mobile --resolution 540x960 -s tools/perf_probe.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("SaveService").set("save_dir", "user://perf_saves")
	root.get_node("SaveService").call("delete_all")
	change_scene_to_file("res://scenes/main.tscn")
	for i: int in 5:
		await process_frame
	var runner: Node = root.get_node("SimRunner")
	runner.call("new_city", 4242)
	var sim: RefCounted = runner.get("sim")
	sim.state.money_cents = 1_000_000_000_00
	var ids: Array = sim.content.building_order
	for x: int in sim.state.grid_size:
		for y: int in sim.state.grid_size:
			sim.apply_command(PlaceBuildingCommand.create(String(ids[(x * 7 + y * 3) % ids.size()]), Vector2i(x, y)))
	for i: int in 600:
		sim.step()
	sim.state.population = 15000
	runner.set_process(false)
	root.get_node("EventBus").emit_signal("city_changed")
	for n: Node in current_scene.find_children("*", "NewspaperView", true, false):
		(n as Control).visible = false
	var city: Node = current_scene.get_node("City")
	var rig: Node = city.get("camera_rig")
	print("buildings=%d" % sim.state.buildings.size())
	for q: int in [2, 1, 0]:
		root.get_node("Settings").call("set_quality", q)
		for dist: float in [560.0, 200.0]:
			rig.call("snap_to", Vector3.ZERO, dist)
			for i: int in 30:
				await process_frame
			var t0: int = Time.get_ticks_usec()
			for i: int in 20:
				await process_frame
			var ms: float = (Time.get_ticks_usec() - t0) / 20000.0
			print("quality=%d zoom=%d draw_calls=%d primitives=%dk frame=%.1fms (software render)" % [q, dist,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0), ms])
	quit()
