import SwiftUI

struct VoiceSetupView: View {
    // Previously plain @State — reset to false on every relaunch even if
    // the family had genuinely granted consent on the backend already.
    // @AppStorage persists it, matching the same fix made on Android.
    @AppStorage("voiceConsentGranted") private var consentGiven = false
    // Which voice — preset or cloned — Amma currently replies with. Empty
    // means "server default", which is a preset the family never chose.
    @AppStorage("selectedVoiceId") private var selectedVoiceId = ""
    @State private var status = "Not started"
    @State private var isUploading = false
    @StateObject private var recorder = AudioRecorderService()

    @State private var presets: [VoicePreset] = []
    @State private var isLoadingPresets = false
    @State private var presetSelectionInFlight: String?

    private let familyId = FamilyContext.shared.familyId

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("About 30 seconds of your voice, reading anything out loud, lets Amma reply in your voice. Nothing is used without your consent below, and you can withdraw it later.")
                        .foregroundStyle(.secondary)

                    Toggle("I consent to my voice being used", isOn: $consentGiven)
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
                    .disabled(!consentGiven)

                    if let fileURL = recorder.recordedFileURL, !recorder.isRecording {
                        Button(isUploading ? "Uploading..." : "Upload sample") {
                            upload(fileURL: fileURL)
                        }
                        .disabled(isUploading)
                    }

                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("Haven't recorded your child's voice yet? Pick a default voice for Amma to use in the meantime — you can switch back any time.")
                        .foregroundStyle(.secondary)

                    if isLoadingPresets {
                        HStack {
                            ProgressView()
                            Text("Loading voices...")
                                .foregroundStyle(.secondary)
                        }
                    } else if presets.isEmpty {
                        Text("Couldn't load default voices — check your connection.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(presets) { preset in
                            Button {
                                selectPreset(preset)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.name)
                                            .foregroundStyle(.primary)
                                        Text(preset.description)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if presetSelectionInFlight == preset.voiceId {
                                        ProgressView()
                                    } else if selectedVoiceId == preset.voiceId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .disabled(presetSelectionInFlight != nil)
                        }
                    }
                } header: {
                    Text("Default voices")
                }
            }
            .navigationTitle("Voice")
            .task { await loadPresets() }
        }
    }

    private func loadPresets() async {
        isLoadingPresets = true
        defer { isLoadingPresets = false }
        presets = (try? await APIClient.shared.fetchVoicePresets()) ?? []
    }

    private func selectPreset(_ preset: VoicePreset) {
        presetSelectionInFlight = preset.voiceId
        Task {
            do {
                try await APIClient.shared.selectVoice(familyId: familyId, voiceId: preset.voiceId)
                await MainActor.run {
                    selectedVoiceId = preset.voiceId
                    presetSelectionInFlight = nil
                }
            } catch {
                await MainActor.run { presetSelectionInFlight = nil }
            }
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
                    selectedVoiceId = voiceId
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
