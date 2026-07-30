package com.dhana.amma.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class InteractionRequestBody(
    @SerialName("family_id") val familyId: String,
    val transcript: String,
    val channel: String,
)

@Serializable
data class InteractionReply(
    @SerialName("reply_text") val replyText: String,
    @SerialName("reply_audio_url") val replyAudioUrl: String? = null,
    val action: Command? = null,
)

@Serializable
data class FamilySetupRequestBody(
    @SerialName("family_id") val familyId: String,
    @SerialName("parent_name") val parentName: String? = null,
    @SerialName("child_name") val childName: String? = null,
    val language: String,
    @SerialName("child_phone_number") val childPhoneNumber: String? = null,
)

@Serializable
data class ConsentRequestBody(
    @SerialName("family_id") val familyId: String,
    val granted: Boolean,
)

@Serializable
data class VoiceSampleResponse(
    @SerialName("voice_id") val voiceId: String,
)

@Serializable
data class TranscribeResponse(
    val transcript: String,
)
