import SwiftUI

struct DevicesView: View {
    @State private var devices: [PairedDevice] = [
        PairedDevice(id: UUID(), familyId: UUID(), type: .appleTV, name: "Living room TV", pairedAt: nil)
    ]
    @State private var integrations: [Integration] = [
        Integration(id: UUID(), familyId: UUID(), type: .phone, status: .notConnected),
        Integration(id: UUID(), familyId: UUID(), type: .whatsapp, status: .notConnected)
    ]

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
                    ForEach(integrations) { integration in
                        HStack {
                            Label(integration.type.rawValue.capitalized, systemImage: icon(for: integration.type))
                            Spacer()
                            Text(integration.status == .connected ? "Connected" : "Not connected")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Devices")
        }
    }

    private func icon(for type: IntegrationType) -> String {
        switch type {
        case .whatsapp: return "message.fill"
        case .phone: return "phone.fill"
        case .cast: return "tv"
        }
    }
}
