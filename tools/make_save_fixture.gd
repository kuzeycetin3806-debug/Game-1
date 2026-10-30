extends SceneTree
## Writes a frozen save fixture for the CURRENT save version.
## Run once when bumping SaveMigrations.CURRENT; never regenerate an old one.
## Usage: godot --headless --path . -s tools/make_save_fixture.gd


func _initialize() -> void:
	var content: ContentDb = ContentDb.load_default()
	var sim: Simulation = Simulation.new_game(content, 424242, 1_761_609_600, 10800)
	for i: int in 30:
		sim.step()
	sim.apply_command(PlaceBuildingCommand.create("cafe", Vector2i(25, 25)))
	sim.apply_command(PlaceBuildingCommand.create("pocket_park", Vector2i(26, 25)))
	sim.apply_command(ChoosePolicyCommand.create("night_market", true))
	for i: int in 300:
		sim.step()
	var path: String = "res://tests/fixtures/saves/v%d_city.json" % SaveMigrations.CURRENT
	if FileAccess.file_exists(path):
		printerr("refusing to overwrite ", path)
		quit(1)
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(SaveCodec.encode(sim, 1_761_609_600 + 330 * 600, "0.1.0"), "  ", true))
	f.close()
	print("wrote ", path)
	quit()
