import Foundation

/// Decision for a navigation attempt inside the app's read-only preview
/// (SPEC §6.6). The preview must load nothing but the in-memory document it
/// renders: the CSP blocks subresources, but top-level navigation — a link
/// click, a scripted `location` assignment, a `<meta http-equiv="refresh">` —
/// is governed only by the navigation delegate.
///
/// The one navigation the preview permits is the `loadHTMLString` it triggers
/// itself, which the coordinator flags explicitly (`isProgrammaticLoad`) — far
/// more robust than trying to recognize that load by its URL, which WebKit may
/// report as `about:blank`, an empty URL, or nil. Everything else is a user or
/// scripted attempt to leave the document, which the preview refuses. Pure and
/// WebKit-free so it is unit-testable (same pattern as CLIInstall).
public enum PreviewNavigationPolicy: Equatable, Sendable {
    /// The view's own in-memory document load.
    case allow
    /// A link activation: cancel and show the "preview is non-interactive"
    /// hint at the click point.
    case cancelAndExplain
    /// A scripted or meta-refresh navigation attempt: cancel with no hint —
    /// the user did nothing, so there is nothing to explain.
    case cancelSilently

    public static func decision(isProgrammaticLoad: Bool,
                                isLinkActivation: Bool) -> PreviewNavigationPolicy {
        if isProgrammaticLoad { return .allow }
        return isLinkActivation ? .cancelAndExplain : .cancelSilently
    }
}
