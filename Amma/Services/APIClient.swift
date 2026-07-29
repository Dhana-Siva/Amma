import Foundation

struct InteractionReply: Codable {
    var replyText: String
    var replyAudioURL: URL?
    var action: Command?

    enum CodingKeys: String, CodingKey {
        case replyText = "reply_text"
        case replyAudioURL = "reply_audio_url"
        case action
    }
}

private struct InteractionRequestBody: Encodable {
    var familyId: String
    var transcript: String
    var channel: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case transcript
        case channel
    }
}

private struct ConsentRequestBody: Encodable {
    var familyId: String
    var granted: Bool

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case granted
    }
}

private struct VoiceSampleResponse: Decodable {
    var voiceId: String

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
    }
}

private struct TranscribeResponse: Decodable {
    var transcript: String
}

private struct FamilySetupRequestBody: Encodable {
    var familyId: String
    var parentName: String
    var childName: String
    var language: String
    var childPhoneNumber: String?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case parentName = "parent_name"
        case childName = "child_name"
        case language
        case childPhoneNumber = "child_phone_number"
    }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "http://192.168.86.48:8000")!

    private init() {}

    func sendInteraction(familyId: UUID, transcript: String, channel: InteractionChannel) async throws -> InteractionReply {
        let url = baseURL.appendingPathComponent("v1/interactions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            InteractionRequestBody(familyId: familyId.uuidString, transcript: transcript, channel: channel.rawValue)
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(InteractionReply.self, from: data)
    }

    func fetchBehaviorProfile(familyId: UUID) async throws -> BehaviorProfile {
        BehaviorProfile(familyId: familyId, facts: [:], routines: [], lastUpdated: Date())
    }

    func setVoiceConsent(familyId: UUID, granted: Bool) async throws {
        let url = baseURL.appendingPathComponent("v1/consent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ConsentRequestBody(familyId: familyId.uuidString, granted: granted)
        )
        _ = try await URLSession.shared.data(for: request)
    }

    func uploadVoiceSample(familyId: UUID, audioFileURL: URL) async throws -> String {
        let url = baseURL.appendingPathComponent("v1/voice-samples")
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"family_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(familyId.uuidString)\r\n".data(using: .utf8)!)

        let audioData = try Data(contentsOf: audioFileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"sample.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(VoiceSampleResponse.self, from: data).voiceId
    }

    func transcribeAudio(fileURL: URL) async throws -> String {
        let url = baseURL.appendingPathComponent("v1/transcribe")
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let audioData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TranscribeResponse.self, from: data).transcript
    }

    func setupFamily(familyId: UUID, parentName: String, childName: String, language: String, childPhoneNumber: String? = nil) async throws {
        let url = baseURL.appendingPathComponent("v1/family-setup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            FamilySetupRequestBody(familyId: familyId.uuidString, parentName: parentName, childName: childName, language: language, childPhoneNumber: childPhoneNumber)
        )
        _ = try await URLSession.shared.data(for: request)
    }
}
