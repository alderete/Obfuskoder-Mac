import SwiftUI
import AppKit

/// A substitution-free NSTextField for AUXILIARY contexts (Settings, sheets).
/// Unlike `MacTextField` it keeps the field editor's NATIVE text undo (spec
/// §12.1) and never reports edits to the model's undo domain, so `⌘Z` there
/// edits the field, not the main form. Supports an optional `Formatter` (e.g.
/// the Settings fallback field's `@`-blocking formatter).
struct AuxTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var formatter: Formatter?

    func makeNSView(context: Context) -> NSTextField {
        let field = NoSubstitutionTextField()
        field.disablesNativeUndo = false          // auxiliary: keep native ⌘Z
        field.placeholderString = placeholder
        field.formatter = formatter
        field.delegate = context.coordinator
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .default
        field.usesSingleLineMode = true
        field.cell?.sendsActionOnEndEditing = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text { nsView.stringValue = text }
        nsView.placeholderAttributedString = placeholder.isEmpty ? nil :
            NSAttributedString(string: placeholder, attributes: [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: nsView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            ])
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AuxTextField
        init(_ parent: AuxTextField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}
