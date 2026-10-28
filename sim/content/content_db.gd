class_name ContentDb
extends RefCounted
## All data-driven content the sim needs. Pure: built from dictionaries so tests
## can feed fixtures; `load_default()` is the only place that touches files.

const BUILDINGS_DIR: String = "res://data/buildings"
const BALANCE_PATH: String = "res://data/balance/default.json"
const MAP_PATH: String = "res://data/maps/nefeskent.json"

var buildings: Dictionary = {} # id -> BuildingDef
var building_order: Array[String] = [] # stable order for UI and iteration
var balance: Dictionary = {}
var map: Dictionary = {}
var errors: Array[String] = []


static func from_dicts(building_dicts: Array, balance_dict: Dictionary, map_dict: Dictionary) -> ContentDb:
	var db := ContentDb.new()
	for raw: Variant in building_dicts:
		var d: Dictionary = raw
		var src: String = String(d.get("_source", d.get("id", "?")))
		var errs: Array[String] = BuildingDef.validate(d, src)
		if not errs.is_empty():
			db.errors.append_array(errs)
			continue
		if db.buildings.has(d.id):
			db.errors.append("%s: duplicate building id '%s'" % [src, d.id])
			continue
		db.buildings[d.id] = BuildingDef.from_dict(d)
		db.building_order.append(String(d.id))
	db.balance = balance_dict
	db.map = map_dict
	db._validate_cross_refs()
	return db


static func load_default() -> ContentDb:
	var dicts: Array = []
	var dir_errors: Array[String] = []
	var files: PackedStringArray = DirAccess.get_files_at(BUILDINGS_DIR)
	var sorted: Array = Array(files)
	sorted.sort()
	for f: String in sorted:
		if not f.ends_with(".json"):
			continue
		var path: String = BUILDINGS_DIR.path_join(f)
		var parsed: Variant = _read_json(path)
		if parsed is Dictionary:
			(parsed as Dictionary)["_source"] = path
			dicts.append(parsed)
		else:
			dir_errors.append("%s: invalid JSON" % path)
	var balance_v: Variant = _read_json(BALANCE_PATH)
	var map_v: Variant = _read_json(MAP_PATH)
	var db: ContentDb = from_dicts(dicts, balance_v if balance_v is Dictionary else {}, map_v if map_v is Dictionary else {})
	db.errors.append_array(dir_errors)
	if not balance_v is Dictionary:
		db.errors.append("%s: invalid JSON" % BALANCE_PATH)
	if not map_v is Dictionary:
		db.errors.append("%s: invalid JSON" % MAP_PATH)
	return db


func get_building(id: String) -> BuildingDef:
	return buildings.get(id) as BuildingDef


func is_valid() -> bool:
	return errors.is_empty()


func bal(path: String, default_value: Variant = 0) -> Variant:
	var node: Variant = balance
	for part: String in path.split("."):
		if not node is Dictionary or not (node as Dictionary).has(part):
			return default_value
		node = (node as Dictionary)[part]
	return node


func bal_int(path: String, default_value: int = 0) -> int:
	return int(bal(path, default_value))


func _validate_cross_refs() -> void:
	for key: String in ["start_money", "tax_per_worker_per_day", "workforce_permille"]:
		if not balance.has(key):
			errors.append("balance: missing '%s'" % key)
	for key: String in ["grid_size", "road_every", "starting_buildings"]:
		if not map.has(key):
			errors.append("map: missing '%s'" % key)
	for raw: Variant in map.get("starting_buildings", []):
		var s: Dictionary = raw
		if not buildings.has(String(s.get("def", ""))):
			errors.append("map: starting building references unknown def '%s'" % s.get("def", ""))


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
