class_name ChoosePolicyCommand
extends Command
## Enact or repeal a city policy. Effects start after the policy's delay;
## its daily cost starts at once.

var policy_id: String
var enable: bool = true


static func create(p_id: String, p_enable: bool) -> ChoosePolicyCommand:
	var c := ChoosePolicyCommand.new()
	c.policy_id = p_id
	c.enable = p_enable
	return c


func type_name() -> String:
	return "choose_policy"


func validate(sim: Simulation) -> String:
	var def: Dictionary = sim.content.policies.get(policy_id, {})
	if def.is_empty():
		return "ERR_UNKNOWN_POLICY"
	var s: SimState = sim.state
	if not enable:
		return "" if s.policies.has(policy_id) else "ERR_POLICY_NOT_ACTIVE"
	if s.policies.has(policy_id):
		return "ERR_POLICY_ACTIVE"
	for other: Variant in def.get("conflicts", []):
		if s.policies.has(String(other)):
			return "ERR_POLICY_CONFLICT"
	if s.population < int(def.get("min_population", 0)):
		return "ERR_POLICY_TOO_SMALL"
	if s.money_cents < int(def.setup_cost) * SimConfig.CENTS:
		return "ERR_NOT_ENOUGH_MONEY"
	return ""


func apply(sim: Simulation) -> Array[SimEvent]:
	var s: SimState = sim.state
	var def: Dictionary = sim.content.policies[policy_id]
	if not enable:
		s.policies.erase(policy_id)
		return [SimEvent.create("policy_repealed", s.tick, {"policy": policy_id})]
	var cost: int = int(def.setup_cost) * SimConfig.CENTS
	s.money_cents -= cost
	s.day_expense_cents += cost
	var active_from: int = s.tick + int(def.delay_hours) * SimConfig.TICKS_PER_DAY / 24
	s.policies[policy_id] = {"since": s.tick, "active_from": active_from}
	return [SimEvent.create("policy_enacted", s.tick, {"policy": policy_id, "active_from": active_from, "cost": int(def.setup_cost)})]


func _payload() -> Dictionary:
	return {"policy": policy_id, "enable": enable}
