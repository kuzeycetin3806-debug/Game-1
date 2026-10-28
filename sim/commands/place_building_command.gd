class_name PlaceBuildingCommand
extends Command

var def_id: String
var cell: Vector2i


static func create(p_def: String, p_cell: Vector2i) -> PlaceBuildingCommand:
	var c := PlaceBuildingCommand.new()
	c.def_id = p_def
	c.cell = p_cell
	return c


func type_name() -> String:
	return "place_building"


func validate(sim: Simulation) -> String:
	var def: BuildingDef = sim.content.get_building(def_id)
	if def == null:
		return "ERR_UNKNOWN_BUILDING"
	var fp: String = sim.grid.check_footprint(cell, def.size)
	if fp != "":
		return fp
	if sim.state.money_cents < def.cost * SimConfig.CENTS:
		return "ERR_NOT_ENOUGH_MONEY"
	return ""


func apply(sim: Simulation) -> Array[SimEvent]:
	var def: BuildingDef = sim.content.get_building(def_id)
	var s: SimState = sim.state
	var ready: int = s.tick + def.build_hours * SimConfig.TICKS_PER_DAY / 24
	var b := BuildingInstance.create(s.next_building_id, def_id, cell, s.tick, ready)
	s.next_building_id += 1
	s.money_cents -= def.cost * SimConfig.CENTS
	s.day_expense_cents += def.cost * SimConfig.CENTS
	s.buildings.append(b)
	sim.mark_buildings_changed()
	return [SimEvent.create("building_placed", s.tick, {"building_id": b.id, "def": def_id, "cell": [cell.x, cell.y], "ready_tick": ready, "cost": def.cost})]


func _payload() -> Dictionary:
	return {"def": def_id, "cell": [cell.x, cell.y]}
