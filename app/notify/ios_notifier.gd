class_name IosNotifier
extends LocalNotifier
## LocalNotifier backed by our iOS GDExtension (platform/ios, singleton "SehirNotificationsIOS").

const SINGLETON: String = "SehirNotificationsIOS"

var _ext: Object
var _next_id: int = 1


static func available() -> bool:
	return Engine.has_singleton(SINGLETON)


func _init() -> void:
	_ext = Engine.get_singleton(SINGLETON)


func is_supported() -> bool:
	return _ext != null


func request_permission() -> void:
	super.request_permission()
	_ext.call("request_permission")


func schedule(at_unix: int, title: String, body: String) -> void:
	super.schedule(at_unix, title, body)
	_ext.call("schedule", _next_id, maxi(at_unix - int(Time.get_unix_time_from_system()), 1), title, body)
	_next_id += 1


func cancel_all() -> void:
	super.cancel_all()
	_ext.call("cancel_all")
