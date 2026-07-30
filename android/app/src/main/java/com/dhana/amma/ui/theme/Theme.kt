package com.dhana.amma.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val AmmaColorScheme = lightColorScheme(
    primary = AmmaPink,
    secondary = AmmaBlue,
    background = AmmaBackground,
)

@Composable
fun AmmaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = AmmaColorScheme,
        content = content,
    )
}
