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

/// Which tab opens by default when the app launches, chosen from Setup >
/// Home page. Distinct from "last tab used" — switching tabs during a
/// session doesn't change this, only the picker in Setup does.
enum HomeTab: String, CaseIterable, Identifiable {
    case talk, voice, setup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .talk: "Talk"
        case .voice: "Voice"
        case .setup: "Setup"
        }
    }

    var systemImage: String {
        switch self {
        case .talk: "waveform"
        case .voice: "waveform.badge.mic"
        case .setup: "tv"
        }
    }
}

struct RootTabView: View {
    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var storedParentName = ""
    @AppStorage("childName") private var storedChildName = ""
    @AppStorage("childPhoneNumber") private var storedChildPhoneNumber = ""
    @AppStorage("homeTab") private var homeTabRaw = HomeTab.talk.rawValue

    // Only seeded from the Setup > Home page preference at launch — after
    // that it's a normal tab selection, so tapping around the app doesn't
    // silently change what "home" means.
    @State private var selectedTab: HomeTab

    init() {
        let stored = UserDefaults.standard.string(forKey: "homeTab").flatMap(HomeTab.init) ?? .talk
        _selectedTab = State(initialValue: stored)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TalkView()
                .tabItem { Label(HomeTab.talk.title, systemImage: HomeTab.talk.systemImage) }
                .tag(HomeTab.talk)

            VoiceSetupView()
                .tabItem { Label(HomeTab.voice.title, systemImage: HomeTab.voice.systemImage) }
                .tag(HomeTab.voice)

            DevicesView()
                .tabItem { Label(HomeTab.setup.title, systemImage: HomeTab.setup.systemImage) }
                .tag(HomeTab.setup)
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
