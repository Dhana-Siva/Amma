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

    // Deliberately separate from onboardingComplete, matching the iOS fix
    // for the same App Store rejection (Amma sends every Talk message to
    // Anthropic + ElevenLabs with no disclosure at all before this existed).
    // onboardingComplete never resets once true, so gating this disclosure
    // on it alone would mean anyone who onboarded on a build before this
    // flag existed — including a Play Store reviewer's device — would
    // never see it on any later build. AmmaRoot checks this independently.
    var aiDisclosureAcknowledged: Boolean
        get() = prefs.getBoolean(KEY_AI_DISCLOSURE_ACKNOWLEDGED, false)
        set(value) = prefs.edit().putBoolean(KEY_AI_DISCLOSURE_ACKNOWLEDGED, value).apply()

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

    // Absolute path to a copy of the child's photo in app-private storage
    // (empty if none set) — copied there at pick/capture time since the
    // original content:// Uri from the system picker/camera isn't
    // guaranteed to stay valid long-term.
    var childPhotoPath: String
        get() = prefs.getString(KEY_CHILD_PHOTO_PATH, "") ?: ""
        set(value) = prefs.edit().putString(KEY_CHILD_PHOTO_PATH, value).apply()

    // Mirrors childPhotoPath but for the parent's own photo — matching
    // iOS's ProfileView, which has both a "You" and a "Child" slot.
    var parentPhotoPath: String
        get() = prefs.getString(KEY_PARENT_PHOTO_PATH, "") ?: ""
        set(value) = prefs.edit().putString(KEY_PARENT_PHOTO_PATH, value).apply()

    // How the child addresses the parent (e.g. "Amma", "Mom") -- used in
    // Talk's greeting instead of the parent's own name, since it reads
    // more like the child themselves greeting them.
    var parentRelation: String
        get() = prefs.getString(KEY_PARENT_RELATION, "") ?: ""
        set(value) = prefs.edit().putString(KEY_PARENT_RELATION, value).apply()

    // Custom photo for Talk's welcome/header picture (empty if a preset or
    // nothing is chosen instead) -- see homeScreenPreset.
    var homeScreenPhotoPath: String
        get() = prefs.getString(KEY_HOME_SCREEN_PHOTO_PATH, "") ?: ""
        set(value) = prefs.edit().putString(KEY_HOME_SCREEN_PHOTO_PATH, value).apply()

    // One of HomeScreenPreset's values, or empty if a custom photo (or
    // nothing) is chosen instead. Exactly one of preset/photo is active at
    // a time -- choosing one clears the other (see ProfileScreen).
    var homeScreenPreset: String
        get() = prefs.getString(KEY_HOME_SCREEN_PRESET, "") ?: ""
        set(value) = prefs.edit().putString(KEY_HOME_SCREEN_PRESET, value).apply()

    // Whether the small avatar shown next to Amma's name in Talk uses the
    // child's real photo (true, the default) or a chosen AvatarPreset
    // character icon (false) -- for a parent who hasn't uploaded, or
    // doesn't want to show, an actual photo there.
    var avatarUsesChildPhoto: Boolean
        get() = prefs.getBoolean(KEY_AVATAR_USES_CHILD_PHOTO, true)
        set(value) = prefs.edit().putBoolean(KEY_AVATAR_USES_CHILD_PHOTO, value).apply()

    // One of AvatarPreset's values, meaningful only when
    // avatarUsesChildPhoto is false.
    var avatarPreset: String
        get() = prefs.getString(KEY_AVATAR_PRESET, "") ?: ""
        set(value) = prefs.edit().putString(KEY_AVATAR_PRESET, value).apply()

    // Persisted mirror of voice-cloning consent — previously only lived
    // in VoiceSetupViewModel's in-memory state, reset to "not granted" on
    // every app restart even if the family had actually granted it on the
    // backend. Both VoiceSetupScreen and ProfileScreen read/write this.
    var voiceConsentGranted: Boolean
        get() = prefs.getBoolean(KEY_VOICE_CONSENT_GRANTED, false)
        set(value) = prefs.edit().putBoolean(KEY_VOICE_CONSENT_GRANTED, value).apply()

    private companion object {
        const val KEY_ONBOARDING_COMPLETE = "onboarding_complete"
        const val KEY_HAS_SEEN_TUTORIAL = "has_seen_tutorial"
        const val KEY_AI_DISCLOSURE_ACKNOWLEDGED = "ai_disclosure_acknowledged"
        const val KEY_LANGUAGE_CODE = "language_code"
        const val KEY_PARENT_NAME = "parent_name"
        const val KEY_CHILD_NAME = "child_name"
        const val KEY_CHILD_PHONE_NUMBER = "child_phone_number"
        const val KEY_CALLING_APP = "calling_app"
        const val KEY_CHILD_PHOTO_PATH = "child_photo_path"
        const val KEY_PARENT_PHOTO_PATH = "parent_photo_path"
        const val KEY_PARENT_RELATION = "parent_relation"
        const val KEY_HOME_SCREEN_PHOTO_PATH = "home_screen_photo_path"
        const val KEY_HOME_SCREEN_PRESET = "home_screen_preset"
        const val KEY_AVATAR_USES_CHILD_PHOTO = "avatar_uses_child_photo"
        const val KEY_AVATAR_PRESET = "avatar_preset"
        const val KEY_VOICE_CONSENT_GRANTED = "voice_consent_granted"
    }
}

object CallingApp {
    const val WHATSAPP = "whatsapp"
    const val VIBER = "viber"
    const val TELEGRAM = "telegram"

    // Experimental — added at the user's request to test whether Teams'
    // documented l/call deep link (normally used with work emails in
    // enterprise contexts) also works for a bare phone number on a
    // personal Teams account. Not confirmed working; drop if it isn't.
    const val TEAMS = "teams"
}
