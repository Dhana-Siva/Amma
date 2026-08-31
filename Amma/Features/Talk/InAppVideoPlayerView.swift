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
///
/// This has taken a few iterations, each addressing a real but different
/// failure:
/// 1. Loading the embed URL *directly* as the WKWebView's top-level page
///    produced YouTube's "Video configuration error" — fixed by wrapping
///    the iframe inside an actual (tiny, local) HTML page instead.
/// 2. A `baseURL` of `https://www.youtube.com` on that page (a common
///    trick, claiming an origin the page isn't really served from) led
///    to "Video unavailable, error 152-4" instead — changed to `nil`
///    (no origin claim at all).
/// 3. Still 152-4 on a real device after that. The next most likely
///    cause, confirmed by many other developers hitting this exact
///    combination: WKWebView's *default user agent* doesn't fully match
///    a real mobile Safari, and YouTube's client validation can reject
///    it outright — hence a fixed numeric error rather than anything
///    content-specific. Setting `customUserAgent` to a real iOS Safari
///    UA string is the standard fix.
/// If this still doesn't resolve it, the reliable fallback is Google's
/// own `youtube-ios-player-helper` library (a thin, officially
/// maintained WKWebView + IFrame Player API wrapper) — a bare hand-
/// rolled iframe is inherently working around something Google hasn't
/// documented, so there's a real ceiling on how much can be fixed this
/// way if YouTube's validation keeps moving.
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
        // WKWebView's default UA doesn't fully match real mobile Safari,
        // and YouTube's client validation can reject that outright.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <style>
            html, body { margin: 0; padding: 0; background: #000; height: 100%; }
            iframe { position: fixed; top: 0; left: 0; width: 100%; height: 100%; border: none; }
          </style>
        </head>
        <body>
          <iframe src="https://www.youtube.com/embed/\(videoId)?autoplay=1&playsinline=1"
                  allow="autoplay; encrypted-media" allowfullscreen></iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
