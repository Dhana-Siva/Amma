package com.dhana.amma.ui.theme

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.BackHand
import androidx.compose.material.icons.filled.EmojiEmotions
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.dhana.amma.AmmaApplication

/** Curated "character" avatars offered as an alternative to a real photo
 * for the small identity shown next to Amma's name/replies in Talk -- for
 * a parent who hasn't uploaded (or doesn't want to upload) an actual
 * photo of their child, or just wants a friendlier look. Deliberately
 * distinct iconography from HomeScreenPreset (heart/sun/family/star/
 * house/flower) so the two picture systems never look interchangeable.
 * Mirrors iOS's AvatarPreset.swift. */
enum class AvatarPreset(val title: String, val icon: ImageVector, val tint: Color) {
    Smile("Smiley", Icons.Filled.EmojiEmotions, Color(0xFFFF9800)),
    Sparkle("Sparkle", Icons.Filled.AutoAwesome, Color(0xFF9C27B0)),
    Wave("Wave", Icons.Filled.BackHand, Color(0xFF009688)),
    Music("Music", Icons.Filled.MusicNote, Color(0xFFE91E63)),
    ;

    companion object {
        fun fromRaw(raw: String): AvatarPreset? = entries.find { it.name.lowercase() == raw.lowercase() }
    }
}

/** Renders whichever avatar the parent has chosen: the child's own
 * uploaded photo (the default) if one is set and selected, otherwise a
 * chosen character preset, otherwise a plain placeholder. Shared between
 * the Edit Profile picker preview and the Talk screen header so both
 * always agree -- reads the same AmmaPreferences keys the editor writes
 * to. Mirrors iOS's AvatarView. */
@Composable
fun AvatarView(size: androidx.compose.ui.unit.Dp = 32.dp) {
    val application = LocalContext.current.applicationContext as AmmaApplication
    val childPhotoPath = application.preferences.childPhotoPath
    val usesChildPhoto = application.preferences.avatarUsesChildPhoto
    val preset = AvatarPreset.fromRaw(application.preferences.avatarPreset)

    val bitmap = remember(childPhotoPath, usesChildPhoto) {
        if (usesChildPhoto && childPhotoPath.isNotBlank()) BitmapFactory.decodeFile(childPhotoPath) else null
    }

    Box(
        modifier = Modifier.size(size).clip(CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        when {
            bitmap != null -> Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
            preset != null -> {
                Box(
                    modifier = Modifier.fillMaxSize().background(preset.tint.copy(alpha = 0.18f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(preset.icon, contentDescription = null, tint = preset.tint, modifier = Modifier.size(size * 0.5f))
                }
            }
            else -> {
                Box(
                    modifier = Modifier.fillMaxSize().background(Color(0xFFE0E0E0)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Person, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(size * 0.5f))
                }
            }
        }
    }
}
