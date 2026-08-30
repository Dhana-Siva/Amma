import Foundation

/// One entry in Amma's own curated contact list — deliberately separate
/// from the phone's full Contacts app. See AmmaContactsStore for why.
struct AmmaContact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var phoneNumber: String
}
