extends SceneTree
## Measures catch-up speed: 14 days (2016 ticks) on the default town plus extra buildings.


func _initialize() -> void:
	var content: ContentDb = ContentDb.load_default()
	var sim: Simulation = Simulation.new_game(content, 42, 1_761_609_600, 10800)
	# Fill empty lots to approximate a mid-game city.
	var placed: int = 0
	var ids: Array[String] = content.building_order
	sim.state.money_cents = 1_000_000_000_00
	for x: int in sim.state.grid_size:
		for y: int in sim.state.grid_size:
			var cmd := PlaceBuildingCommand.create(ids[(x * 7 + y * 3) % ids.size()], Vector2i(x, y))
			if sim.apply_command(cmd).ok:
				placed += 1
	var t0: int = Time.get_ticks_usec()
	for i: int in 2016:
		sim.step()
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("buildings=%d  2016 ticks: %.1f ms (%.3f ms/tick)  pop=%d happy=%d traffic=%d" % [
		sim.state.buildings.size(), ms, ms / 2016.0, sim.state.population, sim.state.happiness, sim.state.traffic])
	quit()
