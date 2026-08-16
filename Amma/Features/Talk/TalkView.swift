import SwiftUI

private enum TalkPhase {
    case idle
    case recording
    case transcribing
    case sending
}

struct TalkView: View {
    @AppStorage("parentName") private var parentName = ""
    @AppStorage("parentRelation") private var parentRelation = ""
    @AppStorage("workspaceBorderEnabled") private var workspaceBorderEnabled = false
    @AppStorage("workspaceBorderColorHex") private var workspaceBorderColorHex = "FF2D78"
    @AppStorage("messageStyleColorful") private var messageStyleColorful = true
    @State private var log: [InteractionLog] = []
    @State private var showClearConfirmation = false
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
    // A brief emoji "reaction" pops onto the newest reply bubble when it
    // arrives, then fades — see conversationBubbles and send() below.
    @State private var reactionEmoji = "✨"
    @State private var showReaction = false

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

                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(log) { entry in
                                        conversationBubbles(for: entry)
                                            .id(entry.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .onChange(of: log.count) { _, _ in
                                guard let lastID = log.last?.id else { return }
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scrollProxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
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
            .overlay {
                if workspaceBorderEnabled, let borderColor = Color(hex: workspaceBorderColorHex) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(borderColor, lineWidth: 3)
                        .padding(6)
                }
            }
            .onAppear {
                guard log.isEmpty, !welcomeAppeared else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.05)) {
                    welcomeAppeared = true
                }
            }
            .toolbar {
                if !log.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear this conversation?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear messages", role: .destructive) {
                    withAnimation { log.removeAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This only clears what's shown here — it doesn't affect anything already sent.")
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
        // Prefer how the child actually addresses the parent (Amma, Mom,
        // Appa, ...) set in Edit Profile — reads far more like the child
        // themselves greeting them than a first name would. Falls back to
        // the parent's name, then to nothing, if relation isn't set.
        let relation = parentRelation.trimmingCharacters(in: .whitespaces)
        let name = parentName.trimmingCharacters(in: .whitespaces)
        let addressee = relation.isEmpty ? name : relation
        return addressee.isEmpty ? "\(text)! \(emoji)" : "\(text), \(addressee)! \(emoji)"
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

    // One exchange as chat bubbles: the parent's message right-aligned in
    // a filled accent bubble (like an outgoing text), Amma's reply
    // left-aligned with a small avatar, a tinted border, and a soft
    // shadow so the panel reads as an active conversation rather than a
    // flat list of plain text rows.
    @ViewBuilder
    private func conversationBubbles(for entry: InteractionLog) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Spacer(minLength: 48)
                Text(entry.transcript)
                    .font(.subheadline)
                    .foregroundStyle(outgoingBubbleTextColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(outgoingBubbleColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: outgoingBubbleColor.opacity(messageStyleColorful ? 0.25 : 0.12), radius: 6, y: 3)
            }

            if let reply = entry.responseText {
                HStack(alignment: .bottom, spacing: 8) {
                    AvatarView(size: 26)
                    Text(reply)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(incomingBubbleBorderColor, lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                        .overlay(alignment: .topTrailing) {
                            if entry.id == log.last?.id && showReaction {
                                Text(reactionEmoji)
                                    .font(.system(size: 26))
                                    .offset(x: 12, y: -14)
                                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                            }
                        }
                    Spacer(minLength: 48)
                }
            }
        }
    }

    // "Colorful" is the original pink/tinted look; "Plain" swaps in a
    // neutral gray palette for a quieter conversation panel, set via the
    // preference in Setup. Same layout and shadows either way — just the
    // hues change.
    private var outgoingBubbleColor: Color {
        messageStyleColorful ? .pink : Color(.systemGray4)
    }

    private var outgoingBubbleTextColor: Color {
        messageStyleColorful ? .white : .primary
    }

    private var incomingBubbleBorderColor: Color {
        messageStyleColorful ? greetingAccentColor.opacity(0.4) : Color(.systemGray4)
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
                let transcript = try await APIClient.shared.transcribeAudio(familyId: familyId, fileURL: fileURL)
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

    // Pops a random cheerful emoji onto the newest reply bubble and fades
    // it out shortly after — purely decorative, makes a fresh reply feel
    // a little more alive than just text appearing.
    private func triggerReaction() {
        reactionEmoji = ["✨", "💖", "😊", "🎉", "👋", "🌟"].randomElement() ?? "✨"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showReaction = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    showReaction = false
                }
            }
        }
    }

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
                triggerReaction()
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
            // Same pattern as stopRecordingAndSend's catch below — keeps
            // the user-facing message friendly/generic (could be a real
            // connection issue, or a backend-side failure like the
            // Anthropic 502 case) while still logging the real cause for
            // on-device debugging via console/device log.
            print("[AmmaDebug] sendInteraction failed: \(error)")
            await MainActor.run {
                statusMessage = "Couldn't reach Amma — check your connection."
                phase = .idle
            }
        }
    }
}
