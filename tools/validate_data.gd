extends SceneTree
## Validates every data file. Exit code 1 on any problem (used by CI).


func _initialize() -> void:
	var db: ContentDb = ContentDb.load_default()
	var errors: Array[String] = db.errors.duplicate()
	for path: String in ["res://data/environment/sky_palette.json", "res://data/environment/city_location.json"]:
		if not JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary:
			errors.append("%s: invalid JSON" % path)
	if errors.is_empty():
		print("data OK: %d buildings, %d events, %d policies" % [db.buildings.size(), db.events.size(), db.policies.size()])
		quit(0)
	else:
		for e: String in errors:
			printerr(e)
		quit(1)
