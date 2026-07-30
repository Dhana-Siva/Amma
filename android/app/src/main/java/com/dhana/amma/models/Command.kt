package com.dhana.amma.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class CommandIntent {
    @SerialName("castMedia") CastMedia,
    @SerialName("stopCast") StopCast,
    @SerialName("placeCall") PlaceCall,
    @SerialName("sendMessage") SendMessage,
}

@Serializable
enum class CommandStatus {
    @SerialName("pending") Pending,
    @SerialName("executed") Executed,
    @SerialName("failed") Failed,
}

@Serializable
data class Command(
    val id: String,
    val familyId: String,
    val intent: CommandIntent,
    val params: Map<String, String> = emptyMap(),
    val status: CommandStatus,
    val executedAt: String? = null,
)
