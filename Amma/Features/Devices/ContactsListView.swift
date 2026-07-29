import SwiftUI

struct ContactsListView: View {
    @State private var contacts: [ContactSummary] = []
    @State private var isLoading = true
    @State private var searchText = ""

    private var filtered: [ContactSummary] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading contacts…")
            } else if contacts.isEmpty {
                Text("No contacts found, or access wasn't granted.\nCheck Settings > Privacy > Contacts > Amma.")
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
        .navigationTitle("Contacts")
        .task {
            contacts = await ContactsService.shared.allContacts()
            isLoading = false
        }
    }
}
