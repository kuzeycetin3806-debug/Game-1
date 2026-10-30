class_name PolicySchema
extends RefCounted
## Validation for data/policies/*.json.


static func validate(d: Dictionary, src: String) -> Array[String]:
	var e: Array[String] = []
	for k: String in ["id", "version", "name_key", "desc_key", "setup_cost", "cost_per_day", "delay_hours", "effects"]:
		if not d.has(k):
			e.append("%s: missing field '%s'" % [src, k])
	if not e.is_empty():
		return e
	if RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(String(d.id)) == null:
		e.append("%s: id must be snake_case" % src)
	for stat: String in (d.effects as Dictionary):
		if not ModifierSet.STATS.has(stat) or stat == "daily_cost":
			e.append("%s: unknown effect stat '%s'" % [src, stat])
	for k: String in ["setup_cost", "cost_per_day", "delay_hours"]:
		if int(d[k]) < 0:
			e.append("%s: '%s' must be >= 0" % [src, k])
	return e
