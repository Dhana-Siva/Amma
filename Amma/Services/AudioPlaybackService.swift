import AVFoundation

final class AudioPlaybackService: ObservableObject {
    @Published var isPlaying = false

    private var player: AVPlayer?

    /// Plays the reply and suspends until it finishes (or 30s elapses, as a
    /// safety net), so callers can wait for the spoken reply to be heard in
    /// full before doing anything else — e.g. placing a call right after
    /// otherwise interrupts or outruns the reply.
    @MainActor
    func play(url: URL) async {
        CastService.logDiagnostic("[AudioPlayback] play() called with \(url)")

        // Amma is meant to be heard in the room, not routed to whatever
        // Bluetooth device happens to be connected (headphones, a car, a
        // speaker elsewhere in the house) — confirmed live that replies
        // were playing successfully but silently going to a connected
        // Bluetooth A2DP route instead of the phone speaker. .playback
        // category alone can't force this override (only .playAndRecord
        // can), so use that with .defaultToSpeaker, then explicitly
        // override to the speaker regardless of any Bluetooth connection.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)
            CastService.logDiagnostic("[AudioPlayback] session category=\(session.category.rawValue) route=\(session.currentRoute.outputs.map(\.portType.rawValue))")
        } catch {
            CastService.logDiagnostic("[AudioPlayback] session setup FAILED: \(error)")
        }

        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        isPlaying = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var observer: NSObjectProtocol?
            var statusObservation: NSKeyValueObservation?
            var didResume = false
            let resumeOnce = { (reason: String) in
                guard !didResume else { return }
                didResume = true
                CastService.logDiagnostic("[AudioPlayback] resuming: \(reason)")
                if let observer { NotificationCenter.default.removeObserver(observer) }
                statusObservation?.invalidate()
                continuation.resume()
            }

            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in resumeOnce("played to end") }

            statusObservation = newPlayer.currentItem?.observe(\.status, options: [.new]) { item, _ in
                let status = item.status
                let error = item.error
                Task { @MainActor in
                    CastService.logDiagnostic("[AudioPlayback] item status=\(status.rawValue) error=\(String(describing: error))")
                    if status == .failed {
                        resumeOnce("item failed: \(String(describing: error))")
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { resumeOnce("30s timeout") }

            newPlayer.play()
            CastService.logDiagnostic("[AudioPlayback] player.play() called, rate=\(newPlayer.rate)")
        }

        isPlaying = false
    }

    func stop() {
        player?.pause()
        isPlaying = false
    }
}
