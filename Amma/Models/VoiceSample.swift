import Foundation

struct VoiceSample: Identifiable, Codable {
    let id: UUID
    var familyId: UUID
    var consentId: UUID
    var storageURL: URL
    var durationSeconds: Double
    var transcript: String?
}

enum VoicePersonaStatus: String, Codable {
    case notStarted
    case training
    case ready
    case failed
}

struct VoicePersonaModel: Identifiable, Codable {
    let id: UUID
    var familyId: UUID
    var provider: String
    var providerModelId: String?
    var status: VoicePersonaStatus
}
