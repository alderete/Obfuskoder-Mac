import SwiftUI
import AppKit

// All app typography derives from text styles, never fixed point sizes, so it
// scales when the user changes their system text size. `.title3` is the 15pt
// style on macOS (body/headline are 13pt) — headings should sit a step above
// body text.

extension Font {
    /// App-wide heading/label font: 15pt bold at default text size.
    static let appHeadline = Font.title3.bold()
}

extension NSFont {
    /// Basic-form field text: 15pt regular at default text size, matching the
    /// heading size while keeping the regular input-text weight.
    static var appFieldFont: NSFont { .preferredFont(forTextStyle: .title3) }
}

extension Text {
    /// Renders inline markdown (`code`, **bold**) from a localized string;
    /// falls back to the plain string if parsing fails.
    init(inlineMarkdown: String) {
        self.init((try? AttributedString(markdown: inlineMarkdown)) ?? AttributedString(inlineMarkdown))
    }
}
