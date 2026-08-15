import SwiftUI
import UIKit

/// @AppStorage has no native Color support, so the Talk border color
/// (picked via a full ColorPicker in Setup) is persisted as a plain
/// "RRGGBB" hex string instead.
extension Color {
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let rgb = UInt32(sanitized, radix: 16) else { return nil }
        self = Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    var hexString: String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        return String(
            format: "%02X%02X%02X",
            Int((components[0] * 255).rounded()),
            Int((components[1] * 255).rounded()),
            Int((components[2] * 255).rounded())
        )
    }
}
