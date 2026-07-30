package com.dhana.amma

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.dhana.amma.ui.AmmaRoot
import com.dhana.amma.ui.theme.AmmaTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AmmaTheme {
                AmmaRoot()
            }
        }
    }
}
