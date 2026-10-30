class_name Command
extends RefCounted
## A player decision. Commands are stamped with the tick they were applied
## before, logged, and replayed in order — that is what makes the city a pure
## function of (seed, commands, ticks).

var tick: int = -1


func type_name() -> String:
	return "command"


## Empty string when allowed, otherwise a translation key explaining why not.
func validate(_sim: Simulation) -> String:
	return ""


func apply(_sim: Simulation) -> Array[SimEvent]:
	return []


func to_dict() -> Dictionary:
	var d: Dictionary = _payload()
	d["type"] = type_name()
	d["tick"] = tick
	return d


func _payload() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> Command:
	var cmd: Command
	match String(d.get("type", "")):
		"place_building":
			cmd = PlaceBuildingCommand.create(String(d.def), Vector2i(int(d.cell[0]), int(d.cell[1])))
		"demolish":
			cmd = DemolishCommand.create(int(d.building_id))
		"choose_policy":
			cmd = ChoosePolicyCommand.create(String(d.policy), bool(d.enable))
		"realign_clock":
			cmd = RealignClockCommand.create(int(d.shift_seconds))
		_:
			push_error("Unknown command type: %s" % d.get("type", ""))
			return null
	cmd.tick = int(d.get("tick", -1))
	return cmd
