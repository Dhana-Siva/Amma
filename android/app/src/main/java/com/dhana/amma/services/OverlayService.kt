package com.dhana.amma.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat
import com.dhana.amma.MainActivity
import com.dhana.amma.R

/**
 * Shows a small floating "return to Amma" bubble over whatever app the
 * parent was handed off to (WhatsApp/Viber/Telegram) — a single direct
 * tap to come back, no swipe-down-then-tap notification gesture needed.
 * Requires SYSTEM_ALERT_WINDOW ("display over other apps"), which can
 * only be granted via a manual trip to system settings — see
 * OverlayHelper for the permission check/request and the fallback to a
 * plain notification when it isn't granted.
 */
class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var bubbleView: ImageView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createForegroundChannel()
        startForeground(FOREGROUND_NOTIFICATION_ID, buildForegroundNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (bubbleView == null) showBubble()
        return START_NOT_STICKY
    }

    private fun showBubble() {
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val sizePx = (56 * resources.displayMetrics.density).toInt()
        val paddingPx = (12 * resources.displayMetrics.density).toInt()
        val marginPx = (24 * resources.displayMetrics.density).toInt()

        val bubble = ImageView(this).apply {
            setImageResource(R.drawable.ic_notification)
            setBackgroundResource(R.drawable.bg_overlay_bubble)
            setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
            setColorFilter(Color.WHITE)
        }

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            x = marginPx
            y = marginPx * 3
        }

        bubble.setOnClickListener {
            val openAmma = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(openAmma)
            stopSelf()
        }

        wm.addView(bubble, params)
        bubbleView = bubble
    }

    override fun onDestroy() {
        super.onDestroy()
        bubbleView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (e: IllegalArgumentException) {
                // Already removed — nothing to do.
            }
        }
        bubbleView = null
    }

    private fun createForegroundChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            FOREGROUND_CHANNEL_ID,
            "Return to Amma (background)",
            NotificationManager.IMPORTANCE_MIN,
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }

    private fun buildForegroundNotification() =
        NotificationCompat.Builder(this, FOREGROUND_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Amma")
            .setContentText("Floating return button is active")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()

    companion object {
        private const val FOREGROUND_NOTIFICATION_ID = 1002
        private const val FOREGROUND_CHANNEL_ID = "overlay_service"

        fun start(context: Context) {
            val intent = Intent(context, OverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
