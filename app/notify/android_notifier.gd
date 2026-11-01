class_name AndroidNotifier
extends LocalNotifier
## LocalNotifier backed by our Android plugin (platform/android, singleton "SehirNotifications").

const SINGLETON: String = "SehirNotifications"

var _plugin: Object
var _next_id: int = 1


static func available() -> bool:
	return Engine.has_singleton(SINGLETON)


func _init() -> void:
	_plugin = Engine.get_singleton(SINGLETON)


func is_supported() -> bool:
	return _plugin != null


func request_permission() -> void:
	super.request_permission()
	_plugin.call("requestPermission")


func has_permission() -> bool:
	return bool(_plugin.call("hasPermission"))


func schedule(at_unix: int, title: String, body: String) -> void:
	super.schedule(at_unix, title, body)
	var delay: int = maxi(at_unix - int(Time.get_unix_time_from_system()), 1)
	_plugin.call("schedule", _next_id, delay, title, body)
	_next_id += 1


func cancel_all() -> void:
	super.cancel_all()
	_plugin.call("cancelAll")
