extends SceneTree
## Writes real request bodies the game would send, for backend/test/contract.test.ts.
## Re-run after changing AiPayloads or backend/src/schemas.ts.
## Usage: godot --headless --path . -s tools/make_backend_fixtures.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ts: Node = root.get_node("TextService")
	var content: ContentDb = ContentDb.load_default()
	var sim: Simulation = Simulation.new_game(content, 777, 1_761_609_600, 10800)
	var events: Array[SimEvent] = []
	sim.apply_command(PlaceBuildingCommand.create("cafe", Vector2i(25, 25)))
	sim.apply_command(ChoosePolicyCommand.create("bike_lanes", true))
	for i: int in 144 * 6:
		events.append_array(sim.step())
	root.get_node("SimRunner").set("sim", sim)
	var editorial: Dictionary = ts.get("editorial")
	var edition: Dictionary = NewsDesk.build(sim, events, 2, 0, CatchUpSummary.snapshot(sim.state), editorial)
	var w: TemplateWriter = ts.call("writer", "tr")
	var page: Dictionary = w.render(edition)
	_write("res://backend/test/fixtures/newspaper_request.json", AiPayloads.newspaper(sim, edition, page, "tr", w))
	var letter: Dictionary = {}
	for raw: Variant in sim.state.letters:
		letter = raw
	if letter.is_empty():
		printerr("no letter in 6 days; change the seed")
		quit(1)
		return
	var c: Citizen = CitizenSystem.citizen_by_id(sim.state, int(letter.citizen))
	var lp: Dictionary = (ts.call("letter_writer", "tr") as LetterWriter).render(letter, c.to_dict(), CitizenSystem.topic_def(sim, String(letter.topic)).options)
	_write("res://backend/test/fixtures/letter_request.json", AiPayloads.letter(sim, letter, c, lp, "tr", TranslationServer.translate(c.occupation_key)))
	quit()


func _write(path: String, d: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "  ", true) + "\n")
	f.close()
	print("wrote ", path)
