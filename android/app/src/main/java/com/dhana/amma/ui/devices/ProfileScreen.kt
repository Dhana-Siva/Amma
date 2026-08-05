package com.dhana.amma.ui.devices

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dhana.amma.AmmaApplication
import com.dhana.amma.ui.voice.VoiceSetupViewModel
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication
    val scope = rememberCoroutineScope()

    // Reuses VoiceSetupViewModel purely for its consent state/logic, so
    // there's a single source of truth shared with the Voice tab rather
    // than a second parallel implementation.
    val voiceViewModel: VoiceSetupViewModel = viewModel(factory = VoiceSetupViewModel.Factory(application))
    val consentGiven by voiceViewModel.consentGiven.collectAsState()

    var parentName by remember { mutableStateOf(application.preferences.parentName) }
    var childName by remember { mutableStateOf(application.preferences.childName) }
    var childPhoneNumber by remember { mutableStateOf(application.preferences.childPhoneNumber) }
    var photoPath by remember { mutableStateOf(application.preferences.childPhotoPath) }
    var saveStatus by remember { mutableStateOf<String?>(null) }

    fun savePhotoBitmap(bitmap: Bitmap) {
        val file = File(context.filesDir, "child_photo_${UUID.randomUUID()}.jpg")
        FileOutputStream(file).use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out) }
        // Clean up the previous photo file, if any, now that it's replaced.
        photoPath.takeIf { it.isNotBlank() }?.let { File(it).delete() }
        photoPath = file.absolutePath
        application.preferences.childPhotoPath = file.absolutePath
    }

    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        context.contentResolver.openInputStream(uri)?.use { input ->
            val bitmap = BitmapFactory.decodeStream(input)
            if (bitmap != null) savePhotoBitmap(bitmap)
        }
    }

    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicturePreview()
    ) { bitmap: Bitmap? ->
        if (bitmap != null) savePhotoBitmap(bitmap)
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) cameraLauncher.launch(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Profile") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(padding)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(120.dp)
                    .clip(CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                val bitmap = remember(photoPath) {
                    photoPath.takeIf { it.isNotBlank() }?.let { BitmapFactory.decodeFile(it) }
                }
                if (bitmap != null) {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "Child's photo",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize(),
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Filled.Person,
                            contentDescription = null,
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(onClick = {
                    galleryLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }) {
                    Text("Choose photo")
                }
                OutlinedButton(onClick = { cameraPermissionLauncher.launch(android.Manifest.permission.CAMERA) }) {
                    Text("Take photo")
                }
            }

            Spacer(Modifier.height(24.dp))

            OutlinedTextField(
                value = parentName,
                onValueChange = { parentName = it },
                label = { Text("Your name") },
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = childName,
                onValueChange = { childName = it },
                label = { Text("Child's name") },
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = childPhoneNumber,
                onValueChange = { childPhoneNumber = it },
                label = { Text("Child's phone number") },
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(24.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "I consent to my voice being used",
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.weight(1f),
                )
                Switch(checked = consentGiven, onCheckedChange = { voiceViewModel.onConsentChanged(it) })
            }

            Spacer(Modifier.height(24.dp))

            Button(
                onClick = {
                    application.preferences.apply {
                        this.parentName = parentName
                        this.childName = childName
                        this.childPhoneNumber = childPhoneNumber.trim()
                    }
                    scope.launch {
                        saveStatus = try {
                            application.apiClient.setupFamily(
                                familyId = application.familyContext.familyId,
                                parentName = parentName,
                                childName = childName,
                                language = application.preferences.languageCode,
                                childPhoneNumber = childPhoneNumber.trim().ifBlank { null },
                            )
                            "Saved."
                        } catch (e: Exception) {
                            "Couldn't save — check your connection and try again."
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Save")
            }

            saveStatus?.let {
                Spacer(Modifier.height(8.dp))
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
