import Testing
import Foundation
import ObfuskoderKit

@Test func allowsInitialAboutBlankLoad() {
    #expect(PreviewNavigationPolicy.decision(isUserInitiated: false,
                                             url: URL(string: "about:blank")) == .allow)
}

// JS `location.href = …` and `<meta http-equiv="refresh">` arrive as
// non-user-initiated navigations, exactly like the initial load — only the
// target URL tells them apart. They must be cancelled, and silently: the
// user did nothing, so the "non-interactive" hint would be noise.
@Test func cancelsScriptedNavigationSilently() {
    for target in ["https://example.com/", "http://evil.test/x",
                   "file:///etc/passwd", "about:srcdoc"] {
        #expect(PreviewNavigationPolicy.decision(isUserInitiated: false,
                                                 url: URL(string: target)) == .cancelSilently,
                "target: \(target)")
    }
    #expect(PreviewNavigationPolicy.decision(isUserInitiated: false, url: nil) == .cancelSilently)
}

@Test func cancelsLinkActivationWithExplanation() {
    #expect(PreviewNavigationPolicy.decision(isUserInitiated: true,
                                             url: URL(string: "https://example.com/")) == .cancelAndExplain)
    // Even a click targeting about:blank is an interaction, not a load.
    #expect(PreviewNavigationPolicy.decision(isUserInitiated: true,
                                             url: URL(string: "about:blank")) == .cancelAndExplain)
}
