class_name EventSchema
extends RefCounted
## Validation for data/events/*.json. See docs/events.md for the format.

const CHECKS: Array[String] = ["daily", "hourly", "follow_up"]
const CONDITION_KEYS: Array[String] = ["season", "hour_between", "weekdays", "weather", "min", "max", "has_building",
	"flags_all", "flags_none", "policies_all", "policies_none"]
const STAT_KEYS: Array[String] = ["population", "happiness", "traffic", "pollution", "green", "money", "employed", "unemployment", "buildings"]
const EFFECT_TYPES: Array[String] = ["modifier", "money", "flag", "unflag", "follow_up"]
const VAR_SOURCES: Array[String] = ["random_built", "busiest", "greenest"]


static func validate(d: Dictionary, src: String) -> Array[String]:
	var e: Array[String] = []
	for k: String in ["id", "version", "category", "importance", "weight", "check"]:
		if not d.has(k):
			e.append("%s: missing field '%s'" % [src, k])
	if not e.is_empty():
		return e
	if RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(String(d.id)) == null:
		e.append("%s: id must be snake_case" % src)
	if not CHECKS.has(String(d.check)):
		e.append("%s: check must be one of %s" % [src, CHECKS])
	if int(d.weight) <= 0:
		e.append("%s: weight must be > 0" % src)
	if int(d.importance) < 0 or int(d.importance) > 100:
		e.append("%s: importance must be 0..100" % src)
	var cond: Dictionary = d.get("conditions", {})
	for k: String in cond:
		if not CONDITION_KEYS.has(k):
			e.append("%s: unknown condition '%s'" % [src, k])
	for side: String in ["min", "max"]:
		for stat: String in cond.get(side, {}):
			if not STAT_KEYS.has(stat):
				e.append("%s: unknown stat '%s' in %s" % [src, stat, side])
	if cond.has("hour_between") and (cond.hour_between as Array).size() != 2:
		e.append("%s: hour_between needs [from, to)" % src)
	for raw: Variant in d.get("effects", []):
		var eff: Dictionary = raw
		var t: String = String(eff.get("type", ""))
		if not EFFECT_TYPES.has(t):
			e.append("%s: unknown effect type '%s'" % [src, t])
		elif t == "modifier" and (not ModifierSet.STATS.has(String(eff.get("stat", ""))) or not eff.has("amount") or not eff.has("hours")):
			e.append("%s: modifier needs a known stat, amount and hours" % src)
		elif t == "money" and not eff.has("amount"):
			e.append("%s: money effect needs amount" % src)
		elif (t == "flag" or t == "unflag") and not eff.has("name"):
			e.append("%s: %s effect needs name" % [src, t])
		elif t == "follow_up" and (not eff.has("event") or not eff.has("hours")):
			e.append("%s: follow_up needs event and hours" % src)
	for k: String in d.get("vars", {}):
		if not VAR_SOURCES.has(String(d.vars[k])):
			e.append("%s: var '%s' has unknown source" % [src, k])
	return e
