package com.dhana.amma.ui.devices

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.widget.FrameLayout
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.mediarouter.app.MediaRouteButton
import com.dhana.amma.AmmaApplication
import com.dhana.amma.R
import com.dhana.amma.services.CallingApp
import com.dhana.amma.services.OverlayHelper
import com.google.android.gms.cast.framework.CastButtonFactory
import kotlinx.coroutines.launch

@Composable
fun DevicesScreen() {
    var showContacts by remember { mutableStateOf(false) }

    if (showContacts) {
        ContactsListScreen(onBack = { showContacts = false })
    } else {
        DevicesMainScreen(onViewContacts = { showContacts = true })
    }
}

@Composable
private fun DevicesMainScreen(onViewContacts: () -> Unit) {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication
    val castService = application.castService
    val scope = rememberCoroutineScope()

    val isConnected by castService.isConnected.collectAsState()
    val connectedDeviceName by castService.connectedDeviceName.collectAsState()

    var languageCode by remember { mutableStateOf(application.preferences.languageCode) }
    var callingApp by remember { mutableStateOf(application.preferences.callingApp) }
    var hasOverlayPermission by remember { mutableStateOf(OverlayHelper.canDrawOverlays(context)) }

    // Granting "display over other apps" happens in system settings, not
    // an in-app dialog — re-check when the user comes back to this screen
    // (e.g. returning from that settings page) rather than only once.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                hasOverlayPermission = OverlayHelper.canDrawOverlays(context)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    fun onLanguageSelected(code: String) {
        languageCode = code
        application.preferences.languageCode = code
        scope.launch {
            runCatching {
                application.apiClient.setupFamily(
                    familyId = application.familyContext.familyId,
                    parentName = application.preferences.parentName,
                    childName = application.preferences.childName,
                    language = code,
                    childPhoneNumber = application.preferences.childPhoneNumber,
                )
            }
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { /* Cast discovery works either way; this only affects device-name detail on some OEMs. */ }

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                permissionLauncher.launch(Manifest.permission.NEARBY_WIFI_DEVICES)
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Language", style = MaterialTheme.typography.labelLarge, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            LanguageOption("தமிழ்", selected = languageCode == "ta") { onLanguageSelected("ta") }
            LanguageOption("English", selected = languageCode == "en") { onLanguageSelected("en") }
        }

        Spacer(Modifier.height(24.dp))
        HorizontalDivider()
        Spacer(Modifier.height(24.dp))

        Text("Calling app", style = MaterialTheme.typography.labelLarge, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        LanguageOption("WhatsApp", selected = callingApp == CallingApp.WHATSAPP) {
            callingApp = CallingApp.WHATSAPP
            application.preferences.callingApp = CallingApp.WHATSAPP
        }
        LanguageOption("Viber", selected = callingApp == CallingApp.VIBER) {
            callingApp = CallingApp.VIBER
            application.preferences.callingApp = CallingApp.VIBER
        }
        LanguageOption("Telegram", selected = callingApp == CallingApp.TELEGRAM) {
            callingApp = CallingApp.TELEGRAM
            application.preferences.callingApp = CallingApp.TELEGRAM
        }
        LanguageOption("Teams (experimental)", selected = callingApp == CallingApp.TEAMS) {
            callingApp = CallingApp.TEAMS
            application.preferences.callingApp = CallingApp.TEAMS
        }

        Spacer(Modifier.height(24.dp))
        HorizontalDivider()
        Spacer(Modifier.height(24.dp))

        Text("Return-to-Amma button", style = MaterialTheme.typography.labelLarge, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        Text(
            if (hasOverlayPermission) {
                "On — a floating button appears to bring you back to Amma after a call or message."
            } else {
                "Off — you'll get a notification instead, which needs an extra swipe-and-tap gesture."
            },
            style = MaterialTheme.typography.bodyMedium,
        )
        if (!hasOverlayPermission) {
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = { OverlayHelper.requestPermission(context) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Turn on floating button")
            }
        }

        Spacer(Modifier.height(24.dp))
        HorizontalDivider()
        Spacer(Modifier.height(24.dp))

        Text(
            text = if (isConnected) {
                stringResource(R.string.devices_connected, connectedDeviceName ?: "TV")
            } else {
                stringResource(R.string.devices_not_connected)
            },
            style = MaterialTheme.typography.bodyLarge,
        )

        Spacer(Modifier.height(12.dp))

        // MediaRouteButton is a classic View widget — Compose has no
        // built-in equivalent, and it's what opens Google's own Cast
        // device picker dialog (device discovery/selection UI is handled
        // entirely by the system, not custom-built here).
        AndroidView(
            factory = { ctx ->
                val button = MediaRouteButton(ctx)
                CastButtonFactory.setUpMediaRouteButton(ctx, button)
                FrameLayout(ctx).apply { addView(button) }
            },
            modifier = Modifier.fillMaxWidth(),
        )

        if (isConnected) {
            Button(
                onClick = { castService.disconnect() },
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
            ) {
                Text(stringResource(R.string.devices_disconnect))
            }
        }

        Spacer(Modifier.height(24.dp))
        HorizontalDivider()
        Spacer(Modifier.height(24.dp))

        OutlinedButton(onClick = onViewContacts, modifier = Modifier.fillMaxWidth()) {
            Text("View phone contacts")
        }
    }
}

@Composable
private fun LanguageOption(label: String, selected: Boolean, onSelect: () -> Unit) {
    Row(
        modifier = Modifier.selectable(selected = selected, onClick = onSelect),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = onSelect)
        Text(label)
    }
}
