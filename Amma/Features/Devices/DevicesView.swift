import SwiftUI

struct DevicesView: View {
    @State private var devices: [PairedDevice] = [
        PairedDevice(id: UUID(), familyId: UUID(), type: .appleTV, name: "Living room TV", pairedAt: nil)
    ]

    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var storedParentName = ""
    @AppStorage("childName") private var storedChildName = ""
    @AppStorage("childPhoneNumber") private var storedChildPhoneNumber = ""

    @State private var phoneInput = ""
    @State private var isSaving = false
    @State private var status: String?

    private var isConnected: Bool { !storedChildPhoneNumber.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section("Cast devices") {
                    ForEach(devices) { device in
                        HStack {
                            Label(device.name, systemImage: "tv")
                            Spacer()
                            Text(device.pairedAt == nil ? "Not paired" : "Paired")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Calling") {
                    HStack {
                        Label("WhatsApp", systemImage: "message.fill")
                        Spacer()
                        Text(isConnected ? "Connected" : "Not connected")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Phone", systemImage: "phone.fill")
                        Spacer()
                        Text(isConnected ? "Connected" : "Not connected")
                            .foregroundStyle(.secondary)
                    }

                    TextField("Child's phone number", text: $phoneInput)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    Button(isSaving ? "Saving..." : "Save number") {
                        save()
                    }
                    .disabled(isSaving || phoneInput.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let status {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Devices")
            .onAppear { phoneInput = storedChildPhoneNumber }
        }
    }

    private func save() {
        let trimmed = phoneInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        status = nil
        Task {
            do {
                try await APIClient.shared.setupFamily(
                    familyId: FamilyContext.shared.familyId,
                    parentName: storedParentName,
                    childName: storedChildName,
                    language: storedLanguage,
                    childPhoneNumber: trimmed
                )
                await MainActor.run {
                    storedChildPhoneNumber = trimmed
                    status = "Saved. Amma can now call or WhatsApp on your behalf."
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    status = "Couldn't save — check your connection and try again."
                    isSaving = false
                }
            }
        }
    }
}
