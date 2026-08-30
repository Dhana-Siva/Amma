import SwiftUI
import WebKit

/// Plays a YouTube video right inside the app — the fallback when no TV/
/// Chromecast is linked, so asking Amma to "play X" still does something
/// useful instead of just reporting "no TV linked." Presented as a full-
/// screen cover from TalkView when CommandExecutor reports
/// .playInAppVideo.
struct InAppVideoPlayerView: View {
    let videoId: String
    let title: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            YouTubeEmbedWebView(videoId: videoId)
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

/// A bare `<iframe>` embed, not the YouTube IFrame JS API — the same fix
/// that resolved a real playback bug on the Cast receiver page (the JS
/// API's ready callback never fired reliably in that embedded context;
/// a plain iframe just works, and there's no reason to expect the JS API
/// to behave any better inside a WKWebView here).
private struct YouTubeEmbedWebView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: "https://www.youtube.com/embed/\(videoId)?autoplay=1&playsinline=1") else { return }
        webView.load(URLRequest(url: url))
    }
}
