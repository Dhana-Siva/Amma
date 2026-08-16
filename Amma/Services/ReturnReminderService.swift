import UserNotifications

/// Fires a local notification right when Amma hands off to WhatsApp or
/// the Phone app for a call/message, so there's a visible, tappable way
/// back — especially for a parent who isn't used to switching between
/// apps. iOS doesn't allow a floating "return" bubble over other apps
/// the way Android does; a notification is the closest equivalent —
/// it sits in Notification Center and on the lock screen until tapped,
/// and tapping it just brings Amma back to the foreground with no extra
/// deep-link plumbing needed.
enum ReturnReminderService {
    private static let identifier = "return-to-amma"

    /// Best-effort, silent — only asks if never asked before, never
    /// blocks or interrupts a call/message from going through either way.
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            // .timeSensitive must be explicitly requested here, or content
            // marked .timeSensitive below won't actually be treated as
            // such — it'd just fall back to the default interruption level.
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .timeSensitive]) { _, _ in }
        }
    }

    /// Schedules the "come back" notification a couple seconds out, by
    /// which point iOS has already handed the screen to WhatsApp/Phone.
    /// Reuses one fixed identifier so repeated calls replace rather than
    /// stack up in Notification Center.
    static func scheduleReturnReminder() {
        let content = UNMutableNotificationContent()
        content.title = "👋 Amma"
        content.body = "Tap to come back to Amma when you're done."
        content.sound = .default
        // Without this, iOS can silently hold or suppress the banner under
        // a Focus mode (Sleep, Do Not Disturb, Personal, ...) even with
        // notification permission granted — .timeSensitive is the level
        // that's allowed to break through those by default. No extra
        // entitlement needed (unlike .critical).
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
