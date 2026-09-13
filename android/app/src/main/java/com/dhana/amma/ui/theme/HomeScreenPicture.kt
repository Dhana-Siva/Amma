package com.dhana.amma.ui.theme

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Face
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocalFlorist
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.WbSunny
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.dhana.amma.AmmaApplication

/** A small curated set of built-in "no upload needed" pictures for Talk's
 * welcome image, offered alongside letting the parent upload their own.
 * Exactly one of a preset or a custom photo is active at a time --
 * choosing one clears the other (see ProfileScreen). Mirrors iOS's
 * HomeScreenPreset. */
enum class HomeScreenPreset(val icon: ImageVector, val tint: Color) {
    Heart(Icons.Filled.Favorite, Color(0xFFE91E63)),
    Sun(Icons.Filled.WbSunny, Color(0xFFFF9800)),
    Family(Icons.Filled.Group, Color(0xFF1565C0)),
    Star(Icons.Filled.Star, Color(0xFFFBC02D)),
    House(Icons.Filled.Home, Color(0xFF43A047)),
    Flower(Icons.Filled.LocalFlorist, Color(0xFF00BFA5)),
    ;

    companion object {
        fun fromRaw(raw: String): HomeScreenPreset? = entries.find { it.name.lowercase() == raw.lowercase() }
    }
}

/** Renders the parent's chosen "home screen" picture: a custom uploaded
 * photo if one is set, otherwise a chosen preset, otherwise a plain
 * generic placeholder. Used both in Edit Profile's preview and on Talk's
 * welcome state, so both stay in sync automatically -- reads the same
 * AmmaPreferences keys the editor (ProfileScreen) writes to. Mirrors
 * iOS's HomeScreenPictureView. */
@Composable
fun HomeScreenPictureView(size: Dp = 132.dp) {
    val application = LocalContext.current.applicationContext as AmmaApplication
    val photoPath = application.preferences.homeScreenPhotoPath
    val preset = HomeScreenPreset.fromRaw(application.preferences.homeScreenPreset)

    val bitmap = remember(photoPath) {
        photoPath.takeIf { it.isNotBlank() }?.let { BitmapFactory.decodeFile(it) }
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
                    modifier = Modifier.fillMaxSize().background(preset.tint.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(preset.icon, contentDescription = null, tint = preset.tint, modifier = Modifier.size(size * 0.4f))
                }
            }
            else -> {
                Box(
                    modifier = Modifier.fillMaxSize().background(Color(0xFFE0E0E0)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Face, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(size * 0.4f))
                }
            }
        }
    }
}
