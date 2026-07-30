package com.dhana.amma.services

import android.content.Context
import java.util.UUID

class FamilyContext(context: Context) {
    private val prefs = context.getSharedPreferences("amma_family", Context.MODE_PRIVATE)

    val familyId: UUID by lazy {
        val stored = prefs.getString(KEY_FAMILY_ID, null)
        if (stored != null) {
            UUID.fromString(stored)
        } else {
            val generated = UUID.randomUUID()
            prefs.edit().putString(KEY_FAMILY_ID, generated.toString()).apply()
            generated
        }
    }

    private companion object {
        const val KEY_FAMILY_ID = "family_id"
    }
}
