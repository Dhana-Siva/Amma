import Foundation

enum CommandIntent: String, Codable {
    case castMedia
    case placeCall
    case sendMessage
}

enum CommandStatus: String, Codable {
    case pending
    case executed
    case failed
}

struct Command: Identifiable, Codable {
    let id: UUID
    var familyId: UUID
    var intent: CommandIntent
    var params: [String: String]
    var status: CommandStatus
    var executedAt: Date?
}
