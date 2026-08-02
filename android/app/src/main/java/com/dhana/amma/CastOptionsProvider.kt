package com.dhana.amma

import android.content.Context
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider

/**
 * Registered via the manifest's OPTIONS_PROVIDER_CLASS_NAME meta-data.
 * Points at Amma's own custom Cast receiver (not a generic media receiver)
 * — same Application ID the iOS app uses, hosted at
 * https://dhana-siva.github.io/amma-cast-receiver/.
 */
class CastOptionsProvider : OptionsProvider {
    override fun getCastOptions(context: Context): CastOptions =
        CastOptions.Builder()
            .setReceiverApplicationId("592BF965")
            .build()

    override fun getAdditionalSessionProviders(context: Context): List<SessionProvider>? = null
}
