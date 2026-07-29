import SwiftUI

struct DevicesView: View {
    @ObservedObject private var castService = CastService.shared

    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var storedParentName = ""
    @AppStorage("childName") private var storedChildName = ""
    @AppStorage("childPhoneNumber") private var storedChildPhoneNumber = ""

    @State private var phoneInput = ""
    @State private var isSaving = false
    @State private var status: String?
    @State private var languageStatus: String?
    @FocusState private var isPhoneFieldFocused: Bool

    private var isConnected: Bool { !storedChildPhoneNumber.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section("Language") {
                    Picker("Language", selection: $storedLanguage) {
                        Text("தமிழ்").tag("ta")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: storedLanguage) { _, newValue in
                        Task {
                            do {
                                try await APIClient.shared.setupFamily(
                                    familyId: FamilyContext.shared.familyId,
                                    parentName: storedParentName,
                                    childName: storedChildName,
                                    language: newValue,
                                    childPhoneNumber: storedChildPhoneNumber.isEmpty ? nil : storedChildPhoneNumber
                                )
                                await MainActor.run { languageStatus = "Saved." }
                            } catch {
                                await MainActor.run { languageStatus = "Couldn't save: \(error.localizedDescription)" }
                            }
                        }
                    }
                    if let languageStatus {
                        Text(languageStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Cast devices") {
                    if castService.isConnected {
                        HStack {
                            Label(castService.connectedDeviceName ?? "TV", systemImage: "tv")
                            Spacer()
                            Text("Connected").foregroundStyle(.secondary)
                        }
                        Button("Disconnect", role: .destructive) {
                            castService.disconnect()
                        }
                    } else if castService.discoveredDevices.isEmpty {
                        Text("Looking for a Chromecast on your network...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(castService.discoveredDevices, id: \.uniqueID) { device in
                            Button {
                                castService.connect(to: device)
                            } label: {
                                HStack {
                                    Label(device.friendlyName ?? "TV", systemImage: "tv")
                                    Spacer()
                                    Text("Connect").foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
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
                        .focused($isPhoneFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { isPhoneFieldFocused = false }

                    Button(isSaving ? "Saving..." : "Save number") {
                        save()
                    }
                    .disabled(isSaving || phoneInput.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let status {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink("View phone contacts") {
                        ContactsListView()
                    }
                }
            }
            .navigationTitle("Devices")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isPhoneFieldFocused = false }
                }
            }
            .onAppear {
                phoneInput = storedChildPhoneNumber
                if !castService.isConnected { castService.startDiscovery() }
            }
            .onDisappear { castService.stopDiscovery() }
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
