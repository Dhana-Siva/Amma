package com.dhana.amma.ui

import android.app.Activity
import android.view.WindowManager
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Tv
import androidx.compose.material.icons.filled.Waves
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.dhana.amma.AmmaApplication
import com.dhana.amma.R
import com.dhana.amma.ui.onboarding.OnboardingScreen
import com.dhana.amma.ui.onboarding.TutorialScreen
import com.dhana.amma.ui.talk.TalkScreen

private enum class MainTab { Talk, Voice, Devices }

@Composable
fun AmmaRoot() {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication

    var onboardingComplete by remember { mutableStateOf(application.preferences.onboardingComplete) }
    var hasSeenTutorial by remember { mutableStateOf(application.preferences.hasSeenTutorial) }

    when {
        !onboardingComplete -> OnboardingScreen(onComplete = { onboardingComplete = true })
        !hasSeenTutorial -> TutorialScreen(onComplete = { hasSeenTutorial = true })
        else -> MainTabs(application)
    }
}

@Composable
private fun MainTabs(application: AmmaApplication) {
    var selectedTab by remember { mutableIntStateOf(0) }

    // Screen auto-lock backgrounds the app after a period of no touch
    // input, which would silently end an active Cast session mid-use —
    // Android equivalent of iOS's isIdleTimerDisabled toggling, scoped to
    // just the main tab area (not onboarding/tutorial).
    val activity = LocalContext.current as? Activity
    DisposableEffect(activity) {
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    // Backend family state is in-memory only and may have been lost since
    // the last launch (e.g. a Railway redeploy) — resend what onboarding
    // already collected, matching iOS's RootTabView.task.
    LaunchedEffect(Unit) {
        runCatching {
            application.apiClient.setupFamily(
                familyId = application.familyContext.familyId,
                parentName = application.preferences.parentName,
                childName = application.preferences.childName,
                language = application.preferences.languageCode,
                childPhoneNumber = application.preferences.childPhoneNumber,
            )
        }
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Filled.Waves, contentDescription = null) },
                    label = { Text(stringResource(R.string.tab_talk)) },
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Filled.Waves, contentDescription = null) },
                    label = { Text(stringResource(R.string.tab_voice)) },
                )
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = { Icon(Icons.Filled.Tv, contentDescription = null) },
                    label = { Text(stringResource(R.string.tab_devices)) },
                )
            }
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (selectedTab) {
                0 -> TalkScreen()
                else -> ComingSoon()
            }
        }
    }
}

@Composable
private fun ComingSoon() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(stringResource(R.string.coming_soon), style = MaterialTheme.typography.bodyLarge)
    }
}
