import Foundation

/// User-facing cadence for automatic update checks. A pure mapping to Sparkle's
/// two knobs (`automaticallyChecksForUpdates` + `updateCheckInterval`), kept in
/// the Kit so it is unit-testable with no Sparkle/WebKit dependency — the same
/// pattern as `PreviewNavigationPolicy`. Backed by `String` so it persists via
/// `@AppStorage`.
public enum UpdateFrequency: String, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case never

    /// Whether Sparkle should check automatically. `.never` turns checks off.
    public var automaticallyChecks: Bool { self != .never }

    /// The check interval in seconds, or nil when checks are disabled.
    public var checkInterval: TimeInterval? {
        switch self {
        case .daily:   return 86_400
        case .weekly:  return 604_800
        case .monthly: return 2_592_000   // 30 days
        case .never:   return nil
        }
    }
}
