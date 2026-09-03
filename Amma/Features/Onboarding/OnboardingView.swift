import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var storedParentName = ""
    @AppStorage("childName") private var storedChildName = ""
    @AppStorage("childPhoneNumber") private var storedChildPhoneNumber = ""
    @AppStorage("preferredCallMethod") private var preferredCallMethod = PreferredCallMethod.whatsapp

    @State private var step = 0
    @State private var parentName = ""
    @State private var childName = ""
    @State private var language = "en"
    @State private var childPhoneNumber = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            switch step {
            case 0:
                welcomeStep
            case 1:
                namesStep
            case 2:
                aiDisclosureStep
            case 3:
                consentStep
            case 4:
                contactsStep
            default:
                callMethodStep
            }

            Spacer()

            Button(step < 5 ? (step == 2 ? "I Understand, Continue" : "Continue") : "Get started") {
                // Apple rejected an earlier build under Guideline 5.1.1 for
                // a dedicated "Allow Contacts access" button here — its
                // wording echoed the system dialog's own language closely
                // enough to read as steering the user toward granting,
                // rather than presenting a neutral choice. Fix: no custom
                // button asks for anything — the system's own neutral
                // Allow/Don't Allow prompt fires as a side effect of the
                // ordinary "Continue" tap, after contactsStep has already
                // explained why (which Apple's own guidance says is fine).
                if step == 4 {
                    Task { await ContactsService.shared.requestAccessIfNeeded() }
                }
                if step < 5 {
                    step += 1
                } else {
                    finish()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(step == 1 && (parentName.isEmpty || childName.isEmpty))
        }
        .padding()
    }

    private var welcomeStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.pink)
            Text("Welcome to Amma")
                .font(.title.bold())
            Text("A way to feel closer to family, every day.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var namesStep: some View {
        VStack(spacing: 16) {
            Text("Let's set up your family")
                .font(.title2.bold())
            TextField("Your name", text: $parentName)
                .textFieldStyle(.roundedBorder)
            TextField("Your child's name", text: $childName)
                .textFieldStyle(.roundedBorder)
            TextField("Child's phone number (optional)", text: $childPhoneNumber)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)

            Text("Which language should Amma speak?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Picker("Language", selection: $language) {
                Text("தமிழ்").tag("ta")
                Text("English").tag("en")
            }
            .pickerStyle(.segmented)
        }
    }

    // Added after an Apple App Review rejection: the app sends the
    // parent's spoken transcript to Anthropic (to generate Amma's reply)
    // and their audio to ElevenLabs (to transcribe it, and to speak the
    // reply back) on every single Talk exchange — core functionality,
    // not optional. Apple's guidance was explicit that a privacy-policy
    // mention alone isn't sufficient; this needs its own in-app
    // disclosure naming the specific third parties and what's sent to
    // each, with an affirmative action (not just passive text) before
    // any of it can happen — hence "I Understand, Continue" rather than
    // a plain "Continue" specifically on this step. This is separate
    // from consentStep below, which is about the optional voice-cloning
    // feature specifically, not this baseline data flow every message
    // goes through regardless.
    private var aiDisclosureStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("How Amma Works")
                .font(.title2.bold())
            Text("Every time you tap and talk, what you say is sent to Anthropic (the company behind Claude, the AI that writes Amma's replies) and to ElevenLabs (which turns your speech into text, and text into Amma's spoken voice). That's how Amma understands you and replies — it happens on every message, not just some.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("See our Privacy Policy for full details on what's shared, with whom, and why.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var consentStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Before we start")
                .font(.title2.bold())
            Text("\(childName.isEmpty ? "Your child" : childName) will be asked separately to record voice samples and approve how their voice is used. Nothing is cloned without their consent, and it can be withdrawn at any time.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var contactsStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Calling family by name")
                .font(.title2.bold())
            Text("Amma can look up a number from your Contacts, so you can just say a name — like \"call Geetha\" — instead of a number. Numbers never leave your phone; only the name you say is sent anywhere.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Continuing will ask for Contacts access — you can decline it, or change it later from Setup.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var callMethodStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "phone.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("How should Amma call?")
                .font(.title2.bold())
            Text("When you say \"call\" without naming an app, which one should Amma use?")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Picker("Preferred call method", selection: $preferredCallMethod) {
                ForEach(PreferredCallMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.segmented)
            Text("You can change this later too, from Setup.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func finish() {
        let familyId = FamilyContext.shared.familyId
        storedLanguage = language
        storedParentName = parentName
        storedChildName = childName
        let trimmedPhoneNumber = childPhoneNumber.trimmingCharacters(in: .whitespaces)
        storedChildPhoneNumber = trimmedPhoneNumber
        Task {
            try? await APIClient.shared.setupFamily(
                familyId: familyId,
                parentName: parentName,
                childName: childName,
                language: language,
                childPhoneNumber: trimmedPhoneNumber.isEmpty ? nil : trimmedPhoneNumber
            )
        }
        onComplete()
    }
}
