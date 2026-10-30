class_name SaveMigrations
extends RefCounted
## Upgrades old save dictionaries step by step to the current format.
## NEVER delete an old step: players skip versions. Each new step gets a
## fixture in tests/fixtures/saves/ and a test.

const CURRENT: int = 3

## version N -> callable taking the v N dictionary and returning v N+1.
static func steps() -> Dictionary:
	return {1: _v1_to_v2, 2: _v2_to_v3}


## v2 (M4): weather, event engine bookkeeping, policies; save root gains "meta".
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var s: Dictionary = d.state
	s.weather = "clear"
	s.weather_block = -1
	s.flags = {}
	s.cooldowns = {}
	s.pending = []
	s.modifiers = []
	s.policies = {}
	s.story_seq = 0
	d.meta = {}
	return d


## Returns {ok: bool, data: Dictionary, error: String, from_version: int}.
static func migrate(d: Dictionary) -> Dictionary:
	return migrate_with(d, steps(), CURRENT)


static func migrate_with(d: Dictionary, table: Dictionary, current: int) -> Dictionary:
	if not d.has("save_version"):
		return {"ok": false, "data": d, "error": "ERR_SAVE_NO_VERSION", "from_version": -1}
	var v: int = int(d.save_version)
	var from: int = v
	if v > current:
		return {"ok": false, "data": d, "error": "ERR_SAVE_TOO_NEW", "from_version": from}
	var data: Dictionary = d.duplicate(true)
	while v < current:
		if not table.has(v):
			return {"ok": false, "data": d, "error": "ERR_SAVE_NO_MIGRATION", "from_version": from}
		data = (table[v] as Callable).call(data)
		v += 1
		data.save_version = v
	return {"ok": true, "data": data, "error": "", "from_version": from}


## v3 (M5): named citizens and their letters. Citizens appear at the next midnight.
static func _v2_to_v3(d: Dictionary) -> Dictionary:
	var s: Dictionary = d.state
	s.citizens = []
	s.next_citizen_id = 1
	s.letters = []
	s.next_letter_id = 1
	return d
