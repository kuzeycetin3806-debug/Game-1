extends GutTest
## TextService against a local mock backend: success overlays text, failures
## and timeouts leave the templates in place.

const PORT: int = 18765
const T0: float = 1_761_609_600.0

var server: MockHttpServer
var _old: Dictionary = {}


func before_each() -> void:
	_old = {"dir": SaveService.save_dir, "url": TextService.backend_url, "enabled": TextService.backend_enabled, "timeout": TextService.backend_timeout_s}
	SaveService.save_dir = "user://test_saves/backend"
	SaveService.delete_all()
	Clock.frozen_unix_time = T0
	server = MockHttpServer.new()
	add_child_autofree(server)
	assert_eq(server.start(PORT), OK)
	TextService.backend_url = "http://127.0.0.1:%d" % PORT
	TextService.backend_enabled = true
	TextService.backend_timeout_s = 1.0
	TextService._attempted.clear()
	SimRunner.new_city(5150)


func after_each() -> void:
	await _wait_idle()
	SaveService.delete_all()
	SaveService.save_dir = _old.dir
	TextService.backend_url = _old.url
	TextService.backend_enabled = _old.enabled
	TextService.backend_timeout_s = _old.timeout
	Clock.frozen_unix_time = -1.0


func _wait_idle() -> void:
	for i: int in 400:
		await wait_process_frames(1)
		if TextService.backend_idle():
			return


func _publish() -> Dictionary:
	return TextService.publish(false)


func test_newspaper_text_from_backend_is_overlaid_and_saved() -> void:
	var ed: Dictionary = _publish()
	var first_key: String = String(ed.stories[0].key)
	server.body = JSON.stringify({"stories": [{"key": first_key, "title": "Yapay zekâ manşeti", "body": "Bu metin sahte backend'den geldi, şablonun yerini aldı."}]})
	TextService._attempted.clear()
	(SimRunner.meta.get("ai_news", {}) as Dictionary).clear()
	TextService.request_newspaper_text(ed, "tr")
	await _wait_idle()
	assert_eq(server.requests.size() >= 1, true)
	var req: Dictionary = server.requests[-1]
	assert_eq(String(req.path), "/v1/newspaper")
	assert_eq(String(req.headers.get("x-device-id", "")).length(), 32)
	var page: Dictionary = TextService.render(ed, "tr")
	assert_eq(String(page.headline.title), "Yapay zekâ manşeti")
	assert_true(bool(page.get("ai", false)))
	var saved: Dictionary = SaveService.load_city(SimRunner.content)
	assert_true((saved.meta.ai_news as Dictionary).has("tr:%d" % int(ed.edition)))


func test_backend_error_keeps_templates() -> void:
	server.status = 502
	server.body = "{\"error\":\"refused\"}"
	var ed: Dictionary = _publish()
	await _wait_idle()
	var page: Dictionary = TextService.render(ed, "tr")
	assert_false(bool(page.get("ai", false)))
	assert_ne(String(page.headline.title), "")


func test_timeout_keeps_templates_and_does_not_block_the_queue() -> void:
	server.silent = true
	var ed: Dictionary = _publish()
	await _wait_idle()
	assert_true(TextService.backend_idle(), "request timed out and the queue drained")
	assert_false(bool(TextService.render(ed, "tr").get("ai", false)))


func test_garbage_response_ignored() -> void:
	server.body = "this is not json"
	var ed: Dictionary = _publish()
	await _wait_idle()
	assert_false(bool(TextService.render(ed, "tr").get("ai", false)))


func test_disabled_backend_sends_nothing() -> void:
	TextService.backend_enabled = false
	_publish()
	await wait_process_frames(10)
	assert_eq(server.requests.size(), 0)


func test_letter_text_from_backend_is_overlaid() -> void:
	server.body = JSON.stringify({"subject": "Yapay zekâ konusu", "greeting": "Merhaba Başkanım,", "body": "Bu mektup sahte backend'den geldi ve şablonun yerini aldı.", "signoff": "Sevgiyle,"})
	var sim: Simulation = SimRunner.sim
	for i: int in 144 * 10:
		sim.step()
		if not sim.state.letters.is_empty():
			break
	var l: Dictionary = sim.state.letters[0]
	TextService.request_letter_text(l, "tr")
	await _wait_idle()
	# The city's first edition may be queued right after; look for the letter call.
	assert_true(server.requests.any(func(r: Dictionary) -> bool: return String(r.path) == "/v1/letter"))
	var page: Dictionary = TextService.letter_page(l, "tr")
	assert_eq(String(page.subject), "Yapay zekâ konusu")
	assert_eq(String(page.memory_line), "")


func test_edition_and_letter_with_same_number_are_both_requested() -> void:
	# Regression: "tr:1" (edition 1) and "tr:1" (letter 1) once shared a retry key.
	var sim: Simulation = SimRunner.sim
	for i: int in 144 * 10:
		sim.step()
		if not sim.state.letters.is_empty():
			break
	TextService._attempted.clear()
	TextService.request_newspaper_text({"edition": 1, "stories": [{"key": "filler.quiet", "count": 1, "vars": {}}], "date": {"year": 2026, "month": 10, "day": 28, "weekday": 3}, "numbers": {}, "weather": {"now": "clear", "forecast": []}}, "tr")
	TextService.request_letter_text(sim.state.letters[0], "tr")
	await _wait_idle()
	var paths: Array = server.requests.map(func(r: Dictionary) -> String: return String(r.path))
	assert_true(paths.has("/v1/newspaper") and paths.has("/v1/letter"), str(paths))
