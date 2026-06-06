import SwiftUI
import WebKit

/// Read-only WKWebView that runs the actual snippet (SPEC §6.6). No network.
/// Text isn't selectable; clicking a link is intercepted (no navigation) and reported
/// via `onInteractionAttempt`, so the UI can explain the preview is non-interactive.
struct PreviewWebView: NSViewRepresentable {
    let html: String
    /// Reload only when the rendered (decoded) content changes — not on every random
    /// re-encode of the same input — to avoid needless WebContent churn.
    let reloadKey: String
    var onInteractionAttempt: () -> Void = {}

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.lastKey != reloadKey else { return }
        context.coordinator.lastKey = reloadKey
        let document = """
        <!doctype html><html><head><meta charset="utf-8">
        <style>body{font:13px -apple-system,system-ui,sans-serif;margin:8px;color:canvastext;\
        -webkit-user-select:none;user-select:none}</style>
        </head><body>\(html)</body></html>
        """
        webView.loadHTMLString(document, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: PreviewWebView
        var lastKey: String?
        init(_ parent: PreviewWebView) { self.parent = parent }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)        // the initial in-memory load
            } else {
                decisionHandler(.cancel)       // user clicked a link — never navigate
                parent.onInteractionAttempt()  // tell the UI to show the hint
            }
        }
    }
}
