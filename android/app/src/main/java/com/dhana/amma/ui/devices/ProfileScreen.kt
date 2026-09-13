package com.dhana.amma.ui.devices

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import com.dhana.amma.ui.theme.AvatarPreset
import com.dhana.amma.ui.theme.AvatarView
import com.dhana.amma.ui.theme.HomeScreenPictureView
import com.dhana.amma.ui.theme.HomeScreenPreset
import com.dhana.amma.ui.voice.VoiceSetupViewModel
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/** Which picture slot a photo-library or camera pick currently in
 * progress is destined for -- mirrors iOS's PhotoTarget, centralizing
 * this here (rather than each field owning its own picker) so only one
 * picker of each kind is ever in flight at a time. */
private enum class PhotoTarget { Parent, Child, HomeScreen }

/** A photo -- from the library or camera -- waiting on the crop step
 * before it's saved to its target slot. Mirrors iOS's PendingCrop. */
private data class PendingCrop(val bitmap: Bitmap, val target: PhotoTarget)

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
    var parentRelation by remember { mutableStateOf(application.preferences.parentRelation) }
    var childName by remember { mutableStateOf(application.preferences.childName) }
    var childPhoneNumber by remember { mutableStateOf(application.preferences.childPhoneNumber) }
    var parentPhotoPath by remember { mutableStateOf(application.preferences.parentPhotoPath) }
    var childPhotoPath by remember { mutableStateOf(application.preferences.childPhotoPath) }
    var homeScreenPhotoPath by remember { mutableStateOf(application.preferences.homeScreenPhotoPath) }
    var homeScreenPreset by remember { mutableStateOf(application.preferences.homeScreenPreset) }
    var avatarUsesChildPhoto by remember { mutableStateOf(application.preferences.avatarUsesChildPhoto) }
    var avatarPreset by remember { mutableStateOf(application.preferences.avatarPreset) }
    var saveStatus by remember { mutableStateOf<String?>(null) }

    // The one shared photo-picking state for the whole screen -- see
    // PhotoTarget's doc comment for why this isn't per-field.
    var photoTarget by remember { mutableStateOf<PhotoTarget?>(null) }
    var pendingCrop by remember { mutableStateOf<PendingCrop?>(null) }

    fun beginPick(target: PhotoTarget) {
        photoTarget = target
    }

    fun applyCroppedPhoto(bitmap: Bitmap, target: PhotoTarget) {
        val prefix = if (target == PhotoTarget.HomeScreen) "home_screen" else "photo"
        val file = File(context.filesDir, "${prefix}_${UUID.randomUUID()}.jpg")
        FileOutputStream(file).use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out) }
        when (target) {
            PhotoTarget.Parent -> {
                parentPhotoPath.takeIf { it.isNotBlank() }?.let { File(it).delete() }
                parentPhotoPath = file.absolutePath
                application.preferences.parentPhotoPath = file.absolutePath
            }
            PhotoTarget.Child -> {
                childPhotoPath.takeIf { it.isNotBlank() }?.let { File(it).delete() }
                childPhotoPath = file.absolutePath
                application.preferences.childPhotoPath = file.absolutePath
            }
            PhotoTarget.HomeScreen -> {
                homeScreenPhotoPath.takeIf { it.isNotBlank() }?.let { File(it).delete() }
                homeScreenPhotoPath = file.absolutePath
                application.preferences.homeScreenPhotoPath = file.absolutePath
                // Exactly one of preset/photo is active -- a custom photo
                // clears whichever preset was chosen before.
                homeScreenPreset = ""
                application.preferences.homeScreenPreset = ""
            }
        }
    }

    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        val target = photoTarget
        photoTarget = null
        if (uri == null || target == null) return@rememberLauncherForActivityResult
        context.contentResolver.openInputStream(uri)?.use { input ->
            BitmapFactory.decodeStream(input)?.let { pendingCrop = PendingCrop(it, target) }
        }
    }

    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicturePreview()
    ) { bitmap: Bitmap? ->
        val target = photoTarget
        photoTarget = null
        if (bitmap != null && target != null) {
            pendingCrop = PendingCrop(bitmap, target)
        }
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> if (granted) cameraLauncher.launch(null) }

    fun choosePhoto(target: PhotoTarget) {
        beginPick(target)
        galleryLauncher.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
    }

    fun takePhoto(target: PhotoTarget) {
        beginPick(target)
        cameraPermissionLauncher.launch(android.Manifest.permission.CAMERA)
    }

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
            Row(
                horizontalArrangement = Arrangement.spacedBy(32.dp),
                modifier = Modifier.padding(bottom = 8.dp),
            ) {
                PhotoSlot(
                    title = "You",
                    placeholderIcon = Icons.Filled.Person,
                    photoPath = parentPhotoPath,
                    onChoosePhoto = { choosePhoto(PhotoTarget.Parent) },
                    onTakePhoto = { takePhoto(PhotoTarget.Parent) },
                )
                PhotoSlot(
                    title = "Child",
                    placeholderIcon = Icons.Filled.Person,
                    photoPath = childPhotoPath,
                    onChoosePhoto = { choosePhoto(PhotoTarget.Child) },
                    onTakePhoto = { takePhoto(PhotoTarget.Child) },
                )
            }

            Spacer(Modifier.height(16.dp))
            HorizontalDivider()
            Spacer(Modifier.height(16.dp))

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
            HorizontalDivider()
            Spacer(Modifier.height(16.dp))

            OutlinedTextField(
                value = parentRelation,
                onValueChange = { parentRelation = it },
                label = { Text("How your child addresses you (e.g. Amma, Mom)") },
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                "Used for the greeting on Talk — \"Good morning, ${parentRelation.trim().ifBlank { "Amma" }}!\" instead of your name.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp),
            )

            Spacer(Modifier.height(24.dp))
            HorizontalDivider()
            Spacer(Modifier.height(16.dp))

            Text("Avatar", style = MaterialTheme.typography.labelLarge, modifier = Modifier.fillMaxWidth())
            Text(
                "Shown next to Amma's replies in Talk — pick the real photo or a friendly default.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
            AvatarView(size = 72.dp)
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                AvatarChoiceTile(
                    selected = avatarUsesChildPhoto,
                    label = childName.ifBlank { "Child" },
                    onClick = {
                        avatarUsesChildPhoto = true
                        application.preferences.avatarUsesChildPhoto = true
                    },
                ) {
                    val bitmap = remember(childPhotoPath) {
                        childPhotoPath.takeIf { it.isNotBlank() }?.let { BitmapFactory.decodeFile(it) }
                    }
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize(),
                        )
                    } else {
                        Icon(Icons.Filled.Person, contentDescription = null)
                    }
                }
                AvatarPreset.entries.forEach { preset ->
                    AvatarChoiceTile(
                        selected = !avatarUsesChildPhoto && avatarPreset.equals(preset.name, ignoreCase = true),
                        label = preset.title,
                        tint = preset.tint,
                        onClick = {
                            avatarUsesChildPhoto = false
                            avatarPreset = preset.name
                            application.preferences.avatarUsesChildPhoto = false
                            application.preferences.avatarPreset = preset.name
                        },
                    ) {
                        Icon(preset.icon, contentDescription = null, tint = preset.tint)
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
            HorizontalDivider()
            Spacer(Modifier.height(16.dp))

            Text("Home screen", style = MaterialTheme.typography.labelLarge, modifier = Modifier.fillMaxWidth())
            Text(
                "Shown on the Talk screen when you open the app — pick one of the defaults or use your own photo.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(12.dp))
            HomeScreenPictureView(size = 100.dp)
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                HomeScreenPreset.entries.forEach { preset ->
                    AvatarChoiceTile(
                        selected = homeScreenPhotoPath.isBlank() && homeScreenPreset.equals(preset.name, ignoreCase = true),
                        label = null,
                        tint = preset.tint,
                        onClick = {
                            homeScreenPhotoPath.takeIf { it.isNotBlank() }?.let { File(it).delete() }
                            homeScreenPhotoPath = ""
                            homeScreenPreset = preset.name
                            application.preferences.homeScreenPhotoPath = ""
                            application.preferences.homeScreenPreset = preset.name
                        },
                    ) {
                        Icon(preset.icon, contentDescription = null, tint = preset.tint)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(onClick = { choosePhoto(PhotoTarget.HomeScreen) }) {
                    Text("Choose photo")
                }
                OutlinedButton(onClick = { takePhoto(PhotoTarget.HomeScreen) }) {
                    Text("Take photo")
                }
            }

            Spacer(Modifier.height(24.dp))
            HorizontalDivider()
            Spacer(Modifier.height(16.dp))

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
                        this.parentRelation = parentRelation.trim()
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

    pendingCrop?.let { crop ->
        PhotoCropScreen(
            image = crop.bitmap,
            onConfirm = { cropped ->
                applyCroppedPhoto(cropped, crop.target)
                pendingCrop = null
            },
            onCancel = { pendingCrop = null },
        )
    }
}

/** One photo slot's display + trigger buttons (avatar preview, "Choose
 * photo"/"Take photo"). Purely presentational -- actual picking is owned
 * by ProfileScreen (a single shared picker/camera launcher for the whole
 * screen; see PhotoTarget's doc comment for why). Mirrors iOS's
 * PhotoPickerField. */
@Composable
private fun PhotoSlot(
    title: String,
    placeholderIcon: androidx.compose.ui.graphics.vector.ImageVector,
    photoPath: String,
    onChoosePhoto: () -> Unit,
    onTakePhoto: () -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        val bitmap = remember(photoPath) {
            photoPath.takeIf { it.isNotBlank() }?.let { BitmapFactory.decodeFile(it) }
        }
        Box(
            modifier = Modifier.size(96.dp).clip(CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (bitmap != null) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Box(
                    modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.surfaceVariant),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(placeholderIcon, contentDescription = null, modifier = Modifier.size(36.dp))
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onChoosePhoto, modifier = Modifier.width(120.dp)) {
            Text("Choose photo", style = MaterialTheme.typography.labelSmall)
        }
        Spacer(Modifier.height(4.dp))
        OutlinedButton(onClick = onTakePhoto, modifier = Modifier.width(120.dp)) {
            Text("Take photo", style = MaterialTheme.typography.labelSmall)
        }
    }
}

/** One selectable tile in the Avatar/Home-screen preset rows: a circular
 * swatch (real photo thumbnail or preset icon) with a colored ring when
 * selected, and an optional caption below. */
@Composable
private fun AvatarChoiceTile(
    selected: Boolean,
    label: String?,
    tint: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.primary,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.18f))
                .then(
                    if (selected) {
                        Modifier.border(2.5.dp, tint, CircleShape)
                    } else {
                        Modifier
                    }
                )
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            content()
        }
        if (label != null) {
            Spacer(Modifier.height(4.dp))
            Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
