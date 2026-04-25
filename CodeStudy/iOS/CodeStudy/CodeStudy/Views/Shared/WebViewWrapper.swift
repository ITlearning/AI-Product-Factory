import SwiftUI
import WebKit

/// Generic UIViewRepresentable that hosts a WKWebView and reports load
/// success/failure back to SwiftUI. Used by SurveyModalView to embed a
/// Google Forms URL, but kept feature-agnostic so it can be reused later.
///
/// Loading is fire-once based on the URL identity — the view does not
/// reload on every body re-evaluation. To force a reload, present a new
/// instance with a different URL.
struct WebViewWrapper: UIViewRepresentable {

    // MARK: - Inputs

    let url: URL
    let onLoadSuccess: () -> Void
    let onLoadFailure: (Error) -> Void

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLoadSuccess: onLoadSuccess,
            onLoadFailure: onLoadFailure
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = true
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false

        webView.load(URLRequest(url: url))
        context.coordinator.loadedURL = url
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload when the URL actually changes — prevents flicker
        // and double-loads on parent state changes.
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onLoadSuccess: () -> Void
        let onLoadFailure: (Error) -> Void
        var loadedURL: URL?

        init(
            onLoadSuccess: @escaping () -> Void,
            onLoadFailure: @escaping (Error) -> Void
        ) {
            self.onLoadSuccess = onLoadSuccess
            self.onLoadFailure = onLoadFailure
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadSuccess()
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            onLoadFailure(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onLoadFailure(error)
        }
    }
}
