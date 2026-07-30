package com.dhana.amma.ui.talk

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.dhana.amma.AmmaApplication
import com.dhana.amma.models.InteractionChannel
import com.dhana.amma.models.InteractionLog
import com.dhana.amma.services.AmmaApiClient
import com.dhana.amma.services.AudioPlaybackService
import com.dhana.amma.services.AudioRecorderService
import com.dhana.amma.services.CastService
import com.dhana.amma.services.CommandExecutor
import com.dhana.amma.services.ContactsService
import com.dhana.amma.services.FamilyContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

enum class TalkPhase { Idle, Recording, Transcribing, Sending }

class TalkViewModel(
    private val appContext: Context,
    private val familyContext: FamilyContext,
    private val apiClient: AmmaApiClient,
    private val contactsService: ContactsService,
    private val castService: CastService,
    val recorder: AudioRecorderService,
    private val playback: AudioPlaybackService,
) : ViewModel() {

    private val _phase = MutableStateFlow(TalkPhase.Idle)
    val phase: StateFlow<TalkPhase> = _phase.asStateFlow()

    private val _log = MutableStateFlow<List<InteractionLog>>(emptyList())
    val log: StateFlow<List<InteractionLog>> = _log.asStateFlow()

    private val _statusMessage = MutableStateFlow<String?>(null)
    val statusMessage: StateFlow<String?> = _statusMessage.asStateFlow()

    fun onMicTap() {
        when (_phase.value) {
            TalkPhase.Idle -> {
                _statusMessage.value = null
                recorder.startRecording()
                _phase.value = TalkPhase.Recording
            }
            TalkPhase.Recording -> {
                recorder.stopRecording()
                val file = recorder.recordedFile
                if (file == null || !file.exists() || file.length() == 0L) {
                    _phase.value = TalkPhase.Idle
                    return
                }
                _phase.value = TalkPhase.Transcribing
                viewModelScope.launch {
                    try {
                        val transcript = apiClient.transcribeAudio(file)
                        _phase.value = TalkPhase.Sending
                        sendTranscript(transcript)
                    } catch (e: Exception) {
                        _statusMessage.value = "Couldn't hear that — check your connection and try again."
                        _phase.value = TalkPhase.Idle
                    }
                }
            }
            TalkPhase.Transcribing, TalkPhase.Sending -> {
                // Ignore taps while busy.
            }
        }
    }

    private suspend fun sendTranscript(transcript: String) {
        try {
            val reply = apiClient.sendInteraction(
                familyId = familyContext.familyId,
                transcript = transcript,
                channel = InteractionChannel.Voice.wireValue,
            )
            _log.value = _log.value + InteractionLog(
                id = UUID.randomUUID(),
                familyId = familyContext.familyId,
                timestamp = System.currentTimeMillis(),
                channel = InteractionChannel.Voice,
                transcript = transcript,
                responseText = reply.replyText,
                responseAudioUrl = reply.replyAudioUrl,
            )
            _statusMessage.value = null
            _phase.value = TalkPhase.Idle

            reply.replyAudioUrl?.let { audioUrl ->
                playback.play(audioUrl)
            }
            reply.action?.let { action ->
                val error = CommandExecutor.execute(action, appContext, contactsService, castService)
                if (error != null) {
                    _statusMessage.value = error
                }
            }
        } catch (e: Exception) {
            _statusMessage.value = "Couldn't reach Amma — check your connection."
            _phase.value = TalkPhase.Idle
        }
    }

    class Factory(private val application: AmmaApplication) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            @Suppress("UNCHECKED_CAST")
            return TalkViewModel(
                appContext = application.applicationContext,
                familyContext = application.familyContext,
                apiClient = application.apiClient,
                contactsService = application.contactsService,
                castService = application.castService,
                recorder = AudioRecorderService(application.applicationContext),
                playback = AudioPlaybackService(application.applicationContext),
            ) as T
        }
    }
}
