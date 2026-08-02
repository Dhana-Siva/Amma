package com.dhana.amma.services

import android.content.Context

class AmmaPreferences(context: Context) {
    private val prefs = context.getSharedPreferences("amma_prefs", Context.MODE_PRIVATE)

    var onboardingComplete: Boolean
        get() = prefs.getBoolean(KEY_ONBOARDING_COMPLETE, false)
        set(value) = prefs.edit().putBoolean(KEY_ONBOARDING_COMPLETE, value).apply()

    var hasSeenTutorial: Boolean
        get() = prefs.getBoolean(KEY_HAS_SEEN_TUTORIAL, false)
        set(value) = prefs.edit().putBoolean(KEY_HAS_SEEN_TUTORIAL, value).apply()

    var languageCode: String
        get() = prefs.getString(KEY_LANGUAGE_CODE, "en") ?: "en"
        set(value) = prefs.edit().putString(KEY_LANGUAGE_CODE, value).apply()

    var parentName: String
        get() = prefs.getString(KEY_PARENT_NAME, "") ?: ""
        set(value) = prefs.edit().putString(KEY_PARENT_NAME, value).apply()

    var childName: String
        get() = prefs.getString(KEY_CHILD_NAME, "") ?: ""
        set(value) = prefs.edit().putString(KEY_CHILD_NAME, value).apply()

    var childPhoneNumber: String
        get() = prefs.getString(KEY_CHILD_PHONE_NUMBER, "") ?: ""
        set(value) = prefs.edit().putString(KEY_CHILD_PHONE_NUMBER, value).apply()

    // One of CallingApp's values below — which app placeCall opens.
    // Messaging always goes through WhatsApp regardless of this setting,
    // since Viber/Skype-only calling keeps that behavior simple.
    var callingApp: String
        get() = prefs.getString(KEY_CALLING_APP, CallingApp.WHATSAPP) ?: CallingApp.WHATSAPP
        set(value) = prefs.edit().putString(KEY_CALLING_APP, value).apply()

    private companion object {
        const val KEY_ONBOARDING_COMPLETE = "onboarding_complete"
        const val KEY_HAS_SEEN_TUTORIAL = "has_seen_tutorial"
        const val KEY_LANGUAGE_CODE = "language_code"
        const val KEY_PARENT_NAME = "parent_name"
        const val KEY_CHILD_NAME = "child_name"
        const val KEY_CHILD_PHONE_NUMBER = "child_phone_number"
        const val KEY_CALLING_APP = "calling_app"
    }
}

object CallingApp {
    const val WHATSAPP = "whatsapp"
    const val VIBER = "viber"
    const val SKYPE = "skype"
}
