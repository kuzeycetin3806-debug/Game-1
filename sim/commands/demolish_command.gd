class_name DemolishCommand
extends Command

var building_id: int


static func create(p_id: int) -> DemolishCommand:
	var c := DemolishCommand.new()
	c.building_id = p_id
	return c


func type_name() -> String:
	return "demolish"


func validate(sim: Simulation) -> String:
	if sim.state.building_by_id(building_id) == null:
		return "ERR_NO_SUCH_BUILDING"
	return ""


func apply(sim: Simulation) -> Array[SimEvent]:
	var s: SimState = sim.state
	var b: BuildingInstance = s.building_by_id(building_id)
	var def: BuildingDef = sim.content.get_building(b.def_id)
	var refund: int = def.cost * SimConfig.CENTS * sim.content.bal_int("demolish_refund_permille", 300) / SimConfig.PERMILLE
	s.money_cents += refund
	s.day_income_cents += refund
	s.buildings.erase(b)
	sim.mark_buildings_changed()
	return [SimEvent.create("building_demolished", s.tick, {"building_id": b.id, "def": b.def_id, "cell": [b.cell.x, b.cell.y], "refund": refund / SimConfig.CENTS})]


func _payload() -> Dictionary:
	return {"building_id": building_id}
