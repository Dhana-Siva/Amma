package com.dhana.amma.services

import android.content.Context
import android.net.Uri
import android.provider.ContactsContract
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

@Serializable
data class AmmaContact(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val phoneNumber: String,
)

/**
 * "Amma's Contacts" — the small, deliberately-chosen list of people Amma
 * can call or message by voice, mirroring iOS's AmmaContactsStore. This
 * replaced mirroring the whole phonebook (iOS 32a6542): voice-triggered
 * calling is scoped to people the family actually added, and adding one
 * visibly changes the list. People are added through the system contact
 * picker (which grants one-off access to just the picked contact, so no
 * READ_CONTACTS permission is needed) or typed in by hand. Numbers stay
 * on the phone; only the spoken name ever reaches the backend.
 */
class ContactsService(private val context: Context) {

    private companion object {
        const val TAG = "AmmaContacts"
        const val PREFS = "amma_contacts"
        const val KEY_CONTACTS = "contacts"
    }

    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    private val _contacts = MutableStateFlow(load())
    val contacts: StateFlow<List<AmmaContact>> = _contacts.asStateFlow()

    private fun load(): List<AmmaContact> =
        prefs.getString(KEY_CONTACTS, null)
            ?.let { runCatching { json.decodeFromString<List<AmmaContact>>(it) }.getOrNull() }
            ?: emptyList()

    private fun save(list: List<AmmaContact>) {
        val sorted = list.sortedBy { it.name.lowercase() }
        prefs.edit().putString(KEY_CONTACTS, json.encodeToString(sorted)).apply()
        _contacts.value = sorted
    }

    /** Adds (or updates, matched by name) a contact. Returns false if either field is blank. */
    fun add(name: String, phoneNumber: String): Boolean {
        val trimmedName = name.trim()
        val trimmedNumber = phoneNumber.trim()
        if (trimmedName.isEmpty() || trimmedNumber.isEmpty()) return false
        val others = _contacts.value.filterNot { it.name.equals(trimmedName, ignoreCase = true) }
        save(others + AmmaContact(name = trimmedName, phoneNumber = trimmedNumber))
        return true
    }

    fun remove(id: String) {
        save(_contacts.value.filterNot { it.id == id })
    }

    /**
     * Reads the name and number from a contact picked via
     * Intent.ACTION_PICK on Phone.CONTENT_URI. The picker grants temporary
     * read access to that one row, so this works without READ_CONTACTS.
     */
    suspend fun readPicked(uri: Uri): Pair<String, String>? = withContext(Dispatchers.IO) {
        runCatching {
            context.contentResolver.query(
                uri,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                ),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val name = cursor.getString(0)
                val number = cursor.getString(1)
                if (name.isNullOrBlank() || number.isNullOrBlank()) null else name to number
            }
        }.onFailure { Log.e(TAG, "readPicked failed for $uri", it) }.getOrNull()
    }

    fun phoneNumber(name: String): String? {
        val contacts = _contacts.value
        Log.d(TAG, "phoneNumber: looking up '$name' among ${contacts.size} contacts")
        if (contacts.isEmpty()) return null

        val target = name.trim().lowercase()

        val exact = contacts.firstOrNull { contact ->
            val candidate = contact.name.trim().lowercase()
            candidate == target || candidate.contains(target) || target.contains(candidate)
        }
        if (exact != null) {
            Log.d(TAG, "phoneNumber: exact match '${exact.name}'")
            return exact.phoneNumber
        }

        val tolerance = max(1, target.length / 3)
        var best: AmmaContact? = null
        var bestDistance = Int.MAX_VALUE
        for (contact in contacts) {
            val distance = levenshtein(target, contact.name.trim().lowercase())
            if (distance < bestDistance) {
                bestDistance = distance
                best = contact
            }
        }
        Log.d(TAG, "phoneNumber: best fuzzy match '${best?.name}' distance=$bestDistance tolerance=$tolerance")
        return if (best != null && bestDistance <= tolerance) best.phoneNumber else null
    }

    private fun levenshtein(a: String, b: String): Int {
        val dp = Array(a.length + 1) { IntArray(b.length + 1) }
        for (i in 0..a.length) dp[i][0] = i
        for (j in 0..b.length) dp[0][j] = j
        for (i in 1..a.length) {
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                dp[i][j] = min(min(dp[i - 1][j] + 1, dp[i][j - 1] + 1), dp[i - 1][j - 1] + cost)
            }
        }
        return dp[a.length][b.length]
    }
}
