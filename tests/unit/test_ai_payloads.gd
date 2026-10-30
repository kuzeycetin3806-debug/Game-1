extends GutTest


func _sim_with_letter() -> Simulation:
	var sim: Simulation = SimFixture.new_sim()
	for i: int in 144 * 10:
		sim.step()
		if not sim.state.letters.is_empty():
			break
	return sim


func test_accept_letter_rejects_bad_shapes() -> void:
	assert_eq(AiPayloads.accept_letter(null), {})
	assert_eq(AiPayloads.accept_letter({"subject": "Hi"}), {})
	assert_eq(AiPayloads.accept_letter({"subject": "Hey", "greeting": "Hi", "body": "x".repeat(900), "signoff": "Bye"}), {})
	var ok: Dictionary = AiPayloads.accept_letter({"subject": "Merhaba", "greeting": "Selam,", "body": "Uzun ve güzel bir mektup.", "signoff": "Sevgiyle,", "extra": 1})
	assert_eq(ok.keys().size(), 4, "extra fields dropped")


func test_accept_newspaper_drops_bad_stories() -> void:
	var got: Dictionary = AiPayloads.accept_newspaper({"stories": [
		{"key": "milestone", "title": "Nüfus 250!", "body": "Şehir büyümeye devam ediyor."},
		{"key": "x", "title": "", "body": "?"},
	]})
	assert_eq(got.keys(), ["milestone"])
	assert_eq(AiPayloads.accept_newspaper({"nope": 1}), {})


func test_letter_payload_has_only_contract_fields() -> void:
	var sim: Simulation = _sim_with_letter()
	assert_false(sim.state.letters.is_empty())
	var l: Dictionary = sim.state.letters[0]
	var c: Citizen = CitizenSystem.citizen_by_id(sim.state, int(l.citizen))
	var page: Dictionary = {"subject": "S", "body": "B", "memory_line": "", "options": [{"id": "a", "label": "A"}]}
	var p: Dictionary = AiPayloads.letter(sim, l, c, page, "tr", "Hemşire")
	var keys: Array = p.keys()
	keys.sort()
	assert_eq(keys, ["citizen", "city", "lang", "letter_id", "options", "template_body", "template_subject", "tone", "topic"])
	assert_false(p.has("memory"), "no memory line, no field")
	assert_eq((p.citizen as Dictionary).keys().size(), 8)
