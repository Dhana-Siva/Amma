import SwiftUI
import ContactsUI

/// Wraps Apple's own contact picker (ContactsUI, not Amma's flat list) —
/// the full native browse/search UI for picking someone already in the
/// phone's Contacts, the same system screen used elsewhere on iOS. No
/// separate "save" step needed afterward: once Contacts access is
/// granted at all, Amma can already look up anyone in the phonebook by
/// name — this just gives a direct, familiar "add from phonebook" action
/// to point at, rather than relying on the parent finding their own way
/// to the phone's Contacts app.
struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (CNContact) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Hide contacts with no number at all — nothing Amma could call.
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (CNContact) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (CNContact) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }
}
