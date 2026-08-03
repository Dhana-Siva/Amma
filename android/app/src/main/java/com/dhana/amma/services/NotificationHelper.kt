package com.dhana.amma.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.dhana.amma.MainActivity
import com.dhana.amma.R

/**
 * Android has no equivalent of iOS's automatic "back to app" pill that
 * appears when one app opens another via a URL scheme — this notification
 * is the closest substitute, giving the parent a real tap target to return
 * to Amma after being handed off to WhatsApp/Viber/Telegram for a call or
 * message. The backend's system prompt already tells Claude to remind the
 * parent verbally to "tap the small Amma link at the top of the screen" —
 * this notification is what makes that reminder literally true on Android.
 */
object NotificationHelper {
    // "_v2" because a channel's importance is locked at creation and can't
    // be raised retroactively for anyone who already has the old channel
    // from an earlier build — a new channel id is the only way to actually
    // change it, the original DEFAULT-importance channel just becomes
    // orphaned/unused, which is harmless.
    private const val CHANNEL_ID = "return_to_amma_v2"
    private const val NOTIFICATION_ID = 1001

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        // HIGH importance so this actually pops up as a heads-up banner —
        // DEFAULT only lands quietly in the shade, easy to miss entirely
        // for a parent who's actively over in WhatsApp/Viber/Telegram and
        // has no reason to think to pull down their notification shade.
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Return to Amma",
            NotificationManager.IMPORTANCE_HIGH,
        )
        val manager = context.getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }

    fun showReturnToAmma(context: Context, appLabel: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        val openAmma = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            openAmma,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Done in $appLabel?")
            .setContentText("Tap to come back to Amma")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            // Ongoing (not auto-dismissed, can't be swiped away) so it
            // stays as a small icon in the status bar the whole time the
            // parent is away in WhatsApp/Viber/Telegram, not just for the
            // few seconds a normal heads-up banner shows before dropping
            // into the shade. Cleared explicitly (see clearReturnToAmma)
            // once they actually come back to Amma, not by autoCancel.
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(NOTIFICATION_ID, notification)
    }

    fun clearReturnToAmma(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.cancel(NOTIFICATION_ID)
    }
}
