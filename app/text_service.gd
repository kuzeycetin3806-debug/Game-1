extends Node
## Newspaper and (from M5) letter text. Today: template writer only. Publishes
## an edition after a real absence (catch-up) and every morning during play.
## Editions are stored as data in the save's meta and rendered on demand, so a
## language switch re-renders the archive.

const ARCHIVE_SIZE: int = 10
## Absences shorter than this (and without highlights) get no special edition.
const MIN_AWAY_TICKS: int = 6
const TEMPLATE_DIR: String = "res://data/text_templates"
const FALLBACK_LANG: String = "tr"
const BACKEND_CONFIG: String = "res://data/config/backend.json"

## Text backend (backend/). Off unless configured; failures silently keep templates.
var backend_url: String = ""
var backend_enabled: bool = false
var backend_timeout_s: float = 10.0
var _queue: Array[Dictionary] = []
var _attempted: Dictionary = {} # request key -> true (this session)
var _http: HTTPRequest
var _busy: bool = false

var editorial: Dictionary = {}
var _templates: Dictionary = {} # lang -> Dictionary
var _letter_templates: Dictionary = {} # lang -> Dictionary


func _ready() -> void:
	editorial = _read(TEMPLATE_DIR.path_join("editorial.json"))
	for lang: String in ["tr", "en"]:
		_templates[lang] = _read(TEMPLATE_DIR.path_join("news_%s.json" % lang))
		_letter_templates[lang] = _read(TEMPLATE_DIR.path_join("letters_%s.json" % lang))
	_load_backend_config()
	_http = HTTPRequest.new()
	_http.timeout = backend_timeout_s
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	EventBus.catch_up_finished.connect(_on_catch_up_finished)
	EventBus.sim_event_emitted.connect(_on_sim_event)
	EventBus.city_loaded.connect(func() -> void: _maybe_first_edition.call_deferred())
	# SimRunner is an earlier autoload: on a cold start the city was loaded before we connected.
	_maybe_first_edition.call_deferred()


## Builds the next edition from everything since the previous one.
## `fallback_before` is used when no earlier edition left a snapshot (old saves).
func publish(auto_open: bool, fallback_before: Dictionary = {}) -> Dictionary:
	var sim: Simulation = SimRunner.sim
	var meta: Dictionary = SimRunner.meta
	var from: int = int(meta.get("last_edition_tick", 0))
	var before: Dictionary = meta.get("last_snapshot", fallback_before if not fallback_before.is_empty() else CatchUpSummary.snapshot(sim.state))
	var n: int = int(meta.get("edition_no", 0)) + 1
	var edition: Dictionary = NewsDesk.build(sim, sim.event_log.since(from), n, from, before, editorial)
	var archive: Array = meta.get("newspapers", [])
	archive.append(edition)
	while archive.size() > ARCHIVE_SIZE:
		archive.pop_front()
	meta.newspapers = archive
	meta.edition_no = n
	meta.last_edition_tick = sim.state.tick
	meta.last_snapshot = CatchUpSummary.snapshot(sim.state)
	meta.unread = true
	SimRunner.save_now()
	EventBus.newspaper_published.emit(edition, auto_open)
	request_newspaper_text(edition)
	return edition


func archive() -> Array:
	return SimRunner.meta.get("newspapers", [])


func latest() -> Dictionary:
	var a: Array = archive()
	return a[-1] if not a.is_empty() else {}


func mark_read() -> void:
	SimRunner.meta.unread = false


func has_unread() -> bool:
	return bool(SimRunner.meta.get("unread", false))


## Template text, with backend text laid over each story it covers.
func render(edition: Dictionary, lang: String = "") -> Dictionary:
	lang = _lang(lang)
	var page: Dictionary = writer(lang).render(edition)
	var ai: Dictionary = (SimRunner.meta.get("ai_news", {}) as Dictionary).get("%s:%d" % [lang, int(edition.edition)], {})
	if ai.is_empty():
		return page
	var keys: Array = (edition.stories as Array).map(func(s: Dictionary) -> String: return String(s.key))
	if keys.size() > 0 and ai.has(keys[0]):
		page.headline = {"key": keys[0], "title": String(ai[keys[0]].title), "body": String(ai[keys[0]].body)}
	var rest: Array = page.stories
	for i: int in rest.size():
		var k: String = keys[i + 1] if i + 1 < keys.size() else ""
		if ai.has(k):
			rest[i] = {"key": k, "title": String(ai[k].title), "body": String(ai[k].body)}
	page.ai = true
	return page


func writer(lang: String = "") -> TemplateWriter:
	if lang == "":
		lang = TranslationServer.get_locale().substr(0, 2)
	var t: Dictionary = _templates.get(lang, _templates[FALLBACK_LANG])
	return TemplateWriter.create(t, _templates[FALLBACK_LANG], func(k: String) -> String: return TranslationServer.translate(k))


## Rendered letter page (template text; M5 backend text replaces subject/body when present).
func letter_page(letter: Dictionary, lang: String = "") -> Dictionary:
	var sim: Simulation = SimRunner.sim
	var c: Citizen = CitizenSystem.citizen_by_id(sim.state, int(letter.citizen))
	var topic: Dictionary = CitizenSystem.topic_def(sim, String(letter.topic))
	var page: Dictionary = letter_writer(lang).render(letter, c.to_dict() if c != null else {}, topic.get("options", []))
	var ai: Dictionary = (SimRunner.meta.get("ai_letters", {}) as Dictionary).get("%s:%d" % [_lang(lang), int(letter.id)], {})
	if not ai.is_empty():
		page.subject = ai.subject
		page.greeting = ai.greeting
		page.body = ai.body
		page.signoff = ai.signoff
		page.memory_line = "" # the backend weaves the memory into the body
		page.ai = true
	return page


