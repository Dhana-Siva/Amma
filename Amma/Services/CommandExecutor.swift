import UIKit

@MainActor
enum CommandExecutor {
    static func execute(_ command: Command) {
        switch command.intent {
        case .placeCall:
            guard let phoneNumber = command.params["phoneNumber"], !phoneNumber.isEmpty else { return }
            open(URL(string: "tel://\(sanitize(phoneNumber))"))

        case .sendMessage:
            guard let phoneNumber = command.params["phoneNumber"], !phoneNumber.isEmpty else { return }
            let text = command.params["text"] ?? ""
            let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            open(URL(string: "whatsapp://send?phone=\(sanitize(phoneNumber))&text=\(encodedText)"))

        case .castMedia:
            break
        }
    }

    private static func sanitize(_ phoneNumber: String) -> String {
        phoneNumber.filter { $0.isNumber || $0 == "+" }
    }

    private static func open(_ url: URL?) {
        guard let url, UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
