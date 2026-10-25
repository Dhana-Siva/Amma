package com.dhana.amma.ui.talk

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.outlined.DeleteSweep
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.IntOffset
import androidx.compose.foundation.layout.offset
import kotlinx.coroutines.delay
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import com.dhana.amma.ui.theme.AmmaPink
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dhana.amma.AmmaApplication
import com.dhana.amma.models.InteractionLog
import com.dhana.amma.R
import com.dhana.amma.ui.theme.AvatarView
import com.dhana.amma.ui.theme.HomeScreenPictureView
import java.util.Calendar

@Composable
fun TalkScreen() {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication
    val viewModel: TalkViewModel = viewModel(factory = TalkViewModel.Factory(application))

    val phase by viewModel.phase.collectAsState()
    val log by viewModel.log.collectAsState()
    val statusMessage by viewModel.statusMessage.collectAsState()

    // Bundled into one prompt on first mic tap rather than asked separately
    // per-feature — only RECORD_AUDIO's result gates whether we actually
    // proceed with recording. (Contacts need no permission any more: see
    // ContactsService's picker-based Amma's Contacts list.)
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        if (results[Manifest.permission.RECORD_AUDIO] == true) viewModel.onMicTap()
    }

    val childName = application.preferences.childName
    val parentName = application.preferences.parentName
    val parentRelation = application.preferences.parentRelation
    val childPhotoPath = application.preferences.childPhotoPath
    val avatarUsesChildPhoto = application.preferences.avatarUsesChildPhoto
    val avatarPreset = application.preferences.avatarPreset
    val homeScreenPhotoPath = application.preferences.homeScreenPhotoPath
    val homeScreenPreset = application.preferences.homeScreenPreset
    val borderEnabled = application.preferences.workspaceBorderEnabled
    val borderColor = Color(application.preferences.workspaceBorderColor)
    val messageStyleColorful = application.preferences.messageStyleColorful

    // A brief emoji "reaction" pops onto the newest reply, then fades
    // (iOS f82e0f6) -- purely decorative. lastSeenSize starts at the
    // current count so coming back to this tab doesn't replay it.
    var reaction by remember { mutableStateOf<String?>(null) }
    var lastSeenSize by remember { mutableStateOf(log.size) }
    LaunchedEffect(log.size) {
        val grew = log.size > lastSeenSize
        lastSeenSize = log.size
        if (grew && log.lastOrNull()?.responseText != null) {
            reaction = REACTION_EMOJI.random()
            delay(1400)
            reaction = null
        }
    }

    Scaffold { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // No name label up here any more (iOS c6f75a6): the avatar sits
            // next to each of Amma's replies instead. Only a clear button
            // remains, once there's a conversation to clear.
            Row(
                modifier = Modifier.fillMaxWidth().height(48.dp).padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (log.isNotEmpty()) {
                    IconButton(onClick = { viewModel.clearConversation() }) {
                        Icon(Icons.Outlined.DeleteSweep, contentDescription = "Clear conversation")
                    }
                }
            }

            val accent = timeOfDayAccent()
            val workspaceShape = RoundedCornerShape(24.dp)
            Column(
                modifier = Modifier.weight(1f).fillMaxWidth().then(
                    if (borderEnabled) {
                        Modifier.padding(horizontal = 12.dp)
                            .border(3.dp, borderColor, workspaceShape)
                            .clip(workspaceShape)
                    } else {
                        Modifier
                    }
                ),
            ) {
            if (log.isEmpty()) {
                WelcomeState(
                    accent = accent,
                    homeScreenPhotoPath = homeScreenPhotoPath,
                    homeScreenPreset = homeScreenPreset,
                    greetingText = greeting(parentName, parentRelation),
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                )
            } else {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    HomeScreenPictureView(
                        photoPath = homeScreenPhotoPath,
                        homeScreenPresetRaw = homeScreenPreset,
                        size = 64.dp,
                    )
                }
                val listState = rememberLazyListState()
                LaunchedEffect(log.size) {
                    if (log.isNotEmpty()) listState.animateScrollToItem(log.lastIndex)
                }
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxWidth().weight(1f),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(log, key = { it.id }) { turn ->
                        TurnBubbles(
                            turn = turn,
                            accent = accent,
                            colorful = messageStyleColorful,
                            reaction = reaction.takeIf { turn.id == log.last().id },
                            avatar = {
                                AvatarView(
                                    childPhotoPath = childPhotoPath,
                                    usesChildPhoto = avatarUsesChildPhoto,
                                    avatarPresetRaw = avatarPreset,
                                    size = 32.dp,
                                )
                            },
                        )
                    }
                }
            }
            }

            statusMessage?.let {
                Text(
                    text = it,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 8.dp),
                )
            }

            Box(
                modifier = Modifier.fillMaxWidth().padding(24.dp),
                contentAlignment = Alignment.Center,
            ) {
                when (phase) {
                    TalkPhase.Transcribing, TalkPhase.Sending -> CircularProgressIndicator()
                    else -> {
                        Button(
                            onClick = {
                                val hasPermission = ContextCompat.checkSelfPermission(
                                    context, Manifest.permission.RECORD_AUDIO
                                ) == PackageManager.PERMISSION_GRANTED
                                if (hasPermission) {
                                    viewModel.onMicTap()
                                } else {
                                    val permissions = mutableListOf(
                                        Manifest.permission.RECORD_AUDIO,
                                    )
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                        permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                                    }
                                    permissionLauncher.launch(permissions.toTypedArray())
                                }
                            },
                            shape = CircleShape,
                            modifier = Modifier.size(88.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (phase == TalkPhase.Recording)
                                    MaterialTheme.colorScheme.error
                                else
                                    MaterialTheme.colorScheme.primary
                            ),
                        ) {
                            Icon(
                                imageVector = if (phase == TalkPhase.Recording) Icons.Filled.GraphicEq else Icons.Filled.Mic,
                                contentDescription = null,
                            )
                        }
                    }
                }
            }
        }
    }
}

