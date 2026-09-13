package com.dhana.amma.ui.onboarding

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.dhana.amma.R

private const val PRIVACY_POLICY_URL = "https://dhana-siva.github.io/Amma/"

/** The "what we send, and to whom" content — shared between onboarding's
 * own step (OnboardingScreen) and the standalone gate (AIDisclosureGateScreen
 * below) so the same disclosure can be shown independently of onboarding
 * history. */
@Composable
fun AIDisclosureContent() {
    val context = LocalContext.current
    Text(stringResource(R.string.ai_disclosure_title), style = MaterialTheme.typography.headlineMedium)
    Spacer(Modifier.height(12.dp))
    Text(stringResource(R.string.ai_disclosure_body), style = MaterialTheme.typography.bodyLarge)
    Spacer(Modifier.height(12.dp))
    Text(
        stringResource(R.string.ai_disclosure_privacy_link),
        style = MaterialTheme.typography.bodySmall.copy(textDecoration = TextDecoration.Underline),
        modifier = Modifier.clickable {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY_URL)))
        },
    )
}

/** Shown once, ahead of MainTabs, to anyone whose device has
 * onboardingComplete = true but hasn't acknowledged this specific
 * disclosure yet — i.e. anyone who finished onboarding on a build from
 * before this screen existed. Wired up in AmmaRoot.kt. */
@Composable
fun AIDisclosureGateScreen(onAcknowledge: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        AIDisclosureContent()
        Spacer(Modifier.height(24.dp))
        Button(onClick = onAcknowledge, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.ai_disclosure_continue))
        }
    }
}
