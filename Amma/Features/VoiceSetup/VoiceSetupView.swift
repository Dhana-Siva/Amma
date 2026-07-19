import SwiftUI

struct VoiceSetupView: View {
    @State private var consentGiven = false
    @State private var status = "Not started"
    @State private var isUploading = false
    @StateObject private var recorder = AudioRecorderService()

    private let familyId = FamilyContext.shared.familyId

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("About 30 seconds of your voice, reading anything out loud, lets Amma reply in your voice. Nothing is used without your consent below, and you can withdraw it later.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Toggle("I consent to my voice being used", isOn: $consentGiven)
                    .padding(.horizontal)
                    .onChange(of: consentGiven) { _, newValue in
                        Task { try? await APIClient.shared.setVoiceConsent(familyId: familyId, granted: newValue) }
                    }

                Button(recorder.isRecording ? "Stop recording (\(recorder.elapsedSeconds)s)" : "Record voice sample") {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        recorder.startRecording()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!consentGiven)

                if let fileURL = recorder.recordedFileURL, !recorder.isRecording {
                    Button(isUploading ? "Uploading..." : "Upload sample") {
                        upload(fileURL: fileURL)
                    }
                    .disabled(isUploading)
                }

                Text(status)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Voice")
        }
    }

    private func upload(fileURL: URL) {
        isUploading = true
        status = "Uploading..."
        Task {
            do {
                let voiceId = try await APIClient.shared.uploadVoiceSample(familyId: familyId, audioFileURL: fileURL)
                await MainActor.run {
                    status = "Voice ready (\(voiceId))"
                    isUploading = false
                }
            } catch {
                await MainActor.run {
                    status = "Upload failed — try again"
                    isUploading = false
                }
            }
        }
    }
}
