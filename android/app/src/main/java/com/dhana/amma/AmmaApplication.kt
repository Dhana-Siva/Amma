package com.dhana.amma

import android.app.Application
import com.dhana.amma.services.AmmaApiClient
import com.dhana.amma.services.AmmaPreferences
import com.dhana.amma.services.CastService
import com.dhana.amma.services.ContactsService
import com.dhana.amma.services.FamilyContext
import com.dhana.amma.services.NotificationHelper

class AmmaApplication : Application() {
    lateinit var familyContext: FamilyContext
        private set
    lateinit var preferences: AmmaPreferences
        private set
    lateinit var apiClient: AmmaApiClient
        private set
    lateinit var contactsService: ContactsService
        private set
    lateinit var castService: CastService
        private set

    override fun onCreate() {
        super.onCreate()
        familyContext = FamilyContext(this)
        preferences = AmmaPreferences(this)
        apiClient = AmmaApiClient()
        contactsService = ContactsService(this)
        castService = CastService()
        castService.configure(this)
        NotificationHelper.createChannel(this)
    }
}
