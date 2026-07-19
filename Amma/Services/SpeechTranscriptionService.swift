import Speech

enum SpeechTranscriptionError: Error {
    case notAuthorized
    case recognizerUnavailable
    case emptyResult
}

/// Guards against SFSpeechRecognizer's completion handler firing more than once.
private final class ResumeGuard {
    private var didResume = false
    private let lock = NSLock()

    func resumeOnce(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        action()
    }
}

final class SpeechTranscriptionService {
    static let shared = SpeechTranscriptionService()

    private init() {}

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(fileURL: URL, languageCode: String) async throws -> String {
        let locale = Locale(identifier: languageCode == "ta" ? "ta-IN" : "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let resumeGuard = ResumeGuard()
            let request = SFSpeechURLRecognitionRequest(url: fileURL)
            request.shouldReportPartialResults = false

            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    resumeGuard.resumeOnce { continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                resumeGuard.resumeOnce {
                    if text.isEmpty {
                        continuation.resume(throwing: SpeechTranscriptionError.emptyResult)
                    } else {
                        continuation.resume(returning: text)
                    }
                }
            }
        }
    }
}
