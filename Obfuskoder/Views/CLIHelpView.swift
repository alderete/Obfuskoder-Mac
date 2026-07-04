import SwiftUI
import AppKit

/// SPEC-CLI §11.2: brief in-app instructions for the obfuskode tool.
/// Deliberately short — full detail lives in `obfuskode --help`.
struct CLIHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(inlineMarkdown: UIStrings.cliHelpIntro)
            Text(UIStrings.cliHelpInstall)
            VStack(alignment: .leading, spacing: 4) {
                SelectableCode(text: "obfuskode --email sue@example.com --link-text \"Email Sue\"")
                SelectableCode(text: "obfuskode --html '<a href=\"mailto:sue@example.com\">contact</a>'")
                SelectableCode(text: "pbpaste | obfuskode | pbcopy")
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Selectable text sits on the "live" white surface (same language
            // as the snippet box, WIN-4) — the selection tint is invisible on
            // a gray wash (COLOR-5).
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            Text(inlineMarkdown: UIStrings.cliHelpOutro)
        }
        .padding(20)
        .frame(width: 460)
    }
}

/// Selectable monospaced example line. AppKit-backed because SwiftUI's
/// `.textSelection` offers no control over its low-contrast highlight color
/// (COLOR-5); this uses the same selection color as the app's text fields.
private struct SelectableCode: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = SelectionTintedLabel(labelWithString: text)
        field.isSelectable = true
        field.font = .monospacedSystemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize,
            weight: .regular)
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.preferredMaxLayoutWidth = 400
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        field.stringValue = text
    }
}

private final class SelectionTintedLabel: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            editor.selectedTextAttributes = [.backgroundColor: NSColor.appTextSelection]
        }
        return ok
    }
}

#Preview {
    CLIHelpView()
}
