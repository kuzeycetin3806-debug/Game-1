class_name ReplyLetterCommand
extends Command
## The mayor answers a citizen's letter with one of its preset options.

var letter_id: int
var option_id: String


static func create(p_letter: int, p_option: String) -> ReplyLetterCommand:
	var c := ReplyLetterCommand.new()
	c.letter_id = p_letter
	c.option_id = p_option
	return c


func type_name() -> String:
	return "reply_letter"


func validate(sim: Simulation) -> String:
	var l: Dictionary = CitizenSystem.letter_by_id(sim.state, letter_id)
	if l.is_empty():
		return "ERR_NO_SUCH_LETTER"
	if String(l.status) != "open":
		return "ERR_LETTER_CLOSED"
	if _option(sim, l).is_empty():
		return "ERR_UNKNOWN_REPLY"
	var cost: int = 0
	for eff: Variant in _option(sim, l).get("effects", []):
		if String((eff as Dictionary).type) == "money" and int((eff as Dictionary).amount) < 0:
			cost -= int((eff as Dictionary).amount)
	if sim.state.money_cents < cost * SimConfig.CENTS:
		return "ERR_NOT_ENOUGH_MONEY"
	return ""


func apply(sim: Simulation) -> Array[SimEvent]:
	var s: SimState = sim.state
	var l: Dictionary = CitizenSystem.letter_by_id(s, letter_id)
	var opt: Dictionary = _option(sim, l)
	l.status = "answered"
	l.reply = option_id
	l.reply_tick = s.tick
	var rng: SimRng = SimRng.for_tick(s.city_seed, s.tick, SimConfig.STREAM_CITIZENS)
	# Same effect vocabulary as events; the letter's topic is the source.
	EventEngine.apply_effects(sim, "letter:" + String(l.topic), opt.get("effects", []), rng)
	var c: Citizen = CitizenSystem.citizen_by_id(s, int(l.citizen))
	if c != null:
		c.mood = clampi(c.mood + int(opt.get("mood", 0)), -100, 100)
		c.remember({"tick": s.tick, "kind": "letter_answered", "ref": String(l.topic) + ":" + option_id, "valence": int(opt.get("memory", 0))},
			sim.content.bal_int("citizens.memory_size", 6))
	return [SimEvent.create("letter_answered", s.tick, {"letter_id": letter_id, "citizen": int(l.citizen), "topic": String(l.topic), "option": option_id})]


func _option(sim: Simulation, l: Dictionary) -> Dictionary:
	for o: Variant in CitizenSystem.topic_def(sim, String(l.topic)).get("options", []):
		if String((o as Dictionary).id) == option_id:
			return o
	return {}


func _payload() -> Dictionary:
	return {"letter_id": letter_id, "option": option_id}
