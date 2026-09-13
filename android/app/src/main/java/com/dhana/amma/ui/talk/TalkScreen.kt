package com.dhana.amma.ui.talk

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
    // per-feature — READ_CONTACTS/CALL_PHONE degrade gracefully if denied
    // (contact-by-name lookup just fails gracefully; calls fall back to
    // opening the dialer instead of auto-dialing), so only RECORD_AUDIO's
    // result gates whether we actually proceed with recording.
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        if (results[Manifest.permission.RECORD_AUDIO] == true) viewModel.onMicTap()
    }

    val childName = application.preferences.childName
    val parentName = application.preferences.parentName
    val parentRelation = application.preferences.parentRelation

    Scaffold { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                AvatarView(size = 36.dp)
                Spacer(Modifier.size(12.dp))
                Text(
                    childName.ifBlank { "Amma" },
                    style = MaterialTheme.typography.headlineMedium,
                )
            }

            if (log.isEmpty()) {
                Box(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(horizontal = 32.dp),
                    ) {
                        HomeScreenPictureView(size = 140.dp)
                        Spacer(Modifier.size(20.dp))
                        Text(
                            text = greeting(parentName, parentRelation),
                            style = MaterialTheme.typography.titleLarge,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        )
                        Spacer(Modifier.size(12.dp))
                        Text(
                            text = stringResource(R.string.talk_empty_state),
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                        )
                    }
                }
            } else {
                HomeScreenPictureView(size = 64.dp)
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().weight(1f),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(log) { turn -> TurnRow(turn) }
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
                                        Manifest.permission.READ_CONTACTS,
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

@Composable
private fun TurnRow(turn: InteractionLog) {
    Column {
        Text(text = turn.transcript, style = MaterialTheme.typography.bodyMedium)
        turn.responseText?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.secondary,
            )
        }
    }
}
