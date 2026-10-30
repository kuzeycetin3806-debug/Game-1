class_name LocalNotifier
extends RefCounted
## Platform adapter for local notifications. This base class records what it
## would do (desktop, tests). A plugin-backed subclass is added once the
## Android/iOS notification plugin is chosen (see docs/PLAN.md, M6).

var scheduled: Array[Dictionary] = [] # {at_unix, title, body}
var permission_requested: bool = false


static func for_platform() -> LocalNotifier:
	# VARSAYIM: no notification plugin yet; every platform uses the recording notifier.
	return LocalNotifier.new()


func is_supported() -> bool:
	return false


func request_permission() -> void:
	permission_requested = true


func schedule(at_unix: int, title: String, body: String) -> void:
	scheduled.append({"at_unix": at_unix, "title": title, "body": body})


func cancel_all() -> void:
	scheduled.clear()
