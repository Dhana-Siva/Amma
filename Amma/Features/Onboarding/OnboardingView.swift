import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @AppStorage("languageCode") private var storedLanguage = "en"
    @AppStorage("parentName") private var storedParentName = ""
    @AppStorage("childName") private var storedChildName = ""
    @AppStorage("childPhoneNumber") private var storedChildPhoneNumber = ""

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
            default:
                consentStep
            }

            Spacer()

            Button(step < 2 ? "Continue" : "Get started") {
                if step < 2 {
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
