import Foundation

/// Which app Amma should hand off to for a call, when the parent hasn't
/// named a specific contact app — chosen once during onboarding,
/// changeable anytime after in Setup > Calling.
enum PreferredCallMethod: String, CaseIterable, Identifiable {
    case whatsapp
    case phone

    var id: Self { self }

    var title: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .phone: return "Phone Call"
        }
    }
}
