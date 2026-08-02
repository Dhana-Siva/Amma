package com.dhana.amma.services

import android.content.Context
import android.util.Log
import com.google.android.gms.cast.Cast
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONObject
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Talks to Amma's own custom Cast receiver (Application ID 592BF965,
 * hosted at https://dhana-siva.github.io/amma-cast-receiver/) over a
 * custom message channel — not the standard media-queue Cast API — same
 * protocol the iOS app uses: {"videoId": "..."} to play, {"action":
 * "stop"} to stop.
 *
 * Device discovery/connection is handled by the platform's standard Cast
 * UI (a MediaRouteButton in the Devices screen opens Google's own device
 * picker dialog) rather than a custom device list, since Android already
 * provides this as a well-known, familiar system experience.
 */
class CastService {
    sealed class CastServiceError : Exception() {
        object NotConnected : CastServiceError()
        object SendFailed : CastServiceError()
    }

    private companion object {
        const val TAG = "AmmaCastService"
        const val NAMESPACE = "urn:x-cast:com.dhana.amma.cast"
    }

    private var castContext: CastContext? = null

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _connectedDeviceName = MutableStateFlow<String?>(null)
    val connectedDeviceName: StateFlow<String?> = _connectedDeviceName.asStateFlow()

    private val messageCallback = Cast.MessageReceivedCallback { _, namespace, message ->
        Log.d(TAG, "message received on $namespace: $message")
    }

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(session: CastSession, sessionId: String) = onSessionActive(session)
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) = onSessionActive(session)
        override fun onSessionEnded(session: CastSession, error: Int) = onSessionInactive()
        override fun onSessionSuspended(session: CastSession, reason: Int) = onSessionInactive()
        override fun onSessionStarting(session: CastSession) {}
        override fun onSessionStartFailed(session: CastSession, error: Int) {}
        override fun onSessionEnding(session: CastSession) {}
        override fun onSessionResuming(session: CastSession, sessionId: String) {}
        override fun onSessionResumeFailed(session: CastSession, error: Int) {}
    }

    private fun onSessionActive(session: CastSession) {
        try {
            session.setMessageReceivedCallbacks(NAMESPACE, messageCallback)
        } catch (e: Exception) {
            Log.w(TAG, "failed to register message channel", e)
        }
        _connectedDeviceName.value = session.castDevice?.friendlyName
        _isConnected.value = true
    }

    private fun onSessionInactive() {
        _isConnected.value = false
        _connectedDeviceName.value = null
    }

    fun configure(context: Context) {
        try {
            val ctx = CastContext.getSharedInstance(context.applicationContext)
            castContext = ctx
            ctx.sessionManager.addSessionManagerListener(sessionListener, CastSession::class.java)
            ctx.sessionManager.currentCastSession?.let { onSessionActive(it) }
        } catch (e: Exception) {
            // Cast unavailable on this device (no Play Services, etc.) —
            // play()/stop() will just report NotConnected, same graceful
            // degradation as everywhere else CastService is used.
            Log.w(TAG, "Cast unavailable", e)
        }
    }

    fun disconnect() {
        castContext?.sessionManager?.endCurrentSession(true)
    }

    suspend fun play(videoId: String) {
        sendMessage(JSONObject().put("videoId", videoId).toString())
    }

    suspend fun stop() {
        sendMessage(JSONObject().put("action", "stop").toString())
    }

    private suspend fun sendMessage(message: String) {
        val session = castContext?.sessionManager?.currentCastSession
            ?.takeIf { it.isConnected }
            ?: throw CastServiceError.NotConnected

        suspendCancellableCoroutine { continuation ->
            session.sendMessage(NAMESPACE, message).setResultCallback { status ->
                if (!continuation.isActive) return@setResultCallback
                if (status.isSuccess) {
                    continuation.resume(Unit)
                } else {
                    Log.w(TAG, "sendMessage failed: ${status.statusMessage}")
                    continuation.resumeWithException(CastServiceError.SendFailed)
                }
            }
        }
    }
}
