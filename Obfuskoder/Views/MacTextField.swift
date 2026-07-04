import SwiftUI
import AppKit

/// NSTextField wrapper that disables macOS text substitutions so emails/HTML are never mangled.
struct MacTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var formatter: Formatter?
    var font: NSFont?
    /// When set and the field is empty, pressing Tab fills the field with this
    /// value and keeps focus with the caret at the end of the inserted text
    /// (ghost-text auto-completion); a second Tab then advances as usual.
    var tabCompletion: (() -> String)?
    var onChange: () -> Void = {}

    func makeNSView(context: Context) -> NSTextField {
        let field = NoSubstitutionTextField()
        field.placeholderString = placeholder
        field.formatter = formatter
        if let font { field.font = font }
        field.delegate = context.coordinator
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .default
        field.lineBreakMode = .byClipping
        field.usesSingleLineMode = true
        field.cell?.sendsActionOnEndEditing = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text { nsView.stringValue = text }
        nsView.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTextField
        init(_ parent: MacTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
            parent.onChange()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            // Tab in an empty field accepts the ghost-text completion and
            // consumes the Tab: focus stays here with the caret at the end of
            // the inserted text (a second Tab advances normally).
            if selector == #selector(NSResponder.insertTab(_:)),
               control.stringValue.trimmingCharacters(in: .whitespaces).isEmpty,
               let completion = parent.tabCompletion?(), !completion.isEmpty {
                textView.string = completion
                textView.selectedRange = NSRange(location: (completion as NSString).length, length: 0)
                parent.text = completion
                parent.onChange()
                return true
            }
            return false
        }
    }
}

/// Configures the shared field editor to turn off substitutions when this field gains focus.
final class NoSubstitutionTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            editor.selectedTextAttributes = [.backgroundColor: NSColor.appTextSelection]
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
            editor.smartInsertDeleteEnabled = false
        }
        return ok
    }
}
