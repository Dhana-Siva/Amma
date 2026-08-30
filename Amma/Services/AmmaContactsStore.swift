import Foundation

/// The curated list of people Amma can call/message by voice — a small,
/// deliberate set the parent picks one at a time (via "Choose from
/// Contacts" or "Create New Contact" in Setup), not the entire phone's
/// Contacts.
///
/// This is a real product decision, not just a UI convenience: scoping
/// voice-triggered calling to a short, trusted list is safer for a
/// parent who might misname someone, or whose phone has a large
/// phonebook full of people Amma has no business calling. It's also
/// simply what "add a contact" needs to mean for the add action to do
/// anything at all — mirroring the whole phonebook (the earlier
/// approach) made every "add" a no-op, since everyone was already shown.
///
/// Kept as a plain in-memory + UserDefaults store (an ObservableObject,
/// so views update live with no manual refresh) — not backed by
/// CNContactStore, so there's no read-after-write staleness class of bug
/// to worry about here.
@MainActor
final class AmmaContactsStore: ObservableObject {
    static let shared = AmmaContactsStore()
    private static let storageKey = "ammaContacts"

    @Published private(set) var contacts: [AmmaContact] = []

    private init() {
        load()
    }

    func add(name: String, phoneNumber: String) {
        contacts.append(AmmaContact(id: UUID(), name: name, phoneNumber: phoneNumber))
        save()
    }

    func remove(_ contact: AmmaContact) {
        contacts.removeAll { $0.id == contact.id }
        save()
    }

    /// Fuzzy name lookup for voice commands — same matching approach
    /// ContactsService previously used against the full phonebook (an
    /// exact/substring match wins immediately; otherwise the closest
    /// name within a length-scaled edit-distance tolerance), just scoped
    /// to this curated list now instead.
    func phoneNumber(forName name: String) -> String? {
        let target = name.lowercased()
        guard !target.isEmpty else { return nil }

        var bestFuzzyMatch: AmmaContact?
        var bestFuzzyDistance = Int.max

        for contact in contacts {
            let contactName = contact.name.lowercased()
            guard !contactName.isEmpty else { continue }
            if contactName == target || contactName.contains(target) || target.contains(contactName) {
                return contact.phoneNumber
            }
            let distance = Self.levenshteinDistance(target, contactName)
            if distance < bestFuzzyDistance {
                bestFuzzyDistance = distance
                bestFuzzyMatch = contact
            }
        }

        let tolerance = max(1, target.count / 3)
        guard bestFuzzyDistance <= tolerance else { return nil }
        return bestFuzzyMatch?.phoneNumber
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([AmmaContact].self, from: data) else { return }
        contacts = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(contacts) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
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
