import Testing
import Foundation
import ObfuskoderKit

// The view's own loadHTMLString is the one navigation the preview allows,
// regardless of how WebKit reports its URL or whether it looks like a link.
@Test func allowsTheProgrammaticLoad() {
    #expect(PreviewNavigationPolicy.decision(isProgrammaticLoad: true,
                                             isLinkActivation: false) == .allow)
    #expect(PreviewNavigationPolicy.decision(isProgrammaticLoad: true,
                                             isLinkActivation: true) == .allow)
}

// A link click is cancelled but explained (the toast hint).
@Test func cancelsLinkActivationWithExplanation() {
    #expect(PreviewNavigationPolicy.decision(isProgrammaticLoad: false,
                                             isLinkActivation: true) == .cancelAndExplain)
}

// Scripted navigation (location =, <meta refresh>) is cancelled silently —
// the user did nothing to explain.
@Test func cancelsScriptedNavigationSilently() {
    #expect(PreviewNavigationPolicy.decision(isProgrammaticLoad: false,
                                             isLinkActivation: false) == .cancelSilently)
}
