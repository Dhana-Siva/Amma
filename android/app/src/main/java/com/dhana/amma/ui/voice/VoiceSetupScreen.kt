package com.dhana.amma.ui.voice

import android.Manifest
import android.content.pm.PackageManager
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dhana.amma.AmmaApplication
import com.dhana.amma.models.VoicePreset
import kotlinx.coroutines.launch
import java.io.File
import java.util.UUID

@Composable
fun VoiceSetupScreen() {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication
    val viewModel: VoiceSetupViewModel = viewModel(factory = VoiceSetupViewModel.Factory(application))
    val scope = rememberCoroutineScope()

    val consentGiven by viewModel.consentGiven.collectAsState()
    val status by viewModel.status.collectAsState()
    val isUploading by viewModel.isUploading.collectAsState()
    val isRecording by viewModel.recorder.isRecording.collectAsState()
    val elapsedSeconds by viewModel.recorder.elapsedSeconds.collectAsState()
    val presets by viewModel.presets.collectAsState()
    val selectedPresetId by viewModel.selectedPresetId.collectAsState()
    val hasSample by viewModel.hasSample.collectAsState()

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) viewModel.toggleRecording() }

    val filePickerLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val contentType = context.contentResolver.getType(uri) ?: "audio/mpeg"
            var displayName = "sample"
            context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0 && cursor.moveToFirst()) {
                    displayName = cursor.getString(nameIndex) ?: displayName
                }
            }
            val destination = File(context.cacheDir, "${UUID.randomUUID()}-$displayName")
            context.contentResolver.openInputStream(uri)?.use { input ->
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            viewModel.onFilePicked(destination, displayName, contentType)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
    ) {
        Text(
            "Choose how Amma should sound when it replies — a default voice, " +
                "or your child's own voice.",
            style = MaterialTheme.typography.bodyLarge,
        )

        Spacer(Modifier.height(20.dp))
        Text("Default voice", style = MaterialTheme.typography.labelLarge)
        Spacer(Modifier.height(8.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            items(presets) { preset ->
                VoicePresetCard(
                    preset = preset,
                    selected = preset.voiceId == selectedPresetId,
                    onSelect = { viewModel.selectPreset(preset) },
                )
            }
        }

        Spacer(Modifier.height(24.dp))
        HorizontalDivider()
        Spacer(Modifier.height(24.dp))

        Text("Your child's real voice", style = MaterialTheme.typography.labelLarge)
        Spacer(Modifier.height(8.dp))
        Text(
            "Needs about 30 seconds of their voice. This is optional, and consent " +
                "can be withdrawn at any time.",
            style = MaterialTheme.typography.bodyMedium,
        )

        Spacer(Modifier.height(16.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("I consent to my voice being used", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
            Switch(checked = consentGiven, onCheckedChange = { viewModel.onConsentChanged(it) })
        }

        Spacer(Modifier.height(16.dp))

        Button(
            enabled = consentGiven,
            onClick = {
                val hasPermission = ContextCompat.checkSelfPermission(
                    context, Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED
                if (hasPermission) {
                    viewModel.toggleRecording()
                } else {
                    permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                }
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (isRecording) "Stop recording (${elapsedSeconds}s)" else "Record voice sample")
        }

        Spacer(Modifier.height(8.dp))

        OutlinedButton(
            enabled = consentGiven && !isRecording,
            onClick = { filePickerLauncher.launch("audio/*") },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Choose audio file instead")
        }

        if (!isRecording && hasSample) {
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = { viewModel.uploadSample() },
                enabled = !isUploading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (isUploading) "Uploading..." else "Upload sample")
            }
        }

        Spacer(Modifier.height(16.dp))
        Text(status, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun VoicePresetCard(preset: VoicePreset, selected: Boolean, onSelect: () -> Unit) {
    Card(
        onClick = onSelect,
        shape = RoundedCornerShape(12.dp),
        colors = if (selected) {
            CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
        } else {
            CardDefaults.cardColors()
        },
        modifier = Modifier.width(140.dp),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(preset.name, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(4.dp))
            Text(preset.description, style = MaterialTheme.typography.bodySmall)
        }
    }
}
