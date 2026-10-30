extends Node
## Save file IO: atomic writes, a rolling backup, and recovery from a broken
## main file. Format conversion is SaveCodec's job (pure, in sim/save).

const FILE_NAME: String = "city.json"

## Tests and tools point this somewhere disposable (env SEHIR_SAVE_DIR), so
## they never touch a developer's real city.
var save_dir: String = "user://saves"


func _init() -> void:
	var override: String = OS.get_environment("SEHIR_SAVE_DIR")
	if override != "":
		save_dir = override


func main_path() -> String:
	return save_dir.path_join(FILE_NAME)


func backup_path() -> String:
	return main_path() + ".bak"


func temp_path() -> String:
	return main_path() + ".tmp"


func has_save() -> bool:
	return FileAccess.file_exists(main_path()) or FileAccess.file_exists(backup_path())


## Writes tmp, verifies it parses, then rotates main -> bak and tmp -> main.
func save(sim: Simulation, meta: Dictionary = {}) -> Error:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var data: Dictionary = SaveCodec.encode(sim, int(Clock.now_unix()), String(ProjectSettings.get_setting("application/config/version", "0.0.0")), meta)
	var text: String = JSON.stringify(data)
	var f: FileAccess = FileAccess.open(temp_path(), FileAccess.WRITE)
	if f == null:
		push_error("SaveService: cannot open %s (%s)" % [temp_path(), error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	if not _parse(FileAccess.get_file_as_string(temp_path())) is Dictionary:
		push_error("SaveService: written file does not parse")
		return ERR_FILE_CORRUPT
	var dir: DirAccess = DirAccess.open(save_dir)
	if FileAccess.file_exists(main_path()):
		if FileAccess.file_exists(backup_path()):
			dir.remove(backup_path())
		dir.rename(main_path(), backup_path())
	var err: Error = dir.rename(temp_path(), main_path())
	if err != OK:
		push_error("SaveService: rename failed (%s)" % error_string(err))
	return err


## Returns {ok, sim, error, recovered: bool, last_wall_time}.
## Tries the main file first, then the backup.
func load_city(content: ContentDb) -> Dictionary:
	var main: Dictionary = _load_file(main_path(), content)
	if main.ok:
		main.recovered = false
		return main
	var bak: Dictionary = _load_file(backup_path(), content)
	if bak.ok:
		push_warning("SaveService: main save unusable (%s), recovered from backup" % main.error)
		bak.recovered = true
		return bak
	return {"ok": false, "sim": null, "error": main.error, "recovered": false, "last_wall_time": 0}


func delete_all() -> void:
	for p: String in [main_path(), backup_path(), temp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _load_file(path: String, content: ContentDb) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "ERR_SAVE_MISSING"}
	var parsed: Variant = _parse(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"ok": false, "error": "ERR_SAVE_CORRUPT"}
	return SaveCodec.decode(parsed as Dictionary, content)


## Quiet parse: a broken save is an expected case, not an engine error.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
