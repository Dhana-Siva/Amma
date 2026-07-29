import SwiftUI

/// One-time walkthrough shown right after onboarding, before the parent
/// ever sees the tab bar. Written for a low-navigation user (see project
/// notes): short, plain-language cards rather than anything they'd need to
/// read carefully or navigate back through.
struct TutorialView: View {
    let onComplete: () -> Void

    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("childName") private var storedChildName = ""

    @State private var step = 0

    private var childName: String {
        storedChildName.isEmpty ? (storedLanguage == "ta" ? "அவங்க" : "them") : storedChildName
    }

    private var isTamil: Bool { storedLanguage == "ta" }

    private var pages: [(icon: String, title: String, body: String)] {
        if isTamil {
            return [
                (
                    "waveform",
                    "மைக்கை தட்டி பேசுங்கள்",
                    "தட்டி பேசுங்க — \(childName) பதில் சொல்லுவாங்க, அவங்களோட குரலில்."
                ),
                (
                    "waveform.badge.mic",
                    "அவங்களோட குரலிலேயே",
                    "அம்மா பதில் சொல்லும்போது கேட்பது \(childName)யோட பதிவு செஞ்ச குரல்தான் — எப்போ வேணும்னாலும் அவங்க சொன்ன மாதிரி."
                ),
                (
                    "tv",
                    "கேளுங்க, அம்மா பார்த்துக்குவாங்க",
                    "போன் பண்ணச் சொல்லு, மெசேஜ் அனுப்பச் சொல்லு, டிவியில ஏதாவது ஓட்டச் சொல்லு — மீதி எல்லாம் அம்மா பார்த்துக்குவாங்க."
                ),
            ]
        } else {
            return [
                (
                    "waveform",
                    "Tap the microphone to talk",
                    "Just tap and speak — \(childName) will reply, in their own voice."
                ),
                (
                    "waveform.badge.mic",
                    "Their voice, always",
                    "When Amma replies, what you're hearing is \(childName)'s own recorded voice — like a message from them, anytime."
                ),
                (
                    "tv",
                    "Just ask, Amma handles it",
                    "Ask to call, send a message, or play something on the TV — Amma takes care of the rest."
                ),
            ]
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            let page = pages[step]
            VStack(spacing: 12) {
                Image(systemName: page.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(.pink)
                Text(page.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.pink : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Button(step < pages.count - 1 ? (isTamil ? "அடுத்து" : "Next") : (isTamil ? "சரி" : "Got it")) {
                if step < pages.count - 1 {
                    step += 1
                } else {
                    onComplete()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
