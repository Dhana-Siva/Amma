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
    var body: some View {
        TabView {
            TalkView()
                .tabItem { Label("Talk", systemImage: "waveform") }

            VoiceSetupView()
                .tabItem { Label("Voice", systemImage: "waveform.badge.mic") }

            DevicesView()
                .tabItem { Label("Devices", systemImage: "tv") }
        }
    }
}
