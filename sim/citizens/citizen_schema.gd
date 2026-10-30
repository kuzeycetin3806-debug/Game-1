class_name CitizenSchema
extends RefCounted
## Load-time validation for data/citizens/*.json.


static func validate(data: Dictionary, events_like: Callable) -> Array[String]:
	var e: Array[String] = []
	var archetypes: Array = (data.get("archetypes", {}) as Dictionary).get("archetypes", [])
	if archetypes.is_empty():
		e.append("citizens: no archetypes")
	for raw: Variant in archetypes:
		var a: Dictionary = raw
		for k: String in ["id", "occupation_key", "weight", "age", "traits", "interests"]:
			if not a.has(k):
				e.append("archetype %s: missing '%s'" % [a.get("id", "?"), k])
	var names: Dictionary = data.get("names", {})
	if (names.get("first", []) as Array).is_empty() or (names.get("last", []) as Array).is_empty():
		e.append("citizens: names need first and last lists")
	var seen: Dictionary = {}
	for raw: Variant in (data.get("topics", {}) as Dictionary).get("topics", []):
		var t: Dictionary = raw
		var src: String = "letter topic %s" % t.get("id", "?")
		for k: String in ["id", "tone", "weight", "interests", "options"]:
			if not t.has(k):
				e.append("%s: missing '%s'" % [src, k])
		if seen.has(t.get("id")):
			e.append("%s: duplicate id" % src)
		seen[t.get("id")] = true
		if (t.get("options", []) as Array).is_empty():
			e.append("%s: needs at least one option" % src)
		for o: Variant in t.get("options", []):
			for eff: Variant in (o as Dictionary).get("effects", []):
				var errs: Array[String] = events_like.call({"id": "x", "version": 1, "category": "c", "importance": 0, "weight": 1, "check": "follow_up", "effects": [eff]}, src)
				e.append_array(errs)
		var cond_errs: Array[String] = events_like.call({"id": "x", "version": 1, "category": "c", "importance": 0, "weight": 1, "check": "follow_up", "conditions": t.get("conditions", {})}, src)
		e.append_array(cond_errs)
	return e
