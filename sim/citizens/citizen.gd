class_name Citizen
extends RefCounted
## A named resident with a personality, interests, mood and a short memory of
## the mayor's decisions. Mood is -100..100; traits are 0..100.

var id: int
var first: String
var last: String
var age: int
var archetype: String
var occupation_key: String
var traits: Dictionary = {} # civic, eco, thrift, social, patience
var interests: Array = [] # Array of String
var home_block: String = ""
var mood: int = 0
## Newest last: [{tick, kind, ref, valence}]
var memory: Array = []
var letters_sent: int = 0
var last_letter_tick: int = -100000
var joined_tick: int = 0


func full_name() -> String:
	return "%s %s" % [first, last]


func has_interest(any_of: Array) -> bool:
	for i: Variant in any_of:
		if interests.has(i):
			return true
	return false


func remember(entry: Dictionary, capacity: int) -> void:
	memory.append(entry)
	while memory.size() > capacity:
		memory.pop_front()


## Most emotionally charged recent memory, or {} (letters quote it).
func strongest_memory() -> Dictionary:
	var best: Dictionary = {}
	var best_v: int = -1
	for i: int in range(memory.size() - 1, -1, -1):
		var m: Dictionary = memory[i]
		if absi(int(m.valence)) > best_v:
			best_v = absi(int(m.valence))
			best = m
	return best


func to_dict() -> Dictionary:
	return {"id": id, "first": first, "last": last, "age": age, "archetype": archetype, "occupation": occupation_key,
		"traits": traits.duplicate(), "interests": interests.duplicate(), "home_block": home_block, "mood": mood,
		"memory": memory.duplicate(true), "letters_sent": letters_sent, "last_letter_tick": last_letter_tick, "joined_tick": joined_tick}


static func from_dict(d: Dictionary) -> Citizen:
	var c := Citizen.new()
	c.id = int(d.id)
	c.first = String(d.first)
	c.last = String(d.last)
	c.age = int(d.age)
	c.archetype = String(d.archetype)
	c.occupation_key = String(d.occupation)
	c.traits = SimJson.ints(d.traits) as Dictionary
	c.interests = (d.interests as Array).duplicate()
	c.home_block = String(d.home_block)
	c.mood = int(d.mood)
	c.memory = SimJson.ints(d.memory) as Array
	c.letters_sent = int(d.letters_sent)
	c.last_letter_tick = int(d.last_letter_tick)
	c.joined_tick = int(d.joined_tick)
	return c
