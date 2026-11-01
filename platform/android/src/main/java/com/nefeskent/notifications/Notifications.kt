package com.nefeskent.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/** Channel setup and the list of scheduled ids (so cancelAll can find them after a restart). */
object Notifications {
    const val CHANNEL_ID = "city_news"
    const val EXTRA_ID = "id"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    private const val PREFS = "sehir_notifications"
    private const val KEY_IDS = "ids"

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = ctx.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        // VARSAYIM: channel name in Turkish (the game's default language).
        val channel = NotificationChannel(CHANNEL_ID, "Şehir haberleri", NotificationManager.IMPORTANCE_DEFAULT)
        channel.description = "Mektuplar, kararlar ve sabah gazetesi"
        manager.createNotificationChannel(channel)
    }

    fun remember(ctx: Context, id: Int) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet(KEY_IDS, emptySet())!!.toMutableSet()
        ids.add(id.toString())
        prefs.edit().putStringSet(KEY_IDS, ids).apply()
    }

    fun scheduledIds(ctx: Context): List<Int> =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY_IDS, emptySet())!!
            .mapNotNull { it.toIntOrNull() }

    fun forgetAll(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY_IDS).apply()
    }
}
