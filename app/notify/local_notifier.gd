class_name LocalNotifier
extends RefCounted
## Platform adapter for local notifications. This base class records what it
## would do (desktop, tests); AndroidNotifier / IosNotifier deliver for real
## through our own plugins (platform/android, platform/ios).

var scheduled: Array[Dictionary] = [] # {at_unix, title, body}
var permission_requested: bool = false


static func for_platform() -> LocalNotifier:
	if AndroidNotifier.available():
		return AndroidNotifier.new()
	if IosNotifier.available():
		return IosNotifier.new()
	return LocalNotifier.new()


func is_supported() -> bool:
	return false


func request_permission() -> void:
	permission_requested = true


func has_permission() -> bool:
	return false


func schedule(at_unix: int, title: String, body: String) -> void:
	scheduled.append({"at_unix": at_unix, "title": title, "body": body})


func cancel_all() -> void:
	scheduled.clear()
