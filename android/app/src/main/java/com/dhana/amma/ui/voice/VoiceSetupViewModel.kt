package com.dhana.amma.ui.voice

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.dhana.amma.AmmaApplication
import com.dhana.amma.models.VoicePreset
import com.dhana.amma.services.AmmaApiClient
import com.dhana.amma.services.AudioRecorderService
import com.dhana.amma.services.FamilyContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

private data class PickedSample(val file: File, val filename: String, val contentType: String)

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

    private val _presets = MutableStateFlow<List<VoicePreset>>(emptyList())
    val presets: StateFlow<List<VoicePreset>> = _presets.asStateFlow()

    private val _selectedPresetId = MutableStateFlow<String?>(null)
    val selectedPresetId: StateFlow<String?> = _selectedPresetId.asStateFlow()

    // A recorded sample takes this over as soon as recording stops
    // (see toggleRecording); whichever was set most recently is what
    // uploadSample() actually sends.
    private var pickedSample: PickedSample? = null

    private val _hasSample = MutableStateFlow(false)
    val hasSample: StateFlow<Boolean> = _hasSample.asStateFlow()

    init {
        viewModelScope.launch {
            runCatching { _presets.value = apiClient.voicePresets() }
        }
    }

    fun onConsentChanged(granted: Boolean) {
        _consentGiven.value = granted
        viewModelScope.launch {
            runCatching { apiClient.setVoiceConsent(familyContext.familyId, granted) }
        }
    }

    fun toggleRecording() {
        if (recorder.isRecording.value) {
            recorder.stopRecording()
            pickedSample = null
            _hasSample.value = recorder.recordedFile != null
        } else {
            _status.value = "Not started"
            recorder.startRecording()
        }
    }

    fun onFilePicked(file: File, filename: String, contentType: String) {
        pickedSample = PickedSample(file, filename, contentType)
        _hasSample.value = true
        _status.value = "File selected — tap Upload sample."
    }

    fun uploadSample() {
        val picked = pickedSample
        val recorded = recorder.recordedFile
        viewModelScope.launch {
            _isUploading.value = true
            try {
                val voiceId = when {
                    picked != null && picked.file.exists() && picked.file.length() > 0L ->
                        apiClient.uploadVoiceSample(familyContext.familyId, picked.file, picked.filename, picked.contentType)
                    recorded != null && recorded.exists() && recorded.length() > 0L ->
                        apiClient.uploadVoiceSample(familyContext.familyId, recorded)
                    else -> {
                        _status.value = "No recording to upload yet."
                        return@launch
                    }
                }
                _selectedPresetId.value = null
                _status.value = "Uploaded — voice ready ($voiceId)"
            } catch (e: Exception) {
                _status.value = "Upload failed — try again."
            } finally {
                _isUploading.value = false
            }
        }
    }

    fun selectPreset(preset: VoicePreset) {
        viewModelScope.launch {
            try {
                apiClient.selectVoice(familyContext.familyId, preset.voiceId)
                _selectedPresetId.value = preset.voiceId
                _status.value = "Using ${preset.name}'s voice."
            } catch (e: Exception) {
                _status.value = "Couldn't set that voice — try again."
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
