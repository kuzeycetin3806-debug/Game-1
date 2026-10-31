extends SceneTree
## Checks what a brand-new player gets after a real cold start. Run AFTER the
## game itself ran once against the same SEHIR_SAVE_DIR (tools/startup_smoke.sh).
## Exit 1 when something is missing.


func _initialize() -> void:
	var ss: Node = root.get_node("SaveService")
	var r: Dictionary = ss.call("load_city", ContentDb.load_default())
	var problems: Array[String] = []
	if not r.ok:
		problems.append("no save after first launch: %s" % r.error)
	else:
		var meta: Dictionary = r.meta
		if int(meta.get("edition_no", 0)) < 1:
			problems.append("first newspaper edition was not published")
		var sim: Simulation = r.sim
		if sim.state.citizens.is_empty():
			problems.append("no citizens in the new town")
	if problems.is_empty():
		print("startup smoke OK")
		quit(0)
	else:
		for p: String in problems:
			printerr(p)
		quit(1)
