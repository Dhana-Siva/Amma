import SwiftUI
import UIKit

// Amma's custom Cast receiver, registered at cast.google.com/publish and
// hosted at https://dhana-siva.github.io/amma-cast-receiver/.
private let castReceiverApplicationID = "592BF965"

@main
struct AmmaApp: App {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    init() {
        CastService.configure(receiverApplicationID: castReceiverApplicationID)
    }

    var body: some Scene {
        WindowGroup {
            if !onboardingComplete {
                OnboardingView(onComplete: { onboardingComplete = true })
            } else if !hasSeenTutorial {
                TutorialView(onComplete: { hasSeenTutorial = true })
            } else {
                RootTabView()
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
                .tabItem { Label("Talk 💬", systemImage: "waveform") }

            VoiceSetupView()
                .tabItem { Label("Voice 🎤", systemImage: "waveform.badge.mic") }

            DevicesView()
                .tabItem { Label("Setup ⚙️", systemImage: "tv") }
        }
        // Voice conversations naturally have gaps where nothing is touching
        // the screen (listening to a reply, thinking of what to say next).
        // Without this, iOS's screen auto-lock backgrounds the app every
        // ~30-60s of inactivity, which suspends the Cast session each time —
        // confirmed live as the cause of casting silently going dead
        // mid-conversation (session disconnects with "Network not
        // reachable" after enough suspend/resume cycles).
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
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
