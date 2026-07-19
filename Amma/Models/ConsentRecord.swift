import Foundation

enum ConsentType: String, Codable {
    case voiceSample
    case behaviorData
}

struct ConsentRecord: Identifiable, Codable {
    let id: UUID
    var familyId: UUID
    var type: ConsentType
    var grantedAt: Date
    var revokedAt: Date?

    var isActive: Bool { revokedAt == nil }
}
