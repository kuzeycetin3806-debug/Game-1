class_name ContentDb
extends RefCounted
## All data-driven content the sim needs. Pure: built from dictionaries so tests
## can feed fixtures; `load_default()` is the only place that touches files.

const BUILDINGS_DIR: String = "res://data/buildings"
const BALANCE_PATH: String = "res://data/balance/default.json"
const MAP_PATH: String = "res://data/maps/nefeskent.json"
const WEATHER_PATH: String = "res://data/environment/weather.json"
const EVENTS_DIR: String = "res://data/events"
const POLICIES_DIR: String = "res://data/policies"

var buildings: Dictionary = {} # id -> BuildingDef
var building_order: Array[String] = [] # stable order for UI and iteration
var balance: Dictionary = {}
var map: Dictionary = {}
var weather: Dictionary = {}
var events: Dictionary = {} # id -> validated event dictionary
var event_order: Array[String] = []
var policies: Dictionary = {} # id -> validated policy dictionary
var policy_order: Array[String] = []
var errors: Array[String] = []


## `extra` may hold "weather" (Dictionary), "events" and "policies" (Arrays of dictionaries).
static func from_dicts(building_dicts: Array, balance_dict: Dictionary, map_dict: Dictionary, extra: Dictionary = {}) -> ContentDb:
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
	db.weather = extra.get("weather", {})
	db._add_records(extra.get("events", []), db.events, db.event_order, EventSchema.validate)
	db._add_records(extra.get("policies", []), db.policies, db.policy_order, PolicySchema.validate)
	db._validate_cross_refs()
	return db


func _add_records(list: Array, into: Dictionary, order: Array[String], validator: Callable) -> void:
	for raw: Variant in list:
		var d: Dictionary = SimJson.ints(raw) as Dictionary
		var src: String = String(d.get("_source", d.get("id", "?")))
		var errs: Array[String] = validator.call(d, src)
		if not errs.is_empty():
			errors.append_array(errs)
			continue
		if into.has(d.id):
			errors.append("%s: duplicate id '%s'" % [src, d.id])
			continue
		into[String(d.id)] = d
		order.append(String(d.id))


static func load_default() -> ContentDb:
	var dir_errors: Array[String] = []
	var dicts: Array = _read_dir(BUILDINGS_DIR, dir_errors)
	var balance_v: Variant = _read_json(BALANCE_PATH)
	var map_v: Variant = _read_json(MAP_PATH)
	var weather_v: Variant = _read_json(WEATHER_PATH)
	var extra: Dictionary = {
		"weather": weather_v if weather_v is Dictionary else {},
		"events": _read_dir(EVENTS_DIR, dir_errors),
		"policies": _read_dir(POLICIES_DIR, dir_errors),
	}
	var db: ContentDb = from_dicts(dicts, balance_v if balance_v is Dictionary else {}, map_v if map_v is Dictionary else {}, extra)
	if not weather_v is Dictionary:
		db.errors.append("%s: invalid JSON" % WEATHER_PATH)
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
	for id: String in event_order:
		var ev: Dictionary = events[id]
		for raw_eff: Variant in ev.get("effects", []):
			var eff: Dictionary = raw_eff
			if String(eff.type) == "follow_up" and not events.has(String(eff.event)):
				errors.append("event %s: follow_up to unknown event '%s'" % [id, eff.event])
		var cond: Dictionary = ev.get("conditions", {})
		for key: String in cond.get("has_building", {}):
			var cat: String = key.trim_prefix("category:")
			if key.begins_with("category:") and not BuildingDef.CATEGORIES.has(cat):
				errors.append("event %s: unknown building category '%s'" % [id, cat])
			elif not key.begins_with("category:") and not buildings.has(key):
				errors.append("event %s: unknown building '%s'" % [id, key])
		for side: String in ["policies_all", "policies_none"]:
			for pol: Variant in cond.get(side, []):
				if not policies.has(String(pol)):
					errors.append("event %s: unknown policy '%s'" % [id, pol])
	for id: String in policy_order:
		for other: Variant in policies[id].get("conflicts", []):
			if not policies.has(String(other)):
				errors.append("policy %s: conflicts with unknown policy '%s'" % [id, other])


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Every *.json in a folder, sorted by file name, each tagged with its path.
static func _read_dir(dir_path: String, errs: Array[String]) -> Array:
	var out: Array = []
	var files: Array = Array(DirAccess.get_files_at(dir_path))
	files.sort()
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var path: String = dir_path.path_join(f)
		var parsed: Variant = _read_json(path)
		if parsed is Dictionary:
			(parsed as Dictionary)["_source"] = path
			out.append(parsed)
		else:
			errs.append("%s: invalid JSON" % path)
	return out
