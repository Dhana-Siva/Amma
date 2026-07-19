import Foundation

struct Family: Identifiable, Codable {
    let id: UUID
    var parentName: String
    var childName: String
    var createdAt: Date
}
