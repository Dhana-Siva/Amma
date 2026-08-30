import Contacts
import SwiftUI

/// Shows Amma's own curated contact list (see AmmaContactsStore) — not
/// the phone's full Contacts, which was the earlier (wrong) approach:
/// mirroring the whole phonebook meant "adding" a contact never visibly
/// changed anything, since everyone was already shown.
struct ContactsListView: View {
    @ObservedObject private var store = AmmaContactsStore.shared
    @State private var searchText = ""
    @State private var isAddingContact = false
    @State private var isPickingFromPhonebook = false
    @State private var confirmationMessage: String?

    private var filtered: [AmmaContact] {
        guard !searchText.isEmpty else { return store.contacts }
        return store.contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if store.contacts.isEmpty {
                Text("No contacts added yet.\nTap + to add someone Amma can call or message by name.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(filtered) { contact in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                            Text(contact.phoneNumber)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { store.remove(filtered[index]) }
                    }
                }
                .searchable(text: $searchText, prompt: "Search contacts")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let confirmationMessage {
                Text(confirmationMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Amma's Contacts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Primary path: pick someone already in the phone's
                    // own Contacts, via Apple's native picker.
                    Button {
                        isPickingFromPhonebook = true
                    } label: {
                        Label("Choose from Contacts", systemImage: "person.crop.circle")
                    }
                    Button {
                        isAddingContact = true
                    } label: {
                        Label("Create New Contact", systemImage: "person.crop.circle.badge.plus")
                    }
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
            }
        }
        .sheet(isPresented: $isAddingContact) {
            // AddContactView already saves to the phone's real Contacts
            // (so it also shows up in the system Contacts app) and to
            // AmmaContactsStore — this view just needs to be around to
            // present the sheet; the list updates itself via @ObservedObject.
            AddContactView(onSaved: {})
        }
        .fullScreenCover(isPresented: $isPickingFromPhonebook) {
            ContactPicker(
                onPick: { contact in
                    isPickingFromPhonebook = false
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    let displayName = name.isEmpty ? "That contact" : name
                    // A contact with no phone number at all can still slip
                    // through the picker's own "enabled" filtering on some
                    // iOS versions — check for real here rather than
                    // showing a false-positive success.
                    guard let phoneNumber = contact.phoneNumbers.first?.value.stringValue else {
                        confirmationMessage = "\(displayName) doesn't have a phone number saved, so Amma can't call or message them."
                        return
                    }
                    store.add(name: displayName, phoneNumber: phoneNumber)
                    showConfirmation(for: displayName)
                },
                onCancel: { isPickingFromPhonebook = false }
            )
            .ignoresSafeArea()
        }
    }

    private func showConfirmation(for name: String) {
        confirmationMessage = "\(name) added — Amma can now call or message them by name."
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if confirmationMessage != nil { confirmationMessage = nil }
        }
    }
}
