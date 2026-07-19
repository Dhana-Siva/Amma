import AVFoundation

final class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsedSeconds: Int = 0
    @Published var recordedFileURL: URL?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        recordedFileURL = url
        isRecording = true
        elapsedSeconds = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    func stopRecording() {
        recorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
}
