import SwiftUI

private enum TalkPhase {
    case idle
    case recording
    case transcribing
    case sending
}

struct TalkView: View {
    @AppStorage("parentName") private var parentName = ""
    @AppStorage("childName") private var childName = ""
    @State private var log: [InteractionLog] = []
    @State private var phase: TalkPhase = .idle
    @State private var statusMessage: String?
    @StateObject private var recorder = AudioRecorderService()
    @StateObject private var playback = AudioPlaybackService()
    @ObservedObject private var health = HealthService.shared
    @ObservedObject private var castService = CastService.shared
    #if targetEnvironment(simulator)
    @State private var debugTranscript = ""
    #endif
    @State private var welcomeAppeared = false

    private let familyId = FamilyContext.shared.familyId

    var body: some View {
        NavigationStack {
            VStack {
                if log.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        HomeScreenPictureView(size: 140)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 5))
                            .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
                            .scaleEffect(welcomeAppeared ? 1 : 0.7)
                            .opacity(welcomeAppeared ? 1 : 0)

                        Text(greeting)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .opacity(welcomeAppeared ? 1 : 0)
                            .offset(y: welcomeAppeared ? 0 : 8)

                        Text("Tap the button and say something.\nAmma will reply.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .opacity(welcomeAppeared ? 1 : 0)
                    }
                    .padding(.horizontal, 32)
                    Spacer()
                } else {
                    VStack(spacing: 8) {
                        HomeScreenPictureView(size: 64)
                            .padding(.top, 12)

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
            .background {
                if log.isEmpty {
                    LinearGradient(
                        colors: [greetingAccentColor.opacity(0.22), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .ignoresSafeArea()
                }
            }
            .onAppear {
                guard log.isEmpty, !welcomeAppeared else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.05)) {
                    welcomeAppeared = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        AvatarView(size: 32)
                        Text(childName.isEmpty ? "Amma" : childName)
                            .font(.headline)
                    }
                }
            }
            .task {
                // Best-effort — only refreshes if the parent already granted
                // Health access from the Setup tab; never prompts from here.
                if health.hasRequestedAccess { await health.refresh() }
            }
        }
    }

    // A time-of-day greeting with the parent's name and a matching emoji —
    // shown on the empty Talk screen, i.e. exactly the moment the app
    // opens (or a fresh tab, after backgrounding). Purely a warm first
    // impression; carries no data, so no localization plumbing needed
    // beyond the two greeting words themselves reading naturally in
    // either language selected on the Setup tab.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let (text, emoji): (String, String)
        switch hour {
        case 5..<12: (text, emoji) = ("Good morning", "☀️")
        case 12..<17: (text, emoji) = ("Good afternoon", "🌤️")
        case 17..<21: (text, emoji) = ("Good evening", "🌆")
        default: (text, emoji) = ("Hello", "🌙")
        }
        let name = parentName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "\(text)! \(emoji)" : "\(text), \(name)! \(emoji)"
    }

    // A soft accent tint for the welcome screen's background gradient and
    // picture shadow, shifting with the same time-of-day boundaries as the
    // greeting so the whole screen reads as one cohesive moment rather
    // than a plain white page with text on it.
    private var greetingAccentColor: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .orange
        case 12..<17: return .blue
        case 17..<21: return .pink
        default: return .indigo
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
                channel: .voice,
                heartRate: health.latestBPM,
                castLinked: castService.isConnected
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
