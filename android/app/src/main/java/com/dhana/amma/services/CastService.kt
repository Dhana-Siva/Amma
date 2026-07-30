package com.dhana.amma.services

import android.content.Context

/**
 * Phase-1 stub. Phase 2 replaces the body of these calls with a real
 * CastContext/SessionManager and a custom Cast.MessageReceivedCallback on
 * namespace "urn:x-cast:com.dhana.amma.cast", talking to the same receiver
 * already deployed at https://dhana-siva.github.io/amma-cast-receiver/ that
 * the iOS app uses. Call sites (CommandExecutor) don't need to change.
 */
class CastService {
    sealed class CastServiceError : Exception() {
        object NotConnected : CastServiceError()
        object SendFailed : CastServiceError()
    }

    fun configure(context: Context) {
        // No-op until Phase 2.
    }

    suspend fun play(videoId: String) {
        throw CastServiceError.NotConnected
    }

    suspend fun stop() {
        throw CastServiceError.NotConnected
    }
}
