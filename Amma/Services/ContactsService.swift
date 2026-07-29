import Contacts

struct ContactSummary: Identifiable {
    let id = UUID()
    let name: String
    let phoneNumbers: [String]
}

final class ContactsService {
    static let shared = ContactsService()

    private init() {}

    /// All contacts with at least one phone number, for the in-app browser —
    /// lets the parent see exactly what Amma sees (e.g. to check how a name
    /// or number is actually saved after a failed lookup).
    func allContacts() async -> [ContactSummary] {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else { return [] }

        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var results: [ContactSummary] = []
        try? store.enumerateContacts(with: request) { contact, _ in
            guard !contact.phoneNumbers.isEmpty else { return }
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            results.append(ContactSummary(name: name, phoneNumbers: contact.phoneNumbers.map { $0.value.stringValue }))
        }
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Looks up a phone number by contact name on-device. Numbers never leave
    /// the phone — the backend only ever sees the name the parent said.
    ///
    /// Matching is fuzzy on purpose: names spoken in Tamil (or any language)
    /// get transliterated by the model into a guessed English spelling, which
    /// often won't exactly match how the contact is actually saved (e.g.
    /// "Diya" said for a contact saved as "Daya"). An exact match wins
    /// immediately; otherwise the closest name within an edit-distance
    /// tolerance is used.
    func phoneNumber(forName name: String) async -> String? {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else { return nil }

        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        let target = name.lowercased()

        var exactMatch: CNContact?
        var bestFuzzyMatch: CNContact?
        var bestFuzzyDistance = Int.max

        try? store.enumerateContacts(with: request) { contact, stop in
            guard !contact.phoneNumbers.isEmpty else { return }
            let givenName = contact.givenName.lowercased()
            let fullName = "\(contact.givenName) \(contact.familyName)"
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            guard !fullName.isEmpty else { return }

            if fullName == target || givenName == target || fullName.contains(target) || target.contains(givenName) {
                exactMatch = contact
                stop.pointee = true
                return
            }

            let distance = min(Self.levenshteinDistance(target, givenName), Self.levenshteinDistance(target, fullName))
            if distance < bestFuzzyDistance {
                bestFuzzyDistance = distance
                bestFuzzyMatch = contact
            }
        }

        if let exactMatch {
            return exactMatch.phoneNumbers.first?.value.stringValue
        }
        // Tolerance scales with name length so short names still need a close
        // match, e.g. "Daya" (4 chars) allows a distance of up to 1-2.
        let tolerance = max(1, target.count / 3)
        guard bestFuzzyDistance <= tolerance else { return nil }
        return bestFuzzyMatch?.phoneNumbers.first?.value.stringValue
    }

    private static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previousRow = Array(0...b.count)
        var currentRow = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            currentRow[0] = i
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    currentRow[j] = previousRow[j - 1]
                } else {
                    currentRow[j] = 1 + min(previousRow[j - 1], previousRow[j], currentRow[j - 1])
                }
            }
            previousRow = currentRow
        }
        return previousRow[b.count]
    }
}
