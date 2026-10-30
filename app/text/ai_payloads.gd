class_name AiPayloads
extends RefCounted
## Builds backend request bodies (must match backend/src/schemas.ts) and checks
## backend responses before they are shown. Pure; unit tested.

const MAX_TITLE: int = 90
const MAX_STORY_BODY: int = 520
const MAX_LETTER_BODY: int = 700


static func city(sim: Simulation, date_text: String) -> Dictionary:
	var s: SimState = sim.state
	return {
		"name": "Nefeskent",
		"date": date_text.substr(0, 60),
		"season": WeatherSystem.season_name_at(sim.local_seconds_now()),
		"weather": s.weather,
		"stats": {"population": s.population, "happiness": s.happiness, "traffic": s.traffic, "money": s.money_cents / SimConfig.CENTS},
	}


## `edition` is NewsDesk data; `page` its TemplateWriter rendering.
static func newspaper(sim: Simulation, edition: Dictionary, page: Dictionary, lang: String, writer: TemplateWriter) -> Dictionary:
	var stories: Array = []
	var rendered: Array = [page.headline] + (page.stories as Array)
	for i: int in mini((edition.stories as Array).size(), 6):
		var st: Dictionary = edition.stories[i]
		var text: Dictionary = rendered[i]
		var facts: Dictionary = {}
		var vars: Dictionary = writer.resolve_vars(st.get("vars", {}) as Dictionary)
		for k: String in vars:
			if facts.size() < 8:
				facts[k] = String(vars[k]).substr(0, 200)
		stories.append({"key": String(st.key).substr(0, 60), "count": clampi(int(st.get("count", 1)), 1, 50), "facts": facts,
			"template_title": String(text.title).substr(0, 200), "template_body": String(text.body).substr(0, 600)})
	return {"lang": lang, "edition": int(edition.edition), "city": city(sim, String(page.edition_line)), "stories": stories}


static func letter(sim: Simulation, l: Dictionary, c: Citizen, page: Dictionary, lang: String, occupation: String) -> Dictionary:
	var labels: Array = []
	for o: Variant in page.options:
		labels.append(String((o as Dictionary).label).substr(0, 200))
	var d: Dictionary = {
		"lang": lang,
		"letter_id": int(l.id),
		"city": city(sim, ""),
		"citizen": {"first": c.first, "last": c.last, "age": clampi(c.age, 16, 110), "occupation": occupation.substr(0, 40),
			"district": String(l.get("district", "")).substr(0, 40), "traits": c.traits.duplicate(),
			"interests": c.interests.slice(0, 6), "mood": clampi(c.mood, -100, 100)},
		"topic": String(l.topic),
		"tone": String(l.tone),
		"template_subject": String(page.subject).substr(0, 200),
		"template_body": String(page.body).substr(0, 600),
		"options": labels.slice(0, 4),
	}
	if String(page.memory_line) != "":
		d.memory = String(page.memory_line).substr(0, 200)
	return d


## {key: {title, body}} from a /v1/newspaper response, or {} if it looks wrong.
static func accept_newspaper(resp: Variant) -> Dictionary:
	if not resp is Dictionary or not (resp as Dictionary).get("stories") is Array:
		return {}
	var out: Dictionary = {}
	for raw: Variant in (resp as Dictionary).stories:
		if not raw is Dictionary:
			return {}
		var s: Dictionary = raw
		var title: String = String(s.get("title", ""))
		var body: String = String(s.get("body", ""))
		if title.length() < 3 or title.length() > MAX_TITLE or body.length() < 10 or body.length() > MAX_STORY_BODY:
			continue
		out[String(s.get("key", ""))] = {"title": title, "body": body}
	return out


static func accept_letter(resp: Variant) -> Dictionary:
	if not resp is Dictionary:
		return {}
	var r: Dictionary = resp
	for k: String in ["subject", "greeting", "body", "signoff"]:
		if not r.get(k) is String or String(r[k]).length() < 2:
			return {}
	if String(r.body).length() > MAX_LETTER_BODY or String(r.subject).length() > 70:
		return {}
	return {"subject": String(r.subject), "greeting": String(r.greeting), "body": String(r.body), "signoff": String(r.signoff)}
