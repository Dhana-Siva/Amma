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
/// Confirmed live: loading the embed URL *directly* as the WKWebView's
/// top-level page (`webView.load(URLRequest(url: embedURL))`) produces
/// YouTube's own "Video configuration error" — its embed validation
/// doesn't get a real origin/referrer to check that way. Wrapping the
/// same iframe inside an actual (tiny, local) HTML page and loading that
/// via `loadHTMLString(_:baseURL:)`, with baseURL set to youtube.com,
/// gives it a proper origin to validate against — same fix shape as the
/// Cast receiver's own iframe embed, just reached the "wrap it in real
/// HTML" step one layer earlier here since there was no HTML page at all
/// yet, just a direct URL load.
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
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }
}
