import UIKit

@MainActor
enum CommandExecutor {
    /// Executes the command, returning a user-facing message on failure
    /// (e.g. contact not found) or nil on success.
    @discardableResult
    static func execute(_ command: Command) async -> String? {
        switch command.intent {
        case .placeCall:
            guard let phoneNumber = await resolvePhoneNumber(command) else {
                return "Couldn't find that contact to call."
            }
            let sanitized = sanitize(phoneNumber)
            // WhatsApp has no documented URL scheme for starting a call (only
            // for opening a chat), so this undocumented one is best-effort —
            // fall back to a regular call if it's not available.
            if let whatsAppCallURL = URL(string: "whatsapp://calluser/?phone=\(sanitized)"),
               UIApplication.shared.canOpenURL(whatsAppCallURL) {
                open(whatsAppCallURL, remindToReturn: true)
            } else {
                open(URL(string: "tel://\(sanitized)"), remindToReturn: true)
            }
            return nil

        case .sendMessage:
            guard let phoneNumber = await resolvePhoneNumber(command) else {
                return "Couldn't find that contact to message."
            }
            let text = command.params["text"] ?? ""
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            open(URL(string: "whatsapp://send?phone=\(sanitize(phoneNumber))&text=\(encodedText)"), remindToReturn: true)
            return nil

        case .castMedia:
            CastService.logDiagnostic("[AmmaCast] CommandExecutor received castMedia, params=\(command.params)")
            guard let videoId = command.params["videoId"], !videoId.isEmpty else {
                return "Couldn't find that to play."
            }
            do {
                try CastService.shared.play(videoId: videoId)
                return nil
            } catch CastServiceError.notConnected {
                return "No TV linked yet — go to Setup to link one."
            } catch {
                return "Couldn't cast that to the TV right now."
            }

        case .stopCast:
            CastService.logDiagnostic("[AmmaCast] CommandExecutor received stopCast")
            do {
                try CastService.shared.stop()
                return nil
            } catch CastServiceError.notConnected {
                return "Nothing's linked to the TV right now."
            } catch {
                return "Couldn't stop the TV right now."
            }
        }
    }

    /// A named contact (looked up on-device) takes priority; otherwise falls
    /// back to the default phone number the backend sent (usually the child's).
    private static func resolvePhoneNumber(_ command: Command) async -> String? {
        if let contactName = command.params["contactName"], !contactName.isEmpty {
            return await ContactsService.shared.phoneNumber(forName: contactName)
        }
        guard let phoneNumber = command.params["phoneNumber"], !phoneNumber.isEmpty else { return nil }
        return phoneNumber
    }

    private static func sanitize(_ phoneNumber: String) -> String {
        phoneNumber.filter { $0.isNumber || $0 == "+" }
    }

    /// - Parameter remindToReturn: schedules a "tap to come back" local
    ///   notification, but only once we know the handoff actually
    ///   happened (the completion handler's `success`) — never fires for
    ///   a URL that silently failed to open.
    private static func open(_ url: URL?, remindToReturn: Bool = false) {
        guard let url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url) { success in
            if success && remindToReturn {
                ReturnReminderService.scheduleReturnReminder()
            }
        }
    }
}
