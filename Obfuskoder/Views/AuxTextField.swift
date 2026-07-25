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
    /// Set for fields whose bound text is reset between presentations (the Save
    /// sheet name field), so a stale native-undo action can't outlive its text
    /// and crash on invocation — see `NoSubstitutionTextField` (test 10.2).
    var clearsUndoOnFocus = false

    func makeNSView(context: Context) -> NSTextField {
        let field = NoSubstitutionTextField()
        field.disablesNativeUndo = false          // auxiliary: keep native ⌘Z
        field.clearsNativeUndoOnFocus = clearsUndoOnFocus
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
        if nsView.stringValue != text {
            nsView.stringValue = text
            // A programmatic reset invalidates the field editor's native undo
            // actions (their ranges refer to the prior text). Clear them while
            // the field is still first responder — the Cancel-then-reopen path
            // that reuses the field never resigns focus, so this is the only
            // hook that fires before ⌘Z could invoke a stale action (test 10.2).
            if let editor = nsView.currentEditor() as? NSTextView {
                editor.breakUndoCoalescing()
                editor.undoManager?.removeAllActions()
            }
        }
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
