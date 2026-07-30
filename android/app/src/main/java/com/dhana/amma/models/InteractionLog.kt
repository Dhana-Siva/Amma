package com.dhana.amma.models

import java.util.UUID

enum class InteractionChannel {
    Tap,
    Voice,
    Scheduled;

    val wireValue: String
        get() = name.lowercase()
}

data class InteractionLog(
    val id: UUID,
    val familyId: UUID,
    val timestamp: Long,
    val channel: InteractionChannel,
    val transcript: String,
    val intent: String? = null,
    val responseText: String? = null,
    val responseAudioUrl: String? = null,
)
