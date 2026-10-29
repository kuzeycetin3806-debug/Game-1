class_name SaveCodec
extends RefCounted
## Pure conversion between a Simulation and the save dictionary (CLAUDE.md §2.6).
## File IO lives in app/SaveService.


static func encode(sim: Simulation, wall_time: int, game_version: String) -> Dictionary:
	var cmds: Array = []
	for c: Command in sim.command_log:
		cmds.append(c.to_dict())
	return {
		"save_version": SaveMigrations.CURRENT,
		"game_version": game_version,
		"city_seed": sim.state.city_seed,
		"last_tick": sim.state.tick,
		"last_wall_time": wall_time,
		"state": sim.state.to_dict(),
		"state_hash": sim.state.hash(),
		"commands": cmds,
		"events": sim.event_log.to_array(),
	}


## Returns {ok: bool, sim: Simulation, error: String, last_wall_time: int, migrated_from: int}.
static func decode(d: Dictionary, content: ContentDb) -> Dictionary:
	var m: Dictionary = SaveMigrations.migrate(d)
	if not m.ok:
		return _fail(m.error)
	var data: Dictionary = m.data
	for key: String in ["state", "state_hash", "commands", "events", "last_wall_time"]:
		if not data.has(key):
			return _fail("ERR_SAVE_CORRUPT")
	if not data.state is Dictionary or not data.commands is Array or not data.events is Array:
		return _fail("ERR_SAVE_CORRUPT")
	var state: SimState = SimState.from_dict(data.state as Dictionary)
	# Hash guards against truncated/edited files: a mismatch means "use the backup".
	if state.hash() != int(data.state_hash):
		return _fail("ERR_SAVE_CORRUPT")
	for b: BuildingInstance in state.buildings:
		if content.get_building(b.def_id) == null:
			return _fail("ERR_SAVE_UNKNOWN_CONTENT")
	var sim: Simulation = Simulation.create(state, content)
	for raw: Variant in data.commands:
		var c: Command = Command.from_dict(raw as Dictionary)
		if c == null:
			return _fail("ERR_SAVE_CORRUPT")
		sim.command_log.append(c)
	sim.event_log = EventLog.from_array(data.events as Array)
	return {"ok": true, "sim": sim, "error": "", "last_wall_time": int(data.last_wall_time), "migrated_from": int(m.from_version)}


static func _fail(err: String) -> Dictionary:
	return {"ok": false, "sim": null, "error": err, "last_wall_time": 0, "migrated_from": -1}
