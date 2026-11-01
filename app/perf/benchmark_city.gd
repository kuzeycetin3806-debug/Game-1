class_name BenchmarkCity
extends RefCounted
## A fully built, busy town for performance tests: every free lot filled,
## everything already finished. Never saved, never shown outside the test.


static func build(content: ContentDb, start_unix: int, utc_offset_s: int) -> Simulation:
	var sim: Simulation = Simulation.new_game(content, 424242, start_unix, utc_offset_s)
	var s: SimState = sim.state
	var ids: Array[String] = content.building_order
	for x: int in s.grid_size:
		for y: int in s.grid_size:
			var def: BuildingDef = content.get_building(ids[(x * 7 + y * 3) % ids.size()])
			if sim.grid.check_footprint(Vector2i(x, y), def.size) != "":
				continue
			s.buildings.append(BuildingInstance.create(s.next_building_id, def.id, Vector2i(x, y), -1, 0))
			s.next_building_id += 1
			sim.mark_buildings_changed()
	sim.step() # refresh aggregates
	s.population = sim.aggregates.residents_capacity
	s.employed = mini(s.population * 6 / 10, sim.aggregates.jobs_total)
	s.traffic = 450
	return sim
