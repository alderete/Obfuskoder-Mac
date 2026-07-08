import SwiftUI
import WebKit
import ObfuskoderKit

/// Read-only WKWebView that runs the actual snippet (SPEC §6.6). No network:
/// a `default-src 'none'` CSP in the wrapper blocks every remote subresource the
/// navigation delegate can't (images, CSS, fetch, frames), and link clicks are
/// intercepted. The page paints its own appearance-adaptive background — `Canvas`
/// tinted 5% toward `CanvasText` so the preview reads as display-only next to the
/// snippet's textBackgroundColor surface (WIN-4) — via public API, no private
/// `drawsBackground` KVC. Text isn't selectable; interaction
/// attempts are reported via `onInteractionAttempt` so the UI can say so.
struct PreviewWebView: NSViewRepresentable {
    let html: String
    /// Reload only when the rendered (decoded) content changes — not on every random
    /// re-encode of the same input — to avoid needless WebContent churn.
    let reloadKey: String
    var onInteractionAttempt: () -> Void = {}
    /// Reports the rendered document's natural height after each load, so the
    /// pane can size the preview to its content (WIN-3).
    var onContentHeight: (CGFloat) -> Void = { _ in }

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
        // The "non-interactive" toast is rendered in-page so it can anchor to
        // the exact click point without moving any SwiftUI layout (CTRL-2).
        let toastMessage = UIStrings.previewNonInteractive
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let document = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; \
        script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; \
        connect-src 'none'; media-src data: blob:; font-src data:; frame-src 'none'; \
        base-uri 'none'; form-action 'none'">
        <style>html,body{background:color-mix(in srgb, Canvas 95%, CanvasText 5%);color:CanvasText}\
        body{font:13px -apple-system,system-ui,sans-serif;margin:8px;\
        -webkit-user-select:none;user-select:none}\
        #__obfsk_toast{position:fixed;opacity:0;transition:opacity .15s ease;\
        pointer-events:none;background:rgba(40,40,40,.92);color:#fff;\
        padding:4px 10px;border-radius:6px;font:11px -apple-system,sans-serif;\
        white-space:nowrap;z-index:2147483647}</style>
        </head><body>\(html)\
        <div id="__obfsk_toast"></div>\
        <script>(function(){\
        var t=document.getElementById('__obfsk_toast'),h;\
        document.addEventListener('click',function(e){\
        if(!e.target.closest('a'))return;\
        t.textContent="\(toastMessage)";\
        t.style.left='0px';t.style.top='0px';t.style.opacity='1';\
        var r=t.getBoundingClientRect();\
        var x=Math.min(Math.max(4,e.clientX-r.width/2),window.innerWidth-r.width-4);\
        var y=e.clientY-r.height-8;if(y<4)y=e.clientY+12;\
        t.style.left=x+'px';t.style.top=y+'px';\
        clearTimeout(h);h=setTimeout(function(){t.style.opacity='0'},1800);\
        },true);})();</script></body></html>
        """
        webView.loadHTMLString(document, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: PreviewWebView
        var lastKey: String?
        init(_ parent: PreviewWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // body margin (8pt top and bottom) isn't part of scrollHeight.
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self, let h = result as? Double else { return }
                self.parent.onContentHeight(CGFloat(h) + 16)
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            // Allow the null-origin in-memory load; cancel a link click or a
            // scripted `location`/<meta refresh> escape to a real URL (the CSP
            // doesn't govern top-level navigation).
            switch PreviewNavigationPolicy.decision(
                isLinkActivation: navigationAction.navigationType == .linkActivated,
                url: navigationAction.request.url) {
            case .allow:
                decisionHandler(.allow)        // the in-memory document load
            case .cancelAndExplain:
                decisionHandler(.cancel)       // user clicked a link — never navigate
                parent.onInteractionAttempt()  // tell the UI to show the hint
            case .cancelSilently:
                decisionHandler(.cancel)       // scripted escape attempt — just block
            }
        }
    }
}
