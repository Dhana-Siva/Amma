import Contacts
import SwiftUI

struct DevicesView: View {
    @ObservedObject private var castService = CastService.shared
    @ObservedObject private var healthService = HealthService.shared

    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var storedParentName = ""
    @AppStorage("childName") private var storedChildName = ""
    @AppStorage("childPhoneNumber") private var storedChildPhoneNumber = ""
    @AppStorage("workspaceBorderEnabled") private var workspaceBorderEnabled = false
    @AppStorage("workspaceBorderColorHex") private var workspaceBorderColorHex = "FF2D78"
    @AppStorage("messageStyleColorful") private var messageStyleColorful = true

    @State private var languageStatus: String?
    @State private var contactsStatus = ContactsService.shared.authorizationStatus

    private var isConnected: Bool { !storedChildPhoneNumber.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Edit profile", systemImage: "person.crop.circle")
                    }
                }

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

                Section("Vitals") {
                    if !healthService.isAvailable {
                        Text("Not available on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if !healthService.hasRequestedAccess {
                        Button("Connect Apple Watch") {
                            Task { await healthService.requestAuthorization() }
                        }
                        Text("Lets Amma see your heart rate from a paired Apple Watch, so it can gently check in when it seems elevated.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Label("Heart rate", systemImage: "heart.fill")
                                .foregroundStyle(.red)
                            Spacer()
                            if let bpm = healthService.latestBPM {
                                Text("\(bpm) bpm")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No reading yet")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("Refresh") {
                            Task { await healthService.refresh() }
                        }
                    }
                }

                Section {
                    Toggle("Show border", isOn: $workspaceBorderEnabled)
                    ColorPicker(
                        "Border color",
                        selection: Binding(
                            get: { Color(hex: workspaceBorderColorHex) ?? .pink },
                            set: { workspaceBorderColorHex = $0.hexString ?? workspaceBorderColorHex }
                        )
                    )
                    .disabled(!workspaceBorderEnabled)
                } header: {
                    Text("Talk border")
                } footer: {
                    Text("Adds a colored frame around the Talk screen.")
                }

                Section {
                    Picker("Message style", selection: $messageStyleColorful) {
                        Text("Colorful").tag(true)
                        Text("Plain").tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Message style")
                } footer: {
                    Text("Colorful uses pink and accent colors for the chat bubbles; Plain uses neutral gray.")
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
                }

                Section {
                    switch contactsStatus {
                    case .authorized, .limited:
                        HStack {
                            Label("Contacts access", systemImage: "person.crop.circle.badge.checkmark")
                            Spacer()
                            Text("On").foregroundStyle(.secondary)
                        }
                    case .denied, .restricted:
                        Button("Turn on in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Text("Amma can still call or message using the child's saved number, but can't look up anyone else by name until this is turned back on.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    default:
                        Button("Allow Contacts access") {
                            Task {
                                await ContactsService.shared.requestAccessIfNeeded()
                                await MainActor.run { contactsStatus = ContactsService.shared.authorizationStatus }
                            }
                        }
                        Text("Lets Amma look up a number when you say a name, like \"call Geetha\", instead of a saved number only.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink("View phone contacts") {
                        ContactsListView()
                    }
                } header: {
                    Text("Contacts")
                }
            }
            .navigationTitle("Setup")
            .onAppear {
                if !castService.isConnected { castService.startDiscovery() }
                // Re-read in case the parent granted/revoked access in the
                // Settings app and came back — not observable, so a plain
                // re-read on every appearance is the only way to catch it.
                contactsStatus = ContactsService.shared.authorizationStatus
            }
            .onDisappear { castService.stopDiscovery() }
            .task {
                if healthService.hasRequestedAccess { await healthService.refresh() }
            }
        }
    }
}
