package com.dhana.amma.services

import android.content.Context
import android.content.pm.PackageManager
import android.provider.ContactsContract
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

data class ContactSummary(
    val id: UUID,
    val name: String,
    val phoneNumbers: List<String>,
)

class ContactsService(private val context: Context) {

    private companion object {
        const val TAG = "AmmaContacts"
    }

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, android.Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    suspend fun allContacts(): List<ContactSummary> = withContext(Dispatchers.IO) {
        if (!hasPermission()) {
            Log.d(TAG, "allContacts: READ_CONTACTS not granted, returning empty")
            return@withContext emptyList()
        }

        val byName = LinkedHashMap<String, MutableList<String>>()
        val cursor = context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            ),
            null,
            null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC",
        )
        Log.d(TAG, "allContacts: query returned cursor=${cursor != null}, count=${cursor?.count}")
        cursor?.use {
            val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (it.moveToNext()) {
                val name = it.getString(nameIdx) ?: continue
                val number = it.getString(numberIdx) ?: continue
                byName.getOrPut(name) { mutableListOf() }.add(number)
            }
        }
        val result = byName.entries
            .sortedBy { it.key.lowercase() }
            .map { (name, numbers) -> ContactSummary(id = UUID.randomUUID(), name = name, phoneNumbers = numbers) }
        Log.d(TAG, "allContacts: resolved ${result.size} distinct names: ${result.take(10).map { it.name }}")
        result
    }

    suspend fun phoneNumber(name: String): String? = withContext(Dispatchers.IO) {
        val contacts = allContacts()
        Log.d(TAG, "phoneNumber: looking up '$name' among ${contacts.size} contacts")
        if (contacts.isEmpty()) return@withContext null

        val target = name.trim().lowercase()

        val exact = contacts.firstOrNull { contact ->
            val candidate = contact.name.trim().lowercase()
            candidate == target || candidate.contains(target) || target.contains(candidate)
        }
        if (exact != null) {
            Log.d(TAG, "phoneNumber: exact match '${exact.name}'")
            return@withContext exact.phoneNumbers.firstOrNull()
        }

        val tolerance = max(1, target.length / 3)
        var best: ContactSummary? = null
        var bestDistance = Int.MAX_VALUE
        for (contact in contacts) {
            val distance = levenshtein(target, contact.name.trim().lowercase())
            if (distance < bestDistance) {
                bestDistance = distance
                best = contact
            }
        }
        Log.d(TAG, "phoneNumber: best fuzzy match '${best?.name}' distance=$bestDistance tolerance=$tolerance")
        if (best != null && bestDistance <= tolerance) best.phoneNumbers.firstOrNull() else null
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
