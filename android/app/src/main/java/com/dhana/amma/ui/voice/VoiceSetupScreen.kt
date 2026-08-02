package com.dhana.amma.ui.voice

import android.Manifest
import android.content.pm.PackageManager
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
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dhana.amma.AmmaApplication

@Composable
fun VoiceSetupScreen() {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication
    val viewModel: VoiceSetupViewModel = viewModel(factory = VoiceSetupViewModel.Factory(application))

    val consentGiven by viewModel.consentGiven.collectAsState()
    val status by viewModel.status.collectAsState()
    val isUploading by viewModel.isUploading.collectAsState()
    val isRecording by viewModel.recorder.isRecording.collectAsState()
    val elapsedSeconds by viewModel.recorder.elapsedSeconds.collectAsState()

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) viewModel.toggleRecording() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            "Amma needs about 30 seconds of your child's voice to reply in their own voice. " +
                "This is optional, and consent can be withdrawn at any time.",
            style = MaterialTheme.typography.bodyLarge,
        )

        Spacer(Modifier.height(24.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("I consent to my voice being used", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
            Switch(checked = consentGiven, onCheckedChange = { viewModel.onConsentChanged(it) })
        }

        Spacer(Modifier.height(24.dp))

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

        if (!isRecording && viewModel.recorder.recordedFile != null) {
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
