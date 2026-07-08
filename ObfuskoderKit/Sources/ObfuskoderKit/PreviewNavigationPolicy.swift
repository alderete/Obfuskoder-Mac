import Foundation

/// Decision for a navigation attempt inside the app's read-only preview
/// (SPEC §6.6). The preview loads only the in-memory document it renders: the
/// CSP blocks subresources, but top-level navigation — a link click, a scripted
/// `location` assignment, a `<meta http-equiv="refresh">` — is governed only by
/// the navigation delegate.
///
/// The `loadHTMLString(_:baseURL: nil)` that renders the snippet loads from a
/// *null origin* — WebKit reports its URL as `about:blank`, an empty URL, or
/// nil depending on the version — so it is recognized by having no real scheme.
/// A scripted escape, by contrast, targets a real scheme (`http`, `https`,
/// `file`, …) and is refused. Pure and WebKit-free so it is unit-testable (same
/// pattern as CLIInstall).
public enum PreviewNavigationPolicy: Equatable, Sendable {
    /// The in-memory document's own (null-origin) load.
    case allow
    /// A link activation: cancel and show the "preview is non-interactive"
    /// hint at the click point.
    case cancelAndExplain
    /// A scripted or meta-refresh navigation to a real URL: cancel with no hint
    /// — the user did nothing, so there is nothing to explain.
    case cancelSilently

    public static func decision(isLinkActivation: Bool, url: URL?) -> PreviewNavigationPolicy {
        if isLinkActivation { return .cancelAndExplain }
        switch url?.scheme?.lowercased() {
        case nil, "about":
            return .allow           // the in-memory document's null-origin load
        default:
            return .cancelSilently  // scripted escape to a real scheme
        }
    }
}
