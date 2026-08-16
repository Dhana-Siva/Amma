import SwiftUI

struct ContactsListView: View {
    @State private var contacts: [ContactSummary] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var isAddingContact = false
    @State private var isPickingFromPhonebook = false
    @State private var confirmationMessage: String?

    private var filtered: [ContactSummary] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading contacts…")
            } else if contacts.isEmpty {
                Text("No contacts found, or access wasn't granted.\nCheck Settings > Privacy > Contacts > Amma, or tap + to add one.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(filtered) { contact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                        ForEach(contact.phoneNumbers, id: \.self) { number in
                            Text(number)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Primary ask: pick someone already in the phone's
                    // own Contacts, via Apple's native picker — not a
                    // typed form.
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
            AddContactView(onSaved: { Task { await reload() } })
        }
        .fullScreenCover(isPresented: $isPickingFromPhonebook) {
            ContactPicker(
                onPick: { contact in
                    isPickingFromPhonebook = false
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    showConfirmation(for: name.isEmpty ? "That contact" : name)
                    Task { await reload() }
                },
                onCancel: { isPickingFromPhonebook = false }
            )
            .ignoresSafeArea()
        }
        .task {
            await reload()
        }
    }

    private func reload() async {
        contacts = await ContactsService.shared.allContacts()
        isLoading = false
    }

    private func showConfirmation(for name: String) {
        confirmationMessage = "\(name) can now be called or messaged by name."
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if confirmationMessage != nil { confirmationMessage = nil }
            }
        }
    }
}
