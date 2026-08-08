import SwiftUI

struct DevicesView: View {
    @ObservedObject private var castService = CastService.shared
    @ObservedObject private var healthService = HealthService.shared

    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var storedParentName = ""
    @AppStorage("childName") private var storedChildName = ""
    @AppStorage("childPhoneNumber") private var storedChildPhoneNumber = ""

    @State private var languageStatus: String?

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
                    } else if !healthService.isAuthorized {
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

                    NavigationLink("View phone contacts") {
                        ContactsListView()
                    }
                }
            }
            .navigationTitle("Setup")
            .onAppear {
                if !castService.isConnected { castService.startDiscovery() }
            }
            .onDisappear { castService.stopDiscovery() }
        }
    }
}
