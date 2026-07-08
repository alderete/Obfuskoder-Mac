import Foundation

/// Decision table for navigation attempts inside the app's read-only preview
/// (SPEC §6.6). The preview must never load anything but its own in-memory
/// document: the CSP blocks subresources, but top-level navigation — a link
/// click, a scripted `location` assignment, a `<meta http-equiv="refresh">` —
/// is governed only by the navigation delegate, which maps its inputs here.
/// Pure and WebKit-free so it is unit-testable (same pattern as CLIInstall).
public enum PreviewNavigationPolicy: Equatable, Sendable {
    /// The initial in-memory document load.
    case allow
    /// A user-style interaction (link activation): cancel and show the
    /// "preview is non-interactive" hint at the click point.
    case cancelAndExplain
    /// A scripted or meta-refresh navigation attempt: cancel with no hint —
    /// the user did nothing, so there is nothing to explain.
    case cancelSilently

    /// `isUserInitiated` is true when WebKit reports anything other than
    /// `.other` (link activation and friends); `url` is the navigation target.
    /// `loadHTMLString(_:baseURL: nil)` arrives as non-user-initiated
    /// `about:blank`, and nothing else does.
    public static func decision(isUserInitiated: Bool, url: URL?) -> PreviewNavigationPolicy {
        if isUserInitiated { return .cancelAndExplain }
        if let url, url.absoluteString == "about:blank" { return .allow }
        return .cancelSilently
    }
}
