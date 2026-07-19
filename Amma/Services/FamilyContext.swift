import Foundation

final class FamilyContext {
    static let shared = FamilyContext()

    let familyId: UUID

    private init() {
        let key = "familyId"
        if let stored = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: stored) {
            familyId = uuid
        } else {
            let generated = UUID()
            UserDefaults.standard.set(generated.uuidString, forKey: key)
            familyId = generated
        }
    }
}
