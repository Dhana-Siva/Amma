import ActivityKit
import Foundation

/// Shared between the main app (which starts/ends the activity) and the
/// AmmaWidget extension (which renders it) — compiled into both targets,
/// see project.yml.
///
/// A Live Activity is the persistent Dynamic Island / Lock Screen
/// equivalent, on iOS, of Android's floating "return to Amma" bubble: it
/// stays visible the whole time the parent is away in WhatsApp/Phone,
/// rather than a plain notification's few-second banner.
struct ReturnActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var message: String
    }
}
