import Foundation

enum DeviceType: String, Codable {
    case iphone
    case appleTV
    case chromecast
}

struct PairedDevice: Identifiable, Codable {
    let id: UUID
    var familyId: UUID
    var type: DeviceType
    var name: String
    var pairedAt: Date?
}

enum IntegrationType: String, Codable {
    case whatsapp
    case phone
    case cast
}

enum IntegrationStatus: String, Codable {
    case notConnected
    case connected
    case error
}

struct Integration: Identifiable, Codable {
    let id: UUID
    var familyId: UUID
    var type: IntegrationType
    var status: IntegrationStatus
}
