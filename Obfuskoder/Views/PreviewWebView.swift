import SwiftUI
import WebKit

/// Read-only WKWebView that runs the actual snippet (SPEC §6.6). No network:
/// a `default-src 'none'` CSP in the wrapper blocks every remote subresource the
/// navigation delegate can't (images, CSS, fetch, frames), and link clicks are
/// intercepted. The page paints its own appearance-adaptive `Canvas` background via
/// public API — no private `drawsBackground` KVC. Text isn't selectable; interaction
/// attempts are reported via `onInteractionAttempt` so the UI can say so.
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
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.lastKey != reloadKey else { return }
        context.coordinator.lastKey = reloadKey
        let document = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; \
        script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; \
        connect-src 'none'; media-src data: blob:; font-src data:; frame-src 'none'; \
        base-uri 'none'; form-action 'none'">
        <style>html,body{background:Canvas;color:CanvasText}\
        body{font:13px -apple-system,system-ui,sans-serif;margin:8px;\
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
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)        // the initial in-memory load
            } else {
                decisionHandler(.cancel)       // user clicked a link — never navigate
                parent.onInteractionAttempt()  // tell the UI to show the hint
            }
        }
    }
}
