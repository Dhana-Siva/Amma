package com.dhana.amma.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.dhana.amma.models.Command
import com.dhana.amma.models.CommandIntent
import java.net.URLEncoder

private const val TAG = "AmmaCommandExecutor"

/**
 * Executes an action the backend returned from /v1/interactions. Returns
 * null on success, or a user-facing error string on failure — mirroring
 * iOS's CommandExecutor.execute(_:).
 */
object CommandExecutor {

    suspend fun execute(
        command: Command,
        context: Context,
        contactsService: ContactsService,
        castService: CastService,
        preferences: AmmaPreferences,
    ): String? {
        return when (command.intent) {
            CommandIntent.PlaceCall -> placeCall(command, context, contactsService, preferences.callingApp)
            CommandIntent.SendMessage -> sendMessage(command, context, contactsService)
            CommandIntent.CastMedia -> castMedia(command, castService)
            CommandIntent.StopCast -> stopCast(castService)
        }
    }

    private suspend fun resolvePhoneNumber(command: Command, contactsService: ContactsService): String? {
        Log.d(TAG, "resolvePhoneNumber: params=${command.params}")
        val contactName = command.params["contactName"]
        if (!contactName.isNullOrBlank()) {
            val resolved = contactsService.phoneNumber(contactName)
            Log.d(TAG, "resolvePhoneNumber: contactName='$contactName' -> $resolved")
            return resolved
        }
        val fallback = command.params["phoneNumber"]?.takeIf { it.isNotBlank() }
        Log.d(TAG, "resolvePhoneNumber: no contactName, fallback phoneNumber=$fallback")
        return fallback
    }

    private fun sanitize(number: String): String =
        number.filterIndexed { index, c -> c.isDigit() || (c == '+' && index == 0) }

    private suspend fun placeCall(
        command: Command,
        context: Context,
        contactsService: ContactsService,
        callingApp: String,
    ): String? {
        val number = resolvePhoneNumber(command, contactsService)
            ?: return "Couldn't find that contact to call."
        val withoutPlus = sanitize(number).removePrefix("+")

        // None of these apps expose a call-initiation intent to third-party
        // apps on Android — each opens the contact's chat/profile page,
        // one tap away from starting a free call, which matters for
        // international calling (e.g. calling family in India) where a
        // regular carrier call would cost money. Telegram's phone-number
        // lookup only resolves if the contact has Telegram installed with
        // that exact number and allows being found by phone number in
        // their privacy settings.
        val (uri, appLabel) = when (callingApp) {
            CallingApp.VIBER -> Uri.parse("viber://chat?number=%2B$withoutPlus") to "Viber"
            CallingApp.TELEGRAM -> Uri.parse("https://t.me/+$withoutPlus") to "Telegram"
            else -> Uri.parse("https://wa.me/$withoutPlus") to "WhatsApp"
        }
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            null
        } catch (e: Exception) {
            "Couldn't open $appLabel."
        }
    }

    private suspend fun sendMessage(command: Command, context: Context, contactsService: ContactsService): String? {
        val number = resolvePhoneNumber(command, contactsService)
            ?: return "Couldn't find that contact to message."
        val sanitized = sanitize(number).removePrefix("+")
        val text = command.params["text"] ?: ""
        val encodedText = URLEncoder.encode(text, "UTF-8")
        val uri = Uri.parse("https://wa.me/$sanitized?text=$encodedText")
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            null
        } catch (e: Exception) {
            "Couldn't open WhatsApp."
        }
    }

    private suspend fun castMedia(command: Command, castService: CastService): String? {
        val videoId = command.params["videoId"]
        if (videoId.isNullOrBlank()) return "Couldn't find that to play."
        return try {
            castService.play(videoId)
            null
        } catch (e: CastService.CastServiceError.NotConnected) {
            "No TV linked yet — go to Devices to link one."
        } catch (e: Exception) {
            "Couldn't cast that — try again."
        }
    }

    private suspend fun stopCast(castService: CastService): String? {
        return try {
            castService.stop()
            null
        } catch (e: CastService.CastServiceError.NotConnected) {
            "No TV linked yet — go to Devices to link one."
        } catch (e: Exception) {
            "Couldn't stop casting — try again."
        }
    }
}
