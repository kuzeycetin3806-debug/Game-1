package com.nefeskent.notifications

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Local notifications for the game. GDScript sees it as Engine.get_singleton("SehirNotifications").
 * Times are passed as "seconds from now" so they fit a 32-bit int on the JNI bridge.
 */
class SehirNotificationsPlugin(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName(): String = "SehirNotifications"

    private val context: Context?
        get() = activity?.applicationContext

    @UsedByGodot
    fun isSupported(): Boolean = true

    @UsedByGodot
    fun hasPermission(): Boolean {
        val ctx = context ?: return false
        if (Build.VERSION.SDK_INT < 33) {
            return NotificationManagerCompat.from(ctx).areNotificationsEnabled()
        }
        return ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    @UsedByGodot
    fun requestPermission() {
        val act = activity ?: return
        if (Build.VERSION.SDK_INT >= 33 && !hasPermission()) {
            act.runOnUiThread {
                ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
            }
        }
    }

    @UsedByGodot
    fun schedule(id: Int, delaySeconds: Int, title: String, body: String) {
        val ctx = context ?: return
        Notifications.ensureChannel(ctx)
        val pending = alarmIntent(ctx, id, title, body)
        val alarms = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = System.currentTimeMillis() + maxOf(delaySeconds, 1) * 1000L
        // Inexact but Doze-friendly; no SCHEDULE_EXACT_ALARM permission needed.
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        Notifications.remember(ctx, id)
    }

    @UsedByGodot
    fun cancelAll() {
        val ctx = context ?: return
        val alarms = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (id in Notifications.scheduledIds(ctx)) {
            alarms.cancel(alarmIntent(ctx, id, "", ""))
        }
        Notifications.forgetAll(ctx)
        NotificationManagerCompat.from(ctx).cancelAll()
    }

    private fun alarmIntent(ctx: Context, id: Int, title: String, body: String): PendingIntent {
        val intent = Intent(ctx, NotificationReceiver::class.java)
            .putExtra(Notifications.EXTRA_ID, id)
            .putExtra(Notifications.EXTRA_TITLE, title)
            .putExtra(Notifications.EXTRA_BODY, body)
        return PendingIntent.getBroadcast(ctx, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    companion object {
        private const val REQUEST_CODE = 4711
    }
}