// A time-of-day greeting with the parent's name/relation and a matching
// emoji -- shown on the empty Talk screen, i.e. exactly the moment the
// app opens (or a fresh tab, after backgrounding). Mirrors iOS's
// TalkView.greeting.
private fun greeting(parentName: String, parentRelation: String): String {
    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    val (text, emoji) = when (hour) {
        in 5..11 -> "Good morning" to "☀️"
        in 12..16 -> "Good afternoon" to "🌤️"
        in 17..20 -> "Good evening" to "🌆"
        else -> "Hello" to "🌙"
    }
    // Prefer how the child actually addresses the parent (Amma, Mom,
    // Appa, ...) set in Edit Profile -- reads far more like the child
    // themselves greeting them than a first name would. Falls back to
    // the parent's name, then to nothing, if relation isn't set.
    val relation = parentRelation.trim()
    val name = parentName.trim()
    val addressee = relation.ifBlank { name }
    return if (addressee.isBlank()) "$text! $emoji" else "$text, $addressee! $emoji"
}

// Same hour boundaries as greeting(), so the welcome gradient and Amma's
// reply bubbles share the greeting's mood (iOS 3a5b971 / a3071b7).
private fun timeOfDayAccent(): Color =
    when (Calendar.getInstance().get(Calendar.HOUR_OF_DAY)) {
        in 5..11 -> Color(0xFFFF9800)
        in 12..16 -> Color(0xFF2196F3)
        in 17..20 -> Color(0xFFE91E63)
        else -> Color(0xFF3F51B5)
    }

@Composable
private fun WelcomeState(
    accent: Color,
    homeScreenPhotoPath: String,
    homeScreenPreset: String,
    greetingText: String,
    modifier: Modifier = Modifier,
) {
    val entrance = remember { Animatable(0.85f) }
    LaunchedEffect(Unit) {
        entrance.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy))
    }
    Box(
        modifier = modifier.background(
            Brush.verticalGradient(listOf(accent.copy(alpha = 0.18f), Color.Transparent))
        ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(horizontal = 32.dp).scale(entrance.value),
        ) {
            Box(
                Modifier
                    .shadow(12.dp, CircleShape)
                    .border(4.dp, Color.White, CircleShape)
            ) {
                HomeScreenPictureView(
                    photoPath = homeScreenPhotoPath,
                    homeScreenPresetRaw = homeScreenPreset,
                    size = 140.dp,
                )
            }
            Spacer(Modifier.size(20.dp))
            Text(
                text = greetingText,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            Spacer(Modifier.size(12.dp))
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.7f),
                tonalElevation = 1.dp,
            ) {
                Text(
                    text = stringResource(R.string.talk_empty_state),
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                )
            }
        }
    }
}

// Chat bubbles, mirroring iOS a3071b7: the parent's words right-aligned in
// a filled pink bubble, Amma's reply left-aligned in a bordered bubble
// tinted with the time-of-day accent, with the chosen avatar beside it.
private val REACTION_EMOJI = listOf("✨", "💖", "😊", "🎉", "👋", "🌟")

// colorful = the pink / time-of-day tinted look; Plain swaps in neutral
// grays, same layout and shadows (iOS 88bee2e's message style setting).
@Composable
private fun TurnBubbles(
    turn: InteractionLog,
    accent: Color,
    colorful: Boolean,
    reaction: String?,
    avatar: @Composable () -> Unit,
) {
    val outgoingColor = if (colorful) AmmaPink else MaterialTheme.colorScheme.surfaceVariant
    val outgoingText = if (colorful) Color.White else MaterialTheme.colorScheme.onSurface
    val incomingFill = if (colorful) accent.copy(alpha = 0.08f) else MaterialTheme.colorScheme.surface
    val incomingBorder = if (colorful) accent.copy(alpha = 0.5f) else MaterialTheme.colorScheme.outlineVariant
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            Surface(
                shape = RoundedCornerShape(18.dp, 18.dp, 4.dp, 18.dp),
                color = outgoingColor,
                shadowElevation = 2.dp,
                modifier = Modifier.padding(start = 48.dp),
            ) {
                Text(
                    text = turn.transcript,
                    color = outgoingText,
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                )
            }
        }
        turn.responseText?.let { reply ->
            Row(
                Modifier.fillMaxWidth().padding(end = 48.dp),
                verticalAlignment = Alignment.Bottom,
            ) {
                avatar()
                Spacer(Modifier.size(8.dp))
                Box {
                    Surface(
                        shape = RoundedCornerShape(18.dp, 18.dp, 18.dp, 4.dp),
                        color = incomingFill,
                        border = BorderStroke(1.dp, incomingBorder),
                        shadowElevation = 2.dp,
                    ) {
                        Text(
                            text = reply,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                        )
                    }
                    // Keeps showing the emoji while it fades out after
                    // reaction goes back to null.
                    var shownEmoji by remember { mutableStateOf("") }
                    if (reaction != null) shownEmoji = reaction
                    androidx.compose.animation.AnimatedVisibility(
                        visible = reaction != null,
                        enter = scaleIn(initialScale = 0.3f, animationSpec = spring(dampingRatio = 0.6f)) + fadeIn(),
                        exit = fadeOut(),
                        modifier = Modifier.align(Alignment.TopEnd).offset { IntOffset(36, -40) },
                    ) {
                        Text(shownEmoji, fontSize = androidx.compose.ui.unit.TextUnit(26f, androidx.compose.ui.unit.TextUnitType.Sp))
                    }
                }
            }
        }
    }
}
