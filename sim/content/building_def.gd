class_name BuildingDef
extends RefCounted
## Immutable definition of a building type, parsed from data/buildings/*.json.

const CATEGORIES: Array[String] = ["residential", "commercial", "office", "park", "transit"]

var id: String
var version: int
var name_key: String
var desc_key: String
var category: String
var size: int
var cost: int # lira
var upkeep_per_day: int # lira
var build_hours: int
var residents: int
var jobs: int
var happiness: int # permille contribution near the building
var green: int
var pollution: int
var traffic: int # trips per day-peak
var traffic_relief: int # permille
var radius: int # cells
var visual: Dictionary


static func from_dict(d: Dictionary) -> BuildingDef:
	var b := BuildingDef.new()
	b.id = String(d.id)
	b.version = int(d.version)
	b.name_key = String(d.name_key)
	b.desc_key = String(d.get("desc_key", ""))
	b.category = String(d.category)
	b.size = int(d.size)
	b.cost = int(d.cost)
	b.upkeep_per_day = int(d.upkeep_per_day)
	b.build_hours = int(d.build_hours)
	b.residents = int(d.get("residents", 0))
	b.jobs = int(d.get("jobs", 0))
	var e: Dictionary = d.get("effects", {})
	b.happiness = int(e.get("happiness", 0))
	b.green = int(e.get("green", 0))
	b.pollution = int(e.get("pollution", 0))
	b.traffic = int(e.get("traffic", 0))
	b.traffic_relief = int(e.get("traffic_relief", 0))
	b.radius = int(e.get("radius", 0))
	b.visual = d.get("visual", {})
	return b


## Schema check. Returns human-readable problems; empty means valid.
static func validate(d: Dictionary, source: String) -> Array[String]:
	var errors: Array[String] = []
	var required: Dictionary = {
		"id": TYPE_STRING, "version": TYPE_FLOAT, "name_key": TYPE_STRING, "category": TYPE_STRING,
		"size": TYPE_FLOAT, "cost": TYPE_FLOAT, "upkeep_per_day": TYPE_FLOAT, "build_hours": TYPE_FLOAT,
		"visual": TYPE_DICTIONARY,
	}
	for key: String in required:
		if not d.has(key):
			errors.append("%s: missing field '%s'" % [source, key])
		elif typeof(d[key]) != required[key] and not (required[key] == TYPE_FLOAT and typeof(d[key]) == TYPE_INT):
			errors.append("%s: field '%s' has wrong type" % [source, key])
	if not errors.is_empty():
		return errors
	var id_re := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	if id_re.search(String(d.id)) == null:
		errors.append("%s: id '%s' must be snake_case" % [source, d.id])
	if not CATEGORIES.has(String(d.category)):
		errors.append("%s: unknown category '%s'" % [source, d.category])
	if int(d.size) < 1 or int(d.size) > 3:
		errors.append("%s: size must be 1..3" % source)
	for key: String in ["cost", "upkeep_per_day", "build_hours", "residents", "jobs"]:
		if d.has(key) and int(d[key]) < 0:
			errors.append("%s: '%s' must be >= 0" % [source, key])
	if d.has("effects") and typeof(d.effects) != TYPE_DICTIONARY:
		errors.append("%s: 'effects' must be an object" % source)
	var kind: String = String((d.visual as Dictionary).get("kind", ""))
	if not ["building", "park", "plaza"].has(kind):
		errors.append("%s: visual.kind must be building|park|plaza" % source)
	return errors
