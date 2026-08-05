import SwiftUI
import UIKit

private enum TalkPhase {
    case idle
    case recording
    case transcribing
    case sending
}

struct TalkView: View {
    @AppStorage("childName") private var childName = ""
    @AppStorage("childPhotoPath") private var childPhotoPath = ""
    @State private var log: [InteractionLog] = []
    @State private var phase: TalkPhase = .idle
    @State private var statusMessage: String?
    @StateObject private var recorder = AudioRecorderService()
    @StateObject private var playback = AudioPlaybackService()
    #if targetEnvironment(simulator)
    @State private var debugTranscript = ""
    #endif

    private let familyId = FamilyContext.shared.familyId

    var body: some View {
        NavigationStack {
            VStack {
                if log.isEmpty {
                    Spacer()
                    Text("Tap the button and say something.\nAmma will reply.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(log) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.transcript)
                                .font(.subheadline)
                            if let reply = entry.responseText {
                                Text(reply)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }

                #if targetEnvironment(simulator)
                HStack {
                    TextField("Type a message (Simulator only — Speech doesn't work here)", text: $debugTranscript)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(sendDebugTranscript)
                    Button("Send", action: sendDebugTranscript)
                        .disabled(debugTranscript.isEmpty || phase == .transcribing || phase == .sending)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                #endif

                talkButton
                    .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        if !childPhotoPath.isEmpty, let image = UIImage(contentsOfFile: childPhotoPath) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        }
                        Text(childName.isEmpty ? "Amma" : childName)
                            .font(.headline)
                    }
                }
            }
        }
    }

    private var talkButton: some View {
        Button {
            handleTap()
        } label: {
            Image(systemName: phase == .recording ? "waveform" : "mic.fill")
                .font(.system(size: 32))
                .frame(width: 88, height: 88)
                .background(Circle().fill(phase == .recording ? .red : .pink))
                .foregroundStyle(.white)
        }
        .disabled(phase == .transcribing || phase == .sending)
    }

    private func handleTap() {
        switch phase {
        case .idle:
            startRecording()
        case .recording:
            stopRecordingAndSend()
        case .transcribing, .sending:
            break
        }
    }

    private func startRecording() {
        statusMessage = nil
        recorder.startRecording()
        phase = .recording
    }

    private func stopRecordingAndSend() {
        recorder.stopRecording()
        guard let fileURL = recorder.recordedFileURL else {
            phase = .idle
            return
        }
        phase = .transcribing
        Task {
            do {
                let transcript = try await APIClient.shared.transcribeAudio(fileURL: fileURL)
                await MainActor.run { phase = .sending }
                await send(transcript: transcript)
            } catch {
                print("[AmmaDebug] transcribeAudio failed: \(error)")
                await MainActor.run {
                    statusMessage = "Couldn't transcribe that — check your connection and try again."
                    phase = .idle
                }
            }
        }
    }

    #if targetEnvironment(simulator)
    private func sendDebugTranscript() {
        let transcript = debugTranscript
        guard !transcript.isEmpty else { return }
        debugTranscript = ""
        statusMessage = nil
        phase = .sending
        Task { await send(transcript: transcript) }
    }
    #endif

    private func send(transcript: String) async {
        do {
            let reply = try await APIClient.shared.sendInteraction(
                familyId: familyId,
                transcript: transcript,
                channel: .voice
            )
            await MainActor.run {
                log.append(InteractionLog(
                    id: UUID(),
                    familyId: familyId,
                    timestamp: Date(),
                    channel: .voice,
                    transcript: transcript,
                    intent: nil,
                    responseText: reply.replyText,
                    responseAudioURL: reply.replyAudioURL
                ))
                statusMessage = nil
                phase = .idle
            }
            if let audioURL = reply.replyAudioURL {
                await playback.play(url: audioURL)
            }
            if let action = reply.action {
                if let errorMessage = await CommandExecutor.execute(action) {
                    await MainActor.run { statusMessage = errorMessage }
                }
            }
        } catch {
            await MainActor.run {
                statusMessage = "Couldn't reach Amma — check your connection."
                phase = .idle
            }
        }
    }
}
