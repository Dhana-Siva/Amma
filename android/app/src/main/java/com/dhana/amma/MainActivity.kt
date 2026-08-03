package com.dhana.amma

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.fragment.app.FragmentActivity
import com.dhana.amma.services.NotificationHelper
import com.dhana.amma.ui.AmmaRoot
import com.dhana.amma.ui.theme.AmmaTheme

// FragmentActivity (not plain ComponentActivity) is required by
// MediaRouteButton — its device-picker dialog is a DialogFragment and
// crashes with "must be a subclass of FragmentActivity" otherwise.
class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AmmaTheme {
                AmmaRoot()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Whether they tapped the ongoing "return to Amma" notification or
        // just switched back manually, being here means they're back —
        // clear it so it doesn't linger after it's served its purpose.
        NotificationHelper.clearReturnToAmma(this)
    }
}
