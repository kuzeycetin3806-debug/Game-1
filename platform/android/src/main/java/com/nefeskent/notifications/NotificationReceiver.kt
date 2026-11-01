package com.nefeskent.notifications

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/** Fires when an alarm is due and posts the notification; tapping it opens the game. */
class NotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        Notifications.ensureChannel(context)
        val id = intent.getIntExtra(Notifications.EXTRA_ID, 0)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val content = launch?.let {
            PendingIntent.getActivity(context, id, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val notification = NotificationCompat.Builder(context, Notifications.CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(intent.getStringExtra(Notifications.EXTRA_TITLE) ?: "")
            .setContentText(intent.getStringExtra(Notifications.EXTRA_BODY) ?: "")
            .setStyle(NotificationCompat.BigTextStyle().bigText(intent.getStringExtra(Notifications.EXTRA_BODY) ?: ""))
            .setAutoCancel(true)
            .setContentIntent(content)
            .build()
        NotificationManagerCompat.from(context).notify(id, notification)
    }
}
