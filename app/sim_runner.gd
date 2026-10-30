extends Node
## Owns the Simulation and drives it from the wall clock. Startup and resume:
## load → plan catch-up → run it on a worker thread over a clone → swap in.
## The only bridge between the pure sim and Godot signals.

## Gaps up to this many ticks are stepped inline; bigger ones get the catch-up flow.
const LIVE_MAX_TICKS: int = 6
## Live stepping budget per frame (gap <= LIVE_MAX_TICKS anyway).
const MAX_TICKS_PER_FRAME: int = 8
const AUTOSAVE_EVERY_TICKS: int = 6 # hourly

var sim: Simulation
var content: ContentDb
## App-side data saved next to the city (newspaper archive, read markers). Not simulated.
var meta: Dictionary = {}
var catching_up: bool = false
## Set when the last load had to fall back to the backup file.
var recovered_from_backup: bool = false

## Local notifications planned when the app goes to the background.
var notifier: LocalNotifier = LocalNotifier.for_platform()
var notification_rules: Dictionary = {}

var _job: CatchUpJob
var _task_id: int = -1
var _ticks_since_save: int = 0


func _ready() -> void:
	content = ContentDb.load_default()
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/notifications.json"))
	notification_rules = rules if rules is Dictionary else {}
	if not content.is_valid():
		for e: String in content.errors:
			push_error(e)
	# Tests drive the runner themselves; no background catch-up racing them.
	if OS.get_environment("SEHIR_TEST") == "1":
		_found_city(1)
		return
	load_or_create()


## Loads the saved city (or founds a new one) and catches it up to now.
func load_or_create() -> void:
	_abort_job()
	var r: Dictionary = SaveService.load_city(content)
	recovered_from_backup = bool(r.get("recovered", false))
	if r.ok:
		sim = r.sim
		meta = r.meta
	else:
		if r.error != "ERR_SAVE_MISSING":
			push_warning("SimRunner: no usable save (%s), founding a new city" % r.error)
		_found_city(-1)
	EventBus.city_loaded.emit()
	begin_catch_up()


## Debug/new game: wipes the save.
func new_city(city_seed: int = -1) -> void:
	_abort_job()
	_found_city(city_seed)
	SaveService.save(sim, meta)
	EventBus.city_loaded.emit()


func _found_city(city_seed: int) -> void:
	meta = {}
	if city_seed < 0:
		city_seed = int(Time.get_unix_time_from_system()) ^ (Time.get_ticks_usec() & 0xFFFF)
	var offset: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	sim = Simulation.new_game(content, city_seed, int(Clock.now_unix()), offset)


## Brings the city up to the wall clock. Small gaps run inline; big ones run on
## a worker thread while the UI shows progress.
func begin_catch_up() -> void:
	if catching_up or sim == null:
		return
	var plan: Dictionary = CatchUp.plan(sim.state.tick, sim.state.start_unix, int(Clock.now_unix()))
	var preamble: Array[SimEvent] = []
	if int(plan.shift_seconds) != 0:
		var r: Dictionary = sim.apply_command(RealignClockCommand.create(int(plan.shift_seconds)))
		preamble = r.events
	var steps: int = int(plan.steps)
	if steps <= LIVE_MAX_TICKS and preamble.is_empty():
		return # _process handles it live
	catching_up = true
	_job = CatchUpJob.create(sim.clone(), steps)
	_job.add_preamble(preamble)
	EventBus.catch_up_started.emit(steps)
	_task_id = WorkerThreadPool.add_task(_job.run, false, "city catch-up")


func catch_up_progress() -> float:
	if _job == null or _job.steps == 0:
		return 1.0
	return float(_job.done) / float(_job.steps)


func _process(_delta: float) -> void:
	if sim == null:
		return
	if catching_up:
		_poll_job()
		return
	var plan: Dictionary = CatchUp.plan(sim.state.tick, sim.state.start_unix, int(Clock.now_unix()))
	if int(plan.steps) > LIVE_MAX_TICKS or int(plan.shift_seconds) != 0:
		begin_catch_up()
		return
	var budget: int = mini(int(plan.steps), MAX_TICKS_PER_FRAME)
	var changed: bool = false
	for i: int in budget:
		for e: SimEvent in sim.step():
			if e.type == "building_completed":
				changed = true
			EventBus.sim_event_emitted.emit(e)
		EventBus.tick_advanced.emit(sim.state.tick)
		_ticks_since_save += 1
	if changed:
		EventBus.city_changed.emit()
	if _ticks_since_save >= AUTOSAVE_EVERY_TICKS:
		save_now()


func _poll_job() -> void:
	EventBus.catch_up_progressed.emit(catch_up_progress())
	if not WorkerThreadPool.is_task_completed(_task_id):
		return
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	var job: CatchUpJob = _job
	_job = null
	# Swap on the main thread; nobody else touched the clone.
	sim = job.sim
	catching_up = false
	save_now()
	EventBus.city_changed.emit()
	EventBus.tick_advanced.emit(sim.state.tick)
	EventBus.catch_up_finished.emit(job.summary)


func _abort_job() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	_job = null
	catching_up = false


## Applies a player command now. Returns the sim result dictionary.
func submit(cmd: Command) -> Dictionary:
	if catching_up:
		EventBus.command_rejected.emit("ERR_CITY_BUSY")
		return {"ok": false, "error": "ERR_CITY_BUSY", "events": [] as Array[SimEvent]}
	var result: Dictionary = sim.apply_command(cmd)
	if result.ok:
		for e: SimEvent in result.events:
			EventBus.sim_event_emitted.emit(e)
		EventBus.city_changed.emit()
		save_now()
	else:
		EventBus.command_rejected.emit(result.error)
	return result


func check(cmd: Command) -> String:
	if catching_up:
		return "ERR_CITY_BUSY"
	return sim.can_apply(cmd)


func save_now() -> void:
	if sim == null or catching_up:
		return
	_ticks_since_save = 0
	SaveService.save(sim, meta)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			save_now()
			schedule_notifications()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_now()
		NOTIFICATION_APPLICATION_RESUMED:
			notifier.cancel_all()
			begin_catch_up()


## Forecasts the next hours on a clone and schedules the few moments worth a ping.
## Returns what was scheduled (for tests and the debug panel).
func schedule_notifications() -> Array[Dictionary]:
	notifier.cancel_all()
	if sim == null or catching_up or not Settings.notifications:
		return []
	if not notifier.permission_requested:
		notifier.request_permission()
	var plan: Array[Dictionary] = NotificationPlanner.plan(sim.clone(), notification_rules)
	for n: Dictionary in plan:
		notifier.schedule(int(n.at_unix), tr("NOTIF_TITLE"), notification_text(n))
	return plan


func notification_text(n: Dictionary) -> String:
	var args: Array = []
	for a: Variant in n.get("args", []):
		var s: String = String(a)
		if s.begins_with("story."):
			s = String(TextService.writer().story_text({"key": s, "count": 1, "vars": {}}, 0).title)
		elif s.begins_with("BLD_") or s.begins_with("POL_"):
			s = tr(s)
		args.append(s)
	var tmpl: String = tr(String(n.key))
	return tmpl % args if not args.is_empty() else tmpl
