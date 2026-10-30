class_name TemplateWriter
extends RefCounted
## Writes an edition (from NewsDesk) as text using data/text_templates/news_<lang>.json.
## Variant choice is derived from the edition number and story key, so a saved
## edition always reads the same. Missing keys fall back to `fallback` (Turkish).

var templates: Dictionary
var fallback: Dictionary
## Callable(String) -> String for building/policy names (TranslationServer.translate in the app).
var translate: Callable


static func create(p_templates: Dictionary, p_fallback: Dictionary, p_translate: Callable) -> TemplateWriter:
	var w := TemplateWriter.new()
	w.templates = p_templates
	w.fallback = p_fallback
	w.translate = p_translate
	return w


func render(edition: Dictionary) -> Dictionary:
	var n: int = int(edition.edition)
	var out_stories: Array = []
	for raw: Variant in edition.stories:
		var st: Dictionary = raw
		out_stories.append(story_text(st, n))
	var headline: Dictionary = out_stories[0] if not out_stories.is_empty() else {"title": "", "body": ""}
	return {
		"masthead": String(_value("masthead", "")),
		"tagline": _pick(_value("tagline", [""]) as Array, n, "tagline"),
		"edition_line": fill(String(_value("edition_line", "{edition}")), {"edition": str(n), "date": date_text(edition.date)}),
		"headline": headline,
		"stories": out_stories.slice(1),
		"section_numbers": String(_value("section_numbers", "")),
		"section_weather": String(_value("section_weather", "")),
		"section_more": String(_value("section_more", "")),
		"numbers": numbers_text(edition.numbers),
		"weather": weather_text(edition.weather),
	}


func story_text(st: Dictionary, edition_no: int) -> Dictionary:
	var key: String = String(st.key)
	var tkey: String = key.get_slice(":", 0) # "policy_effect:bike_lanes" -> "policy_effect"
	var t: Dictionary = _story_template(tkey)
	var count: int = int(st.get("count", 1))
	var vars: Dictionary = resolve_vars(st.get("vars", {}) as Dictionary)
	vars.count = str(count)
	var titles: Array = t.get("title_many", t.get("title", [])) if count > 1 else t.get("title", [])
	var bodies: Array = t.get("body_many", t.get("body", [])) if count > 1 else t.get("body", [])
	return {
		"key": key,
		"title": fill(_pick(titles, edition_no, key + "/t"), vars),
		"body": fill(_pick(bodies, edition_no, key + "/b"), vars),
	}


## "*_key" vars are translation keys; expose them translated without the suffix.
func resolve_vars(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in raw:
		var v: Variant = raw[k]
		if k.ends_with("_key"):
			out[k.trim_suffix("_key")] = String(translate.call(String(v)))
		elif v is int:
			out[k] = thousands(int(v))
		else:
			out[k] = str(v)
	return out


func date_text(d: Dictionary) -> String:
	var months: Array = _value("months", []) as Array
	var weekdays: Array = _value("weekdays", []) as Array
	return fill(String(_value("date_format", "{day}.{month}.{year}")), {
		"day": str(int(d.day)), "year": str(int(d.year)),
		"month": String(months[int(d.month) - 1]) if months.size() == 12 else str(int(d.month)),
		"weekday": String(weekdays[int(d.weekday) - 1]) if weekdays.size() == 7 else "",
	})


func numbers_text(nums: Dictionary) -> Array:
	var labels: Dictionary = _value("numbers", {}) as Dictionary
	var out: Array = []
	for k: String in ["population", "money", "happiness", "traffic"]:
		if not nums.has(k):
			continue
		var b: int = int(nums[k].before)
		var a: int = int(nums[k].after)
		var value: String
		var delta: String
		match k:
			"money":
				value = thousands(a) + " TL"
				delta = _signed(thousands(a - b), a - b)
			"happiness", "traffic":
				value = "%%%d" % roundi(a / 10.0)
				delta = _signed(str(roundi((a - b) / 10.0)), roundi((a - b) / 10.0))
			_:
				value = thousands(a)
				delta = _signed(thousands(a - b), a - b)
		out.append({"key": k, "label": String(labels.get(k, k)), "value": value, "delta": delta})
	return out


func weather_text(w: Dictionary) -> Dictionary:
	var names: Dictionary = _value("weather_names", {}) as Dictionary
	var parts: Array = _value("day_parts", ["", "", "", ""]) as Array
	var fc: Array = []
	for raw: Variant in w.get("forecast", []):
		var f: Dictionary = raw
		fc.append({"label": String(parts[clampi(int(f.part), 0, parts.size() - 1)]), "text": String(names.get(String(f.weather), f.weather)), "weather": String(f.weather)})
	return {"now": fill(String(_value("weather_now", "{weather}")), {"weather": String(names.get(String(w.now), w.now)).to_lower()}),
		"now_weather": String(w.now), "forecast": fc}


static func fill(template: String, vars: Dictionary) -> String:
	var s: String = template
	for k: String in vars:
		s = s.replace("{" + k + "}", String(vars[k]))
	return s


static func thousands(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out


static func _signed(text: String, v: int) -> String:
	return ("+" + text) if v > 0 else text


func _pick(options: Array, edition_no: int, salt: String) -> String:
	if options.is_empty():
		return ""
	var h: int = SimRng.mix32(edition_no * 7919 ^ SimRng.hash_bytes(salt.to_utf8_buffer()))
	return String(options[h % options.size()])


func _story_template(key: String) -> Dictionary:
	var own: Dictionary = templates.get("stories", {})
	if own.has(key):
		return own[key]
	return (fallback.get("stories", {}) as Dictionary).get(key, {"title": [key], "body": [""]})


func _value(key: String, default_value: Variant) -> Variant:
	if templates.has(key):
		return templates[key]
	return fallback.get(key, default_value)
