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