# --- Backend ---------------------------------------------------------------

func request_newspaper_text(edition: Dictionary, lang: String = "") -> void:
	lang = _lang(lang)
	var key: String = "%s:%d" % [lang, int(edition.edition)]
	if not backend_enabled or (SimRunner.meta.get("ai_news", {}) as Dictionary).has(key):
		return
	var page: Dictionary = writer(lang).render(edition)
	var body: Dictionary = AiPayloads.newspaper(SimRunner.sim, edition, page, lang, writer(lang))
	_enqueue({"kind": "news", "key": key, "path": "/v1/newspaper", "body": body})


func request_letter_text(letter: Dictionary, lang: String = "") -> void:
	lang = _lang(lang)
	var key: String = "%s:%d" % [lang, int(letter.id)]
	if not backend_enabled or (SimRunner.meta.get("ai_letters", {}) as Dictionary).has(key):
		return
	var c: Citizen = CitizenSystem.citizen_by_id(SimRunner.sim.state, int(letter.citizen))
	if c == null:
		return
	var page: Dictionary = letter_writer(lang).render(letter, c.to_dict(), CitizenSystem.topic_def(SimRunner.sim, String(letter.topic)).get("options", []))
	var body: Dictionary = AiPayloads.letter(SimRunner.sim, letter, c, page, lang, TranslationServer.translate(c.occupation_key))
	_enqueue({"kind": "letter", "key": key, "id": int(letter.id), "path": "/v1/letter", "body": body})


func backend_idle() -> bool:
	return not _busy and _queue.is_empty()


func _enqueue(job: Dictionary) -> void:
	# Kind is part of the key: newspaper "tr:1" and letter "tr:1" are different texts.
	var attempt_key: String = "%s/%s" % [job.kind, job.key]
	if _attempted.has(attempt_key):
		return
	_attempted[attempt_key] = true
	_queue.append(job)
	_pump()


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	var job: Dictionary = _queue[0]
	var headers: PackedStringArray = ["Content-Type: application/json", "X-Device-Id: " + Settings.device_id]
	_http.timeout = backend_timeout_s
	if _http.request(backend_url.trim_suffix("/") + String(job.path), headers, HTTPClient.METHOD_POST, JSON.stringify(job.body)) == OK:
		_busy = true
	else:
		_queue.pop_front()
		_pump.call_deferred()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var job: Dictionary = _queue.pop_front() if not _queue.is_empty() else {}
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and not job.is_empty():
		var json := JSON.new()
		var parsed: Variant = json.data if json.parse(body.get_string_from_utf8()) == OK else null
		if String(job.kind) == "news":
			var stories: Dictionary = AiPayloads.accept_newspaper(parsed)
			if not stories.is_empty():
				_store("ai_news", String(job.key), stories)
				EventBus.newspaper_text_updated.emit(int(job.body.edition))
		else:
			var text: Dictionary = AiPayloads.accept_letter(parsed)
			if not text.is_empty():
				_store("ai_letters", String(job.key), text)
				EventBus.letter_text_updated.emit(int(job.id))
	elif not job.is_empty():
		# Templates stay; we try again next session (the backend may be over its daily limit).
		push_warning("TextService: backend %s failed (result %d, http %d); using templates" % [job.path, result, code])
	_pump()


func _store(section: String, key: String, value: Dictionary) -> void:
	var m: Dictionary = SimRunner.meta.get(section, {})
	m[key] = value
	# Keep the archive small: only the newest entries survive.
	while m.size() > 60:
		m.erase(m.keys()[0])
	SimRunner.meta[section] = m
	SimRunner.save_now()


func _load_backend_config() -> void:
	var cfg: Dictionary = _read(BACKEND_CONFIG)
	backend_url = String(cfg.get("url", ""))
	backend_enabled = bool(cfg.get("enabled", false))
	backend_timeout_s = float(cfg.get("timeout_s", 10.0))
	var override: String = OS.get_environment("SEHIR_BACKEND_URL")
	if override != "":
		backend_url = override
		backend_enabled = true


func _lang(lang: String) -> String:
	return lang if lang != "" else TranslationServer.get_locale().substr(0, 2)


func letter_writer(lang: String = "") -> LetterWriter:
	if lang == "":
		lang = TranslationServer.get_locale().substr(0, 2)
	var t: Dictionary = _letter_templates.get(lang, _letter_templates[FALLBACK_LANG])
	return LetterWriter.create(t, _letter_templates[FALLBACK_LANG], func(k: String) -> String: return TranslationServer.translate(k))


func _on_catch_up_finished(s: RefCounted) -> void:
	var summary: CatchUpSummary = s as CatchUpSummary
	if summary.away_ticks() >= MIN_AWAY_TICKS or not summary.highlights.is_empty():
		publish(true, summary.before)


func _on_sim_event(e: RefCounted) -> void:
	var ev: SimEvent = e as SimEvent
	if ev.type == "day_started":
		publish(false)
	elif ev.type == "letter_received":
		request_letter_text(CitizenSystem.letter_by_id(SimRunner.sim.state, int(ev.data.letter_id)))


func _maybe_first_edition() -> void:
	if SimRunner.sim != null and not SimRunner.catching_up and int(SimRunner.meta.get("edition_no", 0)) == 0:
		publish(true)


static func _read(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}
