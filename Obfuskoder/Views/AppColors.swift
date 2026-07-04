import AppKit

extension NSColor {
    /// Selection background for the app's text fields and editor. The system's
    /// dark-mode derivation of the sage accent lands on a muddy gray
    /// (#626A5D, measured) that reads poorly under white text (COLOR-4). Use
    /// the accent itself in dark mode and a pale accent tint in light.
    /// Dynamic provider so live appearance switches resolve correctly.
    static let appTextSelection = NSColor(name: nil) { appearance in
        let accent = NSColor(named: "AccentColor") ?? .controlAccentColor
        return appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? accent
            : accent.withAlphaComponent(0.25)
    }
}
