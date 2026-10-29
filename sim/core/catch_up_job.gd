class_name CatchUpJob
extends RefCounted
## Runs a catch-up on a Simulation that nobody else touches (a clone), so it can
## execute on a worker thread. `done` is written by the worker and only read
## for the progress bar.

var sim: Simulation
var steps: int = 0
var done: int = 0
var summary: CatchUpSummary = CatchUpSummary.new()
var finished: bool = false


static func create(p_sim: Simulation, p_steps: int) -> CatchUpJob:
	var j := CatchUpJob.new()
	j.sim = p_sim
	j.steps = p_steps
	j.summary.begin(p_sim.state)
	return j


## Adds events that happened before stepping (e.g. the sleep realign).
func add_preamble(events: Array[SimEvent]) -> void:
	summary.add(events)


func run() -> void:
	for i: int in steps:
		summary.add(sim.step())
		done = i + 1
	summary.finish(sim.state)
	finished = true
