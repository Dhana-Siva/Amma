import AVFoundation

final class AudioPlaybackService: ObservableObject {
    @Published var isPlaying = false

    private var player: AVPlayer?

    func play(url: URL) {
        player = AVPlayer(url: url)
        player?.play()
        isPlaying = true
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
        }
    }

    func stop() {
        player?.pause()
        isPlaying = false
    }
}
