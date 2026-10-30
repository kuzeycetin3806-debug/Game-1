extends GutTest

var tr_t: Dictionary
var en_t: Dictionary


func before_all() -> void:
	tr_t = JSON.parse_string(FileAccess.get_file_as_string("res://data/text_templates/letters_tr.json"))
	en_t = JSON.parse_string(FileAccess.get_file_as_string("res://data/text_templates/letters_en.json"))


func _writer(t: Dictionary) -> LetterWriter:
	return LetterWriter.create(t, tr_t, func(k: String) -> String: return "<" + k + ">")


func _citizen(age: int = 40) -> Dictionary:
	return {"first": "Ayşe", "last": "Yılmaz", "age": age, "occupation": "OCC_NURSE"}


func test_every_topic_and_option_has_text_in_both_languages() -> void:
	for raw: Variant in SimFixture.content().citizens.topics:
		var topic: Dictionary = raw
		for t: Dictionary in [tr_t, en_t]:
			assert_true((t.topics as Dictionary).has(topic.id), "template for %s" % topic.id)
			for o: Variant in topic.options:
				assert_true((t.options as Dictionary).has((o as Dictionary).id), "label for %s" % (o as Dictionary).id)
		assert_true((tr_t.signoff as Dictionary).has(topic.tone), "signoff for tone " + String(topic.tone))


func test_render_fills_everything() -> void:
	for raw: Variant in SimFixture.content().citizens.topics:
		var topic: Dictionary = raw
		for t: Dictionary in [tr_t, en_t]:
			for id: int in range(1, 5):
				var letter: Dictionary = {"id": id, "topic": topic.id, "tone": topic.tone, "district": "Lale", "status": "open",
					"memory": {"kind": "policy_enacted", "ref": "bike_lanes", "valence": 10}}
				var page: Dictionary = _writer(t).render(letter, _citizen(30 + id * 10), topic.options)
				for k: String in ["subject", "greeting", "body", "memory_line", "signoff", "signature"]:
					assert_false(String(page[k]).contains("{"), "%s/%s unresolved: %s" % [topic.id, k, page[k]])
				assert_ne(String(page.body), "")
				assert_eq((page.options as Array).size(), (topic.options as Array).size())


func test_formality_follows_age() -> void:
	var letter: Dictionary = {"id": 1, "topic": "park_request", "tone": "request", "district": "Lale", "memory": {}}
	var young: Dictionary = _writer(tr_t).render(letter, _citizen(25), [])
	var old: Dictionary = _writer(tr_t).render(letter, _citizen(70), [])
	assert_true((tr_t.greeting.casual as Array).has(young.greeting))
	assert_true((tr_t.greeting.formal as Array).has(old.greeting))


func test_memory_line_mentions_the_decision() -> void:
	var line: String = _writer(tr_t).memory_line({"kind": "policy_enacted", "ref": "bike_lanes", "valence": 15}, 3, {})
	assert_string_contains(line, "<POL_BIKE_LANES>")
	assert_eq(_writer(tr_t).memory_line({}, 3, {}), "")


func test_answered_letter_shows_reply() -> void:
	var letter: Dictionary = {"id": 2, "topic": "park_thanks", "tone": "thanks", "district": "Lale", "status": "answered", "reply": "thank_back", "memory": {}}
	var page: Dictionary = _writer(tr_t).render(letter, _citizen(), [])
	assert_string_contains(String(page.status_line), "teşekkür")
