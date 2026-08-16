import ActivityKit

/// Starts/ends the "return to Amma" Live Activity — a Dynamic Island /
/// Lock Screen presence that stays visible for as long as the parent is
/// away in WhatsApp or Phone, not just a few seconds like a plain
/// notification banner. The closest iOS equivalent to Android's floating
/// return bubble, since iOS doesn't allow overlaying other apps.
@MainActor
enum ReturnActivityService {
    private static var currentActivity: Activity<ReturnActivityAttributes>?

    /// Starts the activity if the system allows it (Live Activities can
    /// be off entirely via a system Settings toggle, or unsupported).
    /// Returns whether it actually started, so CommandExecutor can fall
    /// back to a plain notification when it didn't.
    @discardableResult
    static func start() -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        // Only one at a time — replace rather than stack if a second
        // call/message goes out before the first was returned from.
        end()

        let state = ReturnActivityAttributes.ContentState(
            message: "Tap to come back to Amma when you're done."
        )
        do {
            currentActivity = try Activity.request(
                attributes: ReturnActivityAttributes(),
                content: .init(state: state, staleDate: nil)
            )
            return true
        } catch {
            currentActivity = nil
            return false
        }
    }

    /// Ends the activity — called once Amma is back in the foreground,
    /// whether that's from tapping the activity itself or just reopening
    /// the app normally, since its job is done either way.
    static func end() {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
