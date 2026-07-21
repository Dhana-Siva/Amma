import SwiftUI

@main
struct AmmaApp: App {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                RootTabView()
            } else {
                OnboardingView(onComplete: { onboardingComplete = true })
            }
        }
    }
}

struct RootTabView: View {
    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var storedParentName = ""
    @AppStorage("childName") private var storedChildName = ""
    @AppStorage("childPhoneNumber") private var storedChildPhoneNumber = ""

    var body: some View {
        TabView {
            TalkView()
                .tabItem { Label("Talk", systemImage: "waveform") }

            VoiceSetupView()
                .tabItem { Label("Voice", systemImage: "waveform.badge.mic") }

            DevicesView()
                .tabItem { Label("Devices", systemImage: "tv") }
        }
        .task {
            // Backend family state is in-memory only, so re-send what onboarding
            // already collected in case the server restarted since last launch.
            guard !storedParentName.isEmpty, !storedChildName.isEmpty else { return }
            try? await APIClient.shared.setupFamily(
                familyId: FamilyContext.shared.familyId,
                parentName: storedParentName,
                childName: storedChildName,
                language: storedLanguage,
                childPhoneNumber: storedChildPhoneNumber.isEmpty ? nil : storedChildPhoneNumber
            )
        }
    }
}
