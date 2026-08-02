package com.dhana.amma.ui.voice

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.dhana.amma.AmmaApplication
import com.dhana.amma.services.AmmaApiClient
import com.dhana.amma.services.AudioRecorderService
import com.dhana.amma.services.FamilyContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class VoiceSetupViewModel(
    private val familyContext: FamilyContext,
    private val apiClient: AmmaApiClient,
    val recorder: AudioRecorderService,
) : ViewModel() {

    private val _consentGiven = MutableStateFlow(false)
    val consentGiven: StateFlow<Boolean> = _consentGiven.asStateFlow()

    private val _status = MutableStateFlow("Not started")
    val status: StateFlow<String> = _status.asStateFlow()

    private val _isUploading = MutableStateFlow(false)
    val isUploading: StateFlow<Boolean> = _isUploading.asStateFlow()

    fun onConsentChanged(granted: Boolean) {
        _consentGiven.value = granted
        viewModelScope.launch {
            runCatching { apiClient.setVoiceConsent(familyContext.familyId, granted) }
        }
    }

    fun toggleRecording() {
        if (recorder.isRecording.value) {
            recorder.stopRecording()
        } else {
            _status.value = "Not started"
            recorder.startRecording()
        }
    }

    fun uploadSample() {
        val file = recorder.recordedFile
        if (file == null || !file.exists() || file.length() == 0L) {
            _status.value = "No recording to upload yet."
            return
        }
        _isUploading.value = true
        viewModelScope.launch {
            try {
                val voiceId = apiClient.uploadVoiceSample(familyContext.familyId, file)
                _status.value = "Uploaded — voice ready ($voiceId)"
            } catch (e: Exception) {
                _status.value = "Upload failed — try again."
            } finally {
                _isUploading.value = false
            }
        }
    }

    class Factory(private val application: AmmaApplication) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            @Suppress("UNCHECKED_CAST")
            return VoiceSetupViewModel(
                familyContext = application.familyContext,
                apiClient = application.apiClient,
                recorder = AudioRecorderService(application.applicationContext),
            ) as T
        }
    }
}
