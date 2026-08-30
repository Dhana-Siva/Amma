import UIKit

/// What happened after executing a command — most intents just succeed or
/// fail with a message, but castMedia has a third case: no TV linked, so
/// play the video right in the app instead of just reporting failure.
enum CommandOutcome {
    case success
    case errorMessage(String)
    case playInAppVideo(videoId: String, title: String?)
}

@MainActor
enum CommandExecutor {
    /// Executes the command and reports what happened.
    @discardableResult
    static func execute(_ command: Command) async -> CommandOutcome {
        switch command.intent {
        case .placeCall:
            guard let phoneNumber = await resolvePhoneNumber(command) else {
                return .errorMessage("Couldn't find that contact to call.")
            }
            let sanitized = sanitize(phoneNumber)
            switch preferredCallMethod {
            case .whatsapp:
                // WhatsApp has no documented URL scheme for starting a call
                // (only for opening a chat), so this undocumented one is
                // best-effort — fall back to a regular call if it's not
                // available, same as if the parent had chosen Phone.
                if let whatsAppCallURL = URL(string: "whatsapp://calluser/?phone=\(sanitized)"),
                   UIApplication.shared.canOpenURL(whatsAppCallURL) {
                    open(whatsAppCallURL, remindToReturn: true)
                } else {
                    open(URL(string: "tel://\(sanitized)"), remindToReturn: true)
                }
            case .phone:
                open(URL(string: "tel://\(sanitized)"), remindToReturn: true)
            }
            return .success

        case .sendMessage:
            guard let phoneNumber = await resolvePhoneNumber(command) else {
                return .errorMessage("Couldn't find that contact to message.")
            }
            let text = command.params["text"] ?? ""
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            open(URL(string: "whatsapp://send?phone=\(sanitize(phoneNumber))&text=\(encodedText)"), remindToReturn: true)
            return .success

        case .castMedia:
            CastService.logDiagnostic("[AmmaCast] CommandExecutor received castMedia, params=\(command.params)")
            guard let videoId = command.params["videoId"], !videoId.isEmpty else {
                return .errorMessage("Couldn't find that to play.")
            }
            do {
                try CastService.shared.play(videoId: videoId)
                return .success
            } catch CastServiceError.notConnected {
                // No TV linked — rather than just reporting failure, play
                // the video right in the app. Casting is a nice-to-have,
                // not a hard requirement for "play X" to be useful at all.
                return .playInAppVideo(videoId: videoId, title: command.params["title"])
            } catch {
                return .errorMessage("Couldn't cast that to the TV right now.")
            }

        case .stopCast:
            CastService.logDiagnostic("[AmmaCast] CommandExecutor received stopCast")
            do {
                try CastService.shared.stop()
                return .success
            } catch CastServiceError.notConnected {
                return .errorMessage("Nothing's linked to the TV right now.")
            } catch {
                return .errorMessage("Couldn't stop the TV right now.")
            }
        }
    }

    /// A named contact takes priority — looked up in Amma's own curated
    /// list (AmmaContactsStore), not the full phone Contacts — otherwise
    /// falls back to the default phone number the backend sent (usually
    /// the child's).
    private static func resolvePhoneNumber(_ command: Command) async -> String? {
        if let contactName = command.params["contactName"], !contactName.isEmpty {
            return AmmaContactsStore.shared.phoneNumber(forName: contactName)
        }
        guard let phoneNumber = command.params["phoneNumber"], !phoneNumber.isEmpty else { return nil }
        return phoneNumber
    }

    private static func sanitize(_ phoneNumber: String) -> String {
        phoneNumber.filter { $0.isNumber || $0 == "+" }
    }

    /// CommandExecutor isn't a View, so it reads the same
    /// "preferredCallMethod" key directly from UserDefaults rather than
    /// via @AppStorage — set from onboarding and Setup > Calling.
    private static var preferredCallMethod: PreferredCallMethod {
        let raw = UserDefaults.standard.string(forKey: "preferredCallMethod")
        return raw.flatMap(PreferredCallMethod.init) ?? .whatsapp
    }

    /// - Parameter remindToReturn: shows a "tap to come back" — a Live
    ///   Activity when the system allows it (persists in the Dynamic
    ///   Island / Lock Screen for as long as the parent is away), falling
    ///   back to a plain notification otherwise — but only once we know
    ///   the handoff actually happened (the completion handler's
    ///   `success`), never for a URL that silently failed to open.
    private static func open(_ url: URL?, remindToReturn: Bool = false) {
        guard let url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url) { success in
            guard success, remindToReturn else { return }
            Task { @MainActor in
                if !ReturnActivityService.start() {
                    ReturnReminderService.scheduleReturnReminder()
                }
            }
        }
    }
}
