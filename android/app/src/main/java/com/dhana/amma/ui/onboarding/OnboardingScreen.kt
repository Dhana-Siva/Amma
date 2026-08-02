package com.dhana.amma.ui.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dhana.amma.AmmaApplication
import com.dhana.amma.R
import com.dhana.amma.services.CallingApp
import kotlinx.coroutines.launch

@Composable
fun OnboardingScreen(onComplete: () -> Unit) {
    val context = LocalContext.current
    val application = context.applicationContext as AmmaApplication
    val scope = rememberCoroutineScope()

    var step by remember { mutableIntStateOf(0) }
    var parentName by remember { mutableStateOf("") }
    var childName by remember { mutableStateOf("") }
    var childPhoneNumber by remember { mutableStateOf("") }
    var languageCode by remember { mutableStateOf("en") }
    var callingApp by remember { mutableStateOf(CallingApp.WHATSAPP) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        when (step) {
            0 -> {
                Text(stringResource(R.string.onboarding_welcome_title), style = MaterialTheme.typography.headlineMedium)
                Spacer(Modifier.height(12.dp))
                Text(stringResource(R.string.onboarding_welcome_body), style = MaterialTheme.typography.bodyLarge)
            }
            1 -> {
                OutlinedTextField(
                    value = parentName,
                    onValueChange = { parentName = it },
                    label = { Text(stringResource(R.string.onboarding_parent_name)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = childName,
                    onValueChange = { childName = it },
                    label = { Text(stringResource(R.string.onboarding_child_name)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = childPhoneNumber,
                    onValueChange = { childPhoneNumber = it },
                    label = { Text(stringResource(R.string.onboarding_child_phone)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(16.dp))
                Text(stringResource(R.string.onboarding_language), style = MaterialTheme.typography.labelLarge)
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    LanguageOption("தமிழ்", selected = languageCode == "ta") { languageCode = "ta" }
                    LanguageOption("English", selected = languageCode == "en") { languageCode = "en" }
                }
            }
            2 -> {
                Text(stringResource(R.string.onboarding_calling_app_title), style = MaterialTheme.typography.headlineMedium)
                Spacer(Modifier.height(8.dp))
                Text(stringResource(R.string.onboarding_calling_app_body), style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(16.dp))
                CallingAppOption("WhatsApp", selected = callingApp == CallingApp.WHATSAPP) { callingApp = CallingApp.WHATSAPP }
                CallingAppOption("Viber", selected = callingApp == CallingApp.VIBER) { callingApp = CallingApp.VIBER }
                CallingAppOption("Google Meet", selected = callingApp == CallingApp.DUO) { callingApp = CallingApp.DUO }
            }
            3 -> {
                val name = childName.ifBlank { "your child" }
                Text(stringResource(R.string.onboarding_consent_title), style = MaterialTheme.typography.headlineMedium)
                Spacer(Modifier.height(12.dp))
                Text(
                    stringResource(R.string.onboarding_consent_body, name),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }

        Spacer(Modifier.height(24.dp))

        val canContinue = step != 1 || (parentName.isNotBlank() && childName.isNotBlank())
        Button(
            onClick = {
                if (step < 3) {
                    step += 1
                } else {
                    application.preferences.apply {
                        this.languageCode = languageCode
                        this.parentName = parentName
                        this.childName = childName
                        this.childPhoneNumber = childPhoneNumber.trim()
                        this.callingApp = callingApp
                        this.onboardingComplete = true
                    }
                    scope.launch {
                        runCatching {
                            application.apiClient.setupFamily(
                                familyId = application.familyContext.familyId,
                                parentName = parentName,
                                childName = childName,
                                language = languageCode,
                                childPhoneNumber = childPhoneNumber.trim().ifBlank { null },
                            )
                        }
                    }
                    onComplete()
                }
            },
            enabled = canContinue,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (step < 3) stringResource(R.string.onboarding_continue) else stringResource(R.string.onboarding_get_started))
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

@Composable
private fun CallingAppOption(label: String, selected: Boolean, onSelect: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .selectable(selected = selected, onClick = onSelect),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = onSelect)
        Text(label)
    }
}
