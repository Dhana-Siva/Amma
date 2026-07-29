import Foundation
import GoogleCast

/// Writes Cast SDK log lines to a file in Documents (visible to `xcrun
/// devicectl device copy from`), since there's no simple way to stream a
/// physical device's console output live from this environment. Only
/// intended for diagnosing setup issues like devices not appearing in
/// discovery; not wired into any user-facing UI.
private final class CastDiagnosticLogger: NSObject, GCKLoggerDelegate {
    static let shared = CastDiagnosticLogger()

    private let fileURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("cast_debug.log")
    }()

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        write("[\(level.rawValue)] \(function): \(message)")
    }

    /// For our own code to log to the same file — the Cast SDK doesn't log
    /// outbound custom-message sends itself, only connect/disconnect, so
    /// this is the only way to see whether e.g. CastService.play() actually
    /// ran and what it got back.
    func write(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: fileURL)
        }
    }
}

/// Custom-message channel Amma uses to tell the receiver page (see
/// backend/static/cast_receiver.html, hosted at
/// https://dhana-siva.github.io/amma-cast-receiver/) which video to play.
/// Namespace is app-specific to avoid colliding with any other sender.
private let castNamespace = "urn:x-cast:com.dhana.amma.cast"

private final class CastMessageChannel: GCKCastChannel {
    init() {
        super.init(namespace: castNamespace)
    }
}

enum CastServiceError: Error {
    case notConnected
    case sendFailed
}

/// Casts YouTube videos to a Chromecast via Google's official Cast SDK,
/// loading our own custom receiver page (registered under Cast Application
/// ID 592BF965) instead of YouTube's native receiver. This replaced an
/// earlier attempt to mimic YouTube's own undocumented casting protocol
/// directly, which was tested against a real Chromecast and confirmed
/// broken — this path is slower to set up (receiver hosting + Cast SDK
/// developer registration) but uses Google's supported, documented API.
@MainActor
final class CastService: NSObject, ObservableObject {
    static let shared = CastService()

    /// Lets CommandExecutor log into the same diagnostic file, so we can
    /// tell whether an action even reached this far before CastService's
    /// own play()/stop() entry logging kicks in.
    static func logDiagnostic(_ message: String) {
        CastDiagnosticLogger.shared.write(message)
    }

    @Published private(set) var discoveredDevices: [GCKDevice] = []
    @Published private(set) var isConnected = false
    @Published private(set) var connectedDeviceName: String?

    private let messageChannel = CastMessageChannel()

    private var sessionManager: GCKSessionManager { GCKCastContext.sharedInstance().sessionManager }
    private var discoveryManager: GCKDiscoveryManager { GCKCastContext.sharedInstance().discoveryManager }

    /// Call once at app startup, before any other CastService use.
    static func configure(receiverApplicationID: String) {
        let criteria = GCKDiscoveryCriteria(applicationID: receiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        GCKCastContext.setSharedInstanceWith(options)

        let filter = GCKLoggerFilter()
        filter.minimumLevel = .verbose
        GCKLogger.sharedInstance().filter = filter
        GCKLogger.sharedInstance().delegate = CastDiagnosticLogger.shared
        GCKLogger.sharedInstance().loggingEnabled = true
    }

    private override init() {
        super.init()
        sessionManager.add(self)
        discoveryManager.add(self)
        if let session = sessionManager.currentCastSession {
            isConnected = true
            connectedDeviceName = session.device.friendlyName
            session.add(messageChannel)
        }
    }

    func startDiscovery() {
        discoveryManager.startDiscovery()
        refreshDeviceList()
    }

    func stopDiscovery() {
        discoveryManager.stopDiscovery()
    }

    func connect(to device: GCKDevice) {
        sessionManager.startSession(with: device)
    }

    func disconnect() {
        sessionManager.endSessionAndStopCasting(true)
    }

    /// Sends the video to the already-connected receiver. Throws
    /// `.notConnected` if nothing is linked yet, so callers can surface a
    /// user-facing message the same way placeCall/sendMessage do.
    func play(videoId: String) throws {
        try sendMessage("{\"videoId\":\"\(videoId)\"}")
    }

    /// Tells the receiver to stop whatever's currently playing, without
    /// ending the Cast session — so a future play() doesn't need relinking.
    func stop() throws {
        try sendMessage("{\"action\":\"stop\"}")
    }

    private func sendMessage(_ json: String) throws {
        CastDiagnosticLogger.shared.write("[AmmaCast] sendMessage called: \(json)")
        guard sessionManager.currentCastSession != nil else {
            CastDiagnosticLogger.shared.write("[AmmaCast] sendMessage aborted: no currentCastSession")
            throw CastServiceError.notConnected
        }
        var error: GCKError?
        let sent = messageChannel.sendTextMessage(json, error: &error)
        CastDiagnosticLogger.shared.write("[AmmaCast] sendTextMessage returned sent=\(sent) error=\(String(describing: error))")
        if !sent || error != nil {
            throw CastServiceError.sendFailed
        }
    }

    private func refreshDeviceList() {
        var devices: [GCKDevice] = []
        for index in 0..<discoveryManager.deviceCount {
            devices.append(discoveryManager.device(at: index))
        }
        discoveredDevices = devices
    }
}

extension CastService: GCKSessionManagerListener {
    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKCastSession) {
        Task { @MainActor in
            session.add(self.messageChannel)
            self.isConnected = true
            self.connectedDeviceName = session.device.friendlyName
        }
    }

    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didResumeCastSession session: GCKCastSession) {
        Task { @MainActor in
            session.add(self.messageChannel)
            self.isConnected = true
            self.connectedDeviceName = session.device.friendlyName
        }
    }

    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKCastSession, withError error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.connectedDeviceName = nil
        }
    }
}

extension CastService: GCKDiscoveryManagerListener {
    nonisolated func didUpdateDeviceList() {
        Task { @MainActor in
            self.refreshDeviceList()
        }
    }
}
