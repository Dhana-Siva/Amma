package com.dhana.amma.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

object OverlayHelper {
    fun canDrawOverlays(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return Settings.canDrawOverlays(context)
    }

    /** Sends the user to the system settings screen to grant "display over
     * other apps" — this permission has no standard runtime popup, it can
     * only be granted through this dedicated settings screen. */
    fun requestPermission(context: Context) {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}"),
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    /** Shows the floating return-to-Amma bubble if permission is already
     * granted, otherwise falls back to the ongoing notification. */
    fun showReturnToAmma(context: Context, appLabel: String) {
        if (canDrawOverlays(context)) {
            OverlayService.start(context)
        } else {
            NotificationHelper.showReturnToAmma(context, appLabel)
        }
    }
}
