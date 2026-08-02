package com.dhana.amma.services

import com.dhana.amma.models.ConsentRequestBody
import com.dhana.amma.models.FamilySetupRequestBody
import com.dhana.amma.models.InteractionReply
import com.dhana.amma.models.InteractionRequestBody
import com.dhana.amma.models.TranscribeResponse
import com.dhana.amma.models.VoicePreset
import com.dhana.amma.models.VoicePresetsResponse
import com.dhana.amma.models.VoiceSampleResponse
import com.dhana.amma.models.VoiceSelectRequestBody
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.ResponseBody
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import java.io.File
import java.util.UUID

class ApiException(val statusCode: Int, val body: String) :
    Exception("HTTP $statusCode: $body")

private interface AmmaApiService {
    @POST("v1/interactions")
    suspend fun sendInteraction(@Body body: InteractionRequestBody): Response<InteractionReply>

    @POST("v1/family-setup")
    suspend fun setupFamily(@Body body: FamilySetupRequestBody): Response<ResponseBody>

    @POST("v1/consent")
    suspend fun setVoiceConsent(@Body body: ConsentRequestBody): Response<ResponseBody>

    @Multipart
    @POST("v1/voice-samples")
    suspend fun uploadVoiceSample(
        @Part familyId: MultipartBody.Part,
        @Part audio: MultipartBody.Part,
    ): Response<VoiceSampleResponse>

    @Multipart
    @POST("v1/transcribe")
    suspend fun transcribeAudio(@Part audio: MultipartBody.Part): Response<TranscribeResponse>

    @GET("v1/voice-presets")
    suspend fun voicePresets(): Response<VoicePresetsResponse>

    @POST("v1/voice-select")
    suspend fun selectVoice(@Body body: VoiceSelectRequestBody): Response<ResponseBody>
}

class AmmaApiClient(baseUrl: String = "https://amma-production.up.railway.app/") {
    private val json = Json { ignoreUnknownKeys = true }

    private val service: AmmaApiService = Retrofit.Builder()
        .baseUrl(baseUrl)
        .addConverterFactory(
            json.asConverterFactory("application/json".toMediaType())
        )
        .build()
        .create(AmmaApiService::class.java)

    suspend fun sendInteraction(
        familyId: UUID,
        transcript: String,
        channel: String,
    ): InteractionReply {
        val response = service.sendInteraction(
            InteractionRequestBody(familyId = familyId.toString(), transcript = transcript, channel = channel)
        )
        return response.bodyOrThrow()
    }

    suspend fun setupFamily(
        familyId: UUID,
        parentName: String,
        childName: String,
        language: String,
        childPhoneNumber: String? = null,
    ) {
        val response = service.setupFamily(
            FamilySetupRequestBody(
                familyId = familyId.toString(),
                parentName = parentName,
                childName = childName,
                language = language,
                childPhoneNumber = childPhoneNumber,
            )
        )
        response.throwIfNotSuccessful()
    }

    suspend fun setVoiceConsent(familyId: UUID, granted: Boolean) {
        val response = service.setVoiceConsent(
            ConsentRequestBody(familyId = familyId.toString(), granted = granted)
        )
        response.throwIfNotSuccessful()
    }

    suspend fun uploadVoiceSample(
        familyId: UUID,
        audioFile: File,
        filename: String = "sample.m4a",
        contentType: String = "audio/m4a",
    ): String {
        val familyIdPart = MultipartBody.Part.createFormData("family_id", familyId.toString())
        val audioPart = MultipartBody.Part.createFormData(
            "audio",
            filename,
            audioFile.asRequestBody(contentType.toMediaType()),
        )
        val response = service.uploadVoiceSample(familyIdPart, audioPart)
        return response.bodyOrThrow().voiceId
    }

    suspend fun voicePresets(): List<VoicePreset> {
        val response = service.voicePresets()
        return response.bodyOrThrow().presets
    }

    suspend fun selectVoice(familyId: UUID, voiceId: String) {
        val response = service.selectVoice(
            VoiceSelectRequestBody(familyId = familyId.toString(), voiceId = voiceId)
        )
        response.throwIfNotSuccessful()
    }

    suspend fun transcribeAudio(audioFile: File): String {
        val audioPart = MultipartBody.Part.createFormData(
            "audio",
            "recording.m4a",
            audioFile.asRequestBody("audio/m4a".toMediaType()),
        )
        val response = service.transcribeAudio(audioPart)
        return response.bodyOrThrow().transcript
    }

    private fun <T> Response<T>.bodyOrThrow(): T {
        if (!isSuccessful) {
            throw ApiException(code(), errorBody()?.string() ?: "")
        }
        return body() ?: throw ApiException(code(), "empty body")
    }

    private fun <T> Response<T>.throwIfNotSuccessful() {
        if (!isSuccessful) {
            throw ApiException(code(), errorBody()?.string() ?: "")
        }
    }
}
