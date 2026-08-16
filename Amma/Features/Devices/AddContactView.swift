import SwiftUI

/// A small name + phone number form that saves straight to the device's
/// Contacts, so a parent can add a family member from inside Amma
/// instead of switching to the separate Contacts app.
struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSaved: () -> Void

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await ContactsService.shared.addContact(name: name, phoneNumber: phoneNumber)
                await MainActor.run {
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't save — check Contacts access in Setup."
                    isSaving = false
                }
            }
        }
    }
}
