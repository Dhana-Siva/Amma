import Foundation

struct BehaviorProfile: Codable {
    var familyId: UUID
    var facts: [String: String]
    var routines: [String]
    var lastUpdated: Date
}

enum InteractionChannel: String, Codable {
    case tap
    case voice
    case scheduled
}

struct InteractionLog: Identifiable, Codable {
    let id: UUID
    var familyId: UUID
    var timestamp: Date
    var channel: InteractionChannel
    var transcript: String
    var intent: String?
    var responseText: String?
    var responseAudioURL: URL?
}
