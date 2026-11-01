// iOS local notifications for Şehir Nefes Alıyor (GDExtension, godot-cpp).
// GDScript: Engine.get_singleton("SehirNotificationsIOS").
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

#include <gdextension_interface.h>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

class SehirNotificationsIOS : public Object {
	GDCLASS(SehirNotificationsIOS, Object);

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("is_supported"), &SehirNotificationsIOS::is_supported);
		ClassDB::bind_method(D_METHOD("request_permission"), &SehirNotificationsIOS::request_permission);
		ClassDB::bind_method(D_METHOD("schedule", "id", "delay_seconds", "title", "body"), &SehirNotificationsIOS::schedule);
		ClassDB::bind_method(D_METHOD("cancel_all"), &SehirNotificationsIOS::cancel_all);
	}

public:
	bool is_supported() const { return true; }

	void request_permission() {
		UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
		[[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options
																			completionHandler:^(BOOL granted, NSError *error){
																			}];
	}

	void schedule(int id, int delay_seconds, const String &title, const String &body) {
		UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
		content.title = [NSString stringWithUTF8String:title.utf8().get_data()];
		content.body = [NSString stringWithUTF8String:body.utf8().get_data()];
		content.sound = [UNNotificationSound defaultSound];
		UNTimeIntervalNotificationTrigger *trigger =
				[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:(NSTimeInterval)MAX(delay_seconds, 1) repeats:NO];
		NSString *identifier = [NSString stringWithFormat:@"sehir.%d", id];
		UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
		[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
	}

	void cancel_all() {
		UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
		[center removeAllPendingNotificationRequests];
		[center removeAllDeliveredNotifications];
	}
};

static SehirNotificationsIOS *singleton = nullptr;

static void initialize_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ClassDB::register_class<SehirNotificationsIOS>();
	singleton = memnew(SehirNotificationsIOS);
	Engine::get_singleton()->register_singleton("SehirNotificationsIOS", singleton);
}

static void uninitialize_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE || singleton == nullptr) {
		return;
	}
	Engine::get_singleton()->unregister_singleton("SehirNotificationsIOS");
	memdelete(singleton);
	singleton = nullptr;
}

extern "C" {
GDExtensionBool GDE_EXPORT sehir_notifications_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_module);
	init_obj.register_terminator(uninitialize_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
