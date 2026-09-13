import SwiftUI

/// The "what we send, and to whom" content shown for the Talk feature's
/// data sharing. Factored out of OnboardingView so the exact same
/// disclosure can also be shown as a standalone gate (see
/// AIDisclosureGateView below) — necessary because `onboardingComplete`
/// persists forever via @AppStorage, so anyone who finished onboarding on
/// a build from before this screen existed would otherwise never see it,
/// having skipped straight past onboarding entirely on every build since.
struct AIDisclosureContent: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("How Amma Works")
                .font(.title2.bold())
            Text("Every time you tap and talk, what you say is sent to Anthropic (the company behind Claude, the AI that writes Amma's replies) and to ElevenLabs (which turns your speech into text, and text into Amma's spoken voice). That's how Amma understands you and replies — it happens on every message, not just some.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Link("See our Privacy Policy for full details on what's shared, with whom, and why.", destination: URL(string: "https://dhana-siva.github.io/Amma/")!)
                .font(.footnote)
        }
    }
}

/// Shown once, before RootTabView, to anyone whose device has
/// `onboardingComplete = true` but hasn't acknowledged this specific
/// disclosure yet — i.e. existing users upgrading from a build that
/// predates it, and (this is the part that actually matters for App
/// Review) any device already past onboarding when this screen was
/// added. Same copy and action as onboarding's own step, just reachable
/// independently of whether onboarding itself already ran.
struct AIDisclosureGateView: View {
    let onAcknowledge: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            AIDisclosureContent()
            Spacer()
            Button("I Understand, Continue", action: onAcknowledge)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
