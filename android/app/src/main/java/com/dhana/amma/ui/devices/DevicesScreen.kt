package com.dhana.amma.ui.devices

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.widget.FrameLayout
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.mediarouter.app.MediaRouteButton
import com.dhana.amma.AmmaApplication
import com.dhana.amma.R
import com.google.android.gms.cast.framework.CastButtonFactory

@Composable
fun DevicesScreen() {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication
    val castService = application.castService

    val isConnected by castService.isConnected.collectAsState()
    val connectedDeviceName by castService.connectedDeviceName.collectAsState()

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
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
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
    }
}
