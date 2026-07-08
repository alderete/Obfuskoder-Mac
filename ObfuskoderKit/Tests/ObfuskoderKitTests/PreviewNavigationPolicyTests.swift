import Testing
import Foundation
import ObfuskoderKit

// The in-memory document loads from a null origin (about:blank / empty / nil,
// depending on WebKit); all of those must be allowed so the preview renders.
@Test func allowsNullOriginLoad() {
    #expect(PreviewNavigationPolicy.decision(isLinkActivation: false,
                                             url: URL(string: "about:blank")) == .allow)
    #expect(PreviewNavigationPolicy.decision(isLinkActivation: false, url: nil) == .allow)
    #expect(PreviewNavigationPolicy.decision(isLinkActivation: false,
                                             url: URL(string: "about:srcdoc")) == .allow)
}

// A scripted location=/meta-refresh escape targets a real scheme and is
// cancelled silently (the user did nothing to explain).
@Test func cancelsScriptedEscapeToRealURL() {
    for target in ["https://example.com/", "http://evil.test/x", "file:///etc/passwd"] {
        #expect(PreviewNavigationPolicy.decision(isLinkActivation: false,
                                                 url: URL(string: target)) == .cancelSilently,
                "target: \(target)")
    }
}

// A link click is cancelled but explained (the toast hint), whatever its URL.
@Test func cancelsLinkActivationWithExplanation() {
    #expect(PreviewNavigationPolicy.decision(isLinkActivation: true,
                                             url: URL(string: "https://example.com/")) == .cancelAndExplain)
    #expect(PreviewNavigationPolicy.decision(isLinkActivation: true,
                                             url: URL(string: "about:blank")) == .cancelAndExplain)
}
