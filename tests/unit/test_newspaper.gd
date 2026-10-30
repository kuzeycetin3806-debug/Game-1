extends GutTest

var editorial: Dictionary
var tr_t: Dictionary
var en_t: Dictionary


func before_all() -> void:
	editorial = JSON.parse_string(FileAccess.get_file_as_string("res://data/text_templates/editorial.json"))
	tr_t = JSON.parse_string(FileAccess.get_file_as_string("res://data/text_templates/news_tr.json"))
	en_t = JSON.parse_string(FileAccess.get_file_as_string("res://data/text_templates/news_en.json"))


func _writer(t: Dictionary) -> TemplateWriter:
	return TemplateWriter.create(t, tr_t, func(k: String) -> String: return "<" + k + ">")


func _full_vars() -> Dictionary:
	return {"district": "Lale", "building_key": "BLD_CAFE", "policy_key": "POL_BIKE_LANES", "population": 2500}


func test_every_template_fills_completely() -> void:
	for t: Dictionary in [tr_t, en_t]:
		var w: TemplateWriter = _writer(t)
		for key: String in (t.stories as Dictionary):
			for count: int in [1, 3]:
				for ed: int in range(1, 6):
					var txt: Dictionary = w.story_text({"key": key, "count": count, "vars": _full_vars()}, ed)
					assert_false(String(txt.title).contains("{") or String(txt.body).contains("{"), "%s/%d unresolved: %s" % [key, count, txt])
					assert_ne(String(txt.title), "", key)


func test_every_event_has_a_story_template() -> void:
	var c: ContentDb = SimFixture.content()
	for id: String in c.event_order:
		assert_true((tr_t.stories as Dictionary).has("story." + id), "tr missing story." + id)
		assert_true((en_t.stories as Dictionary).has("story." + id), "en missing story." + id)
	for cat: String in BuildingDef.CATEGORIES:
		assert_true((tr_t.stories as Dictionary).has("built." + cat), "built." + cat)
	for w: String in (c.weather.notable as Array):
		assert_true((tr_t.stories as Dictionary).has("weather." + w), "weather." + w)


func test_same_kind_stories_merge() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var events: Array[SimEvent] = [
		SimEvent.create("building_completed", 1, {"def": "cafe", "building_id": 1, "cell": [1, 1]}),
		SimEvent.create("building_completed", 2, {"def": "shop_row", "building_id": 2, "cell": [2, 1]}),
	]
	var ed: Dictionary = NewsDesk.build(sim, events, 1, 0, {}, editorial)
	var built: Array = (ed.stories as Array).filter(func(s: Dictionary) -> bool: return String(s.key) == "built.commercial")
	assert_eq(built.size(), 1)
	assert_eq(int(built[0].count), 2)
	var text: Dictionary = _writer(tr_t).story_text(built[0], 1)
	assert_string_contains(String(text.title), "2")


func test_headline_is_most_important() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var events: Array[SimEvent] = [
		SimEvent.create("building_completed", 1, {"def": "cafe", "building_id": 1, "cell": [1, 1]}),
		SimEvent.create("population_milestone", 5, {"population": 500}),
		SimEvent.create("story", 3, {"id": "lost_cat_found", "importance": 15, "district": "Lale"}),
	]
	var ed: Dictionary = NewsDesk.build(sim, events, 1, 0, {}, editorial)
	assert_eq(String(ed.stories[0].key), "milestone")


func test_quiet_window_gets_fillers() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var ed: Dictionary = NewsDesk.build(sim, [] as Array[SimEvent], 1, 0, {}, editorial)
	assert_eq((ed.stories as Array).size(), int(editorial.min_stories))
	assert_string_starts_with(String(ed.stories[0].key), "filler.")


func test_events_before_window_ignored() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var events: Array[SimEvent] = [SimEvent.create("population_milestone", 5, {"population": 500})]
	var ed: Dictionary = NewsDesk.build(sim, events, 1, 10, {}, editorial)
	for s: Dictionary in ed.stories:
		assert_ne(String(s.key), "milestone")


func test_week_long_edition_is_reproducible() -> void:
	var texts: Array = []
	for i: int in 2:
		var sim: Simulation = SimFixture.new_sim()
		var before: Dictionary = CatchUpSummary.snapshot(sim.state)
		SimFixture.place(sim, "office_mid", Vector2i(25, 25))
		var events: Array[SimEvent] = SimFixture.run(sim, 7 * 144)
		var ed: Dictionary = NewsDesk.build(sim, events, 4, 0, before, editorial)
		assert_gte((ed.stories as Array).size(), 3)
		texts.append(JSON.stringify(_writer(tr_t).render(ed)))
	assert_eq(texts[0], texts[1])
	var page: Dictionary = JSON.parse_string(texts[0])
	assert_eq(String(page.masthead), "Nefeskent Postası")
	assert_string_contains(String(page.edition_line), "Sayı 4")
	assert_string_contains(String(page.edition_line), "Kasım", "7 days after Oct 28 is in November")
	assert_eq((page.weather.forecast as Array).size(), 3)
	assert_eq((page.numbers as Array).size(), 4)


func test_english_falls_back_to_turkish_for_missing_keys() -> void:
	var partial: Dictionary = {"stories": {}, "masthead": "X"}
	var w: TemplateWriter = TemplateWriter.create(partial, tr_t, func(k: String) -> String: return k)
	var txt: Dictionary = w.story_text({"key": "milestone", "count": 1, "vars": {"population": 100}}, 1)
	assert_string_contains(String(txt.title), "100")


func test_date_text() -> void:
	var w: TemplateWriter = _writer(tr_t)
	assert_eq(w.date_text({"year": 2026, "month": 10, "day": 28, "weekday": 3}), "28 Ekim 2026, Çarşamba")
	assert_eq(_writer(en_t).date_text({"year": 2026, "month": 10, "day": 28, "weekday": 3}), "Wednesday, October 28, 2026")


func test_first_edition_welcomes_the_mayor() -> void:
	var sim: Simulation = SimFixture.new_sim()
	var ed: Dictionary = NewsDesk.build(sim, [] as Array[SimEvent], 1, 0, {}, editorial)
	assert_eq(String(ed.stories[0].key), "welcome")
	var later: Dictionary = NewsDesk.build(sim, [] as Array[SimEvent], 2, 0, {}, editorial)
	assert_ne(String(later.stories[0].key), "welcome")
