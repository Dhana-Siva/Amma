package com.dhana.amma.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.dhana.amma.models.Command
import com.dhana.amma.models.CommandIntent
import java.net.URLEncoder

/**
 * Executes an action the backend returned from /v1/interactions. Returns
 * null on success, or a user-facing error string on failure — mirroring
 * iOS's CommandExecutor.execute(_:).
 */
object CommandExecutor {

    suspend fun execute(command: Command, context: Context, contactsService: ContactsService, castService: CastService): String? {
        return when (command.intent) {
            CommandIntent.PlaceCall -> placeCall(command, context, contactsService)
            CommandIntent.SendMessage -> sendMessage(command, context, contactsService)
            CommandIntent.CastMedia -> castMedia(command, castService)
            CommandIntent.StopCast -> stopCast(castService)
        }
    }

    private suspend fun resolvePhoneNumber(command: Command, contactsService: ContactsService): String? {
        val contactName = command.params["contactName"]
        if (!contactName.isNullOrBlank()) {
            return contactsService.phoneNumber(contactName)
        }
        return command.params["phoneNumber"]?.takeIf { it.isNotBlank() }
    }

    private fun sanitize(number: String): String =
        number.filterIndexed { index, c -> c.isDigit() || (c == '+' && index == 0) }

    private suspend fun placeCall(command: Command, context: Context, contactsService: ContactsService): String? {
        val number = resolvePhoneNumber(command, contactsService)
            ?: return "Couldn't find that contact to call."
        val sanitized = sanitize(number)
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$sanitized")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            null
        } catch (e: Exception) {
            "Couldn't open the dialer."
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
