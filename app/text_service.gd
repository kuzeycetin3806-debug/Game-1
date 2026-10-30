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

var editorial: Dictionary = {}
var _templates: Dictionary = {} # lang -> Dictionary


func _ready() -> void:
	editorial = _read(TEMPLATE_DIR.path_join("editorial.json"))
	for lang: String in ["tr", "en"]:
		_templates[lang] = _read(TEMPLATE_DIR.path_join("news_%s.json" % lang))
	EventBus.catch_up_finished.connect(_on_catch_up_finished)
	EventBus.sim_event_emitted.connect(_on_sim_event)
	EventBus.city_loaded.connect(func() -> void: _maybe_first_edition.call_deferred())


## Builds the next edition from everything since the previous one.
func publish(auto_open: bool) -> Dictionary:
	var sim: Simulation = SimRunner.sim
	var meta: Dictionary = SimRunner.meta
	var from: int = int(meta.get("last_edition_tick", 0))
	var before: Dictionary = meta.get("last_snapshot", CatchUpSummary.snapshot(sim.state))
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


func render(edition: Dictionary, lang: String = "") -> Dictionary:
	return writer(lang).render(edition)


func writer(lang: String = "") -> TemplateWriter:
	if lang == "":
		lang = TranslationServer.get_locale().substr(0, 2)
	var t: Dictionary = _templates.get(lang, _templates[FALLBACK_LANG])
	return TemplateWriter.create(t, _templates[FALLBACK_LANG], func(k: String) -> String: return TranslationServer.translate(k))


func _on_catch_up_finished(s: RefCounted) -> void:
	var summary: CatchUpSummary = s as CatchUpSummary
	if summary.away_ticks() >= MIN_AWAY_TICKS or not summary.highlights.is_empty():
		publish(true)


func _on_sim_event(e: RefCounted) -> void:
	if (e as SimEvent).type == "day_started":
		publish(false)


func _maybe_first_edition() -> void:
	if SimRunner.sim != null and not SimRunner.catching_up and int(SimRunner.meta.get("edition_no", 0)) == 0:
		publish(true)


static func _read(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}
