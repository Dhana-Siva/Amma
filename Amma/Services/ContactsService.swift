import Contacts

enum ContactsServiceError: Error {
    case accessDenied
}

/// Thin wrapper over the phone's real Contacts (CNContactStore) — used
/// only for permission status/requests and for writing a new contact
/// there (so "Create New Contact" also shows up in the system Contacts
/// app, not just Amma's own list). Amma's actual voice-lookup and
/// curated contact list live in AmmaContactsStore instead — see its own
/// doc comment for why those are deliberately separate from the full
/// phone Contacts.
final class ContactsService {
    static let shared = ContactsService()

    // A single store instance for the app's lifetime — not one per call.
    // This isn't just efficiency: creating a fresh CNContactStore for
    // every operation caused a real bug, confirmed live — a contact saved
    // via one instance's CNSaveRequest wasn't reliably visible yet to a
    // different, freshly-created instance's enumerateContacts right
    // after. Apple's own guidance is to keep one instance around for
    // exactly this reason.
    private let store = CNContactStore()

    private init() {}

    /// Current system permission state, for a status row in Setup — read
    /// fresh each time rather than cached, since it can change out from
    /// under the app in Settings.
    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Explicitly triggers the system permission prompt (used from
    /// onboarding and Setup, ahead of any actual lookup). Safe to call
    /// even when already determined — `requestAccess` just returns the
    /// existing answer without re-prompting in that case.
    @discardableResult
    func requestAccessIfNeeded() async -> Bool {
        (try? await store.requestAccess(for: .contacts)) ?? false
    }

    /// Creates a new contact directly on the device — lets a parent add a
    /// family member to call/message by name without leaving Amma for
    /// the separate Contacts app. Splits `name` on the first space into
    /// given/family name (a plain heuristic, same as how most contact
    /// pickers behave for a single free-text name field).
    func addContact(name: String, phoneNumber: String) async throws {
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else { throw ContactsServiceError.accessDenied }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let parts = trimmedName.split(separator: " ", maxSplits: 1)

        let contact = CNMutableContact()
        contact.givenName = String(parts.first ?? "")
        if parts.count > 1 { contact.familyName = String(parts[1]) }
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phoneNumber))
        ]

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)
    }
}
