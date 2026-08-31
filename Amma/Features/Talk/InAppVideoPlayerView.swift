import SwiftUI
import YouTubeiOSPlayerHelper

/// Plays a YouTube video right inside the app — the fallback when no TV/
/// Chromecast is linked, so asking Amma to "play X" still does something
/// useful instead of just reporting "no TV linked." Presented as a full-
/// screen cover from TalkView when CommandExecutor reports
/// .playInAppVideo.
///
/// This went through two hand-rolled WKWebView + raw <iframe> attempts
/// first (a plain page load, then a wrapped HTML page with various
/// baseURL/user-agent tweaks) — both still hit YouTube's undocumented
/// embedding-client validation on a real device ("Video unavailable,
/// error 152-4"). Switched to Google's own officially-maintained
/// YTPlayerView (from the youtube-ios-player-helper SPM package) instead
/// of continuing to guess at what a bare iframe is missing — it's built
/// specifically to handle this reliably.
struct InAppVideoPlayerView: View {
    let videoId: String
    let title: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            YouTubePlayerRepresentable(videoId: videoId)
                .ignoresSafeArea(edges: .bottom)
                .background(.black)
                .navigationTitle(title ?? "Playing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

private struct YouTubePlayerRepresentable: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.delegate = context.coordinator
        return playerView
    }

    func updateUIView(_ playerView: YTPlayerView, context: Context) {
        guard context.coordinator.loadedVideoId != videoId else { return }
        context.coordinator.loadedVideoId = videoId
        playerView.load(withVideoId: videoId, playerVars: ["playsinline": 1, "autoplay": 1])
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Starts playback once the player signals it's actually ready —
    /// `autoplay: 1` alone isn't reliable in every player state, and
    /// logs errors so a future failure shows a real cause in the device
    /// console instead of another guessing round.
    final class Coordinator: NSObject, YTPlayerViewDelegate {
        var loadedVideoId: String?

        func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
            playerView.playVideo()
        }

        func playerView(_ playerView: YTPlayerView, receivedError error: YTPlayerError) {
            print("[AmmaDebug] YTPlayerView error: \(error)")
        }
    }
}
