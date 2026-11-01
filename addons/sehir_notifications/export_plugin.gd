@tool
extends EditorPlugin
## Adds our notification AAR (built from platform/android, copied into bin/)
## and its AndroidX dependency to Android exports. Our own code, not third-party.

var _export_plugin: AndroidNotificationsExport


func _enter_tree() -> void:
	_export_plugin = AndroidNotificationsExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidNotificationsExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "SehirNotifications"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(["sehir_notifications/bin/sehir_notifications-%s.aar" % ("debug" if debug else "release")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["androidx.core:core:1.13.1"])
