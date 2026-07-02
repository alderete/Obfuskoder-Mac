import SwiftUI
import AppKit

/// NSTextField wrapper that disables macOS text substitutions so emails/HTML are never mangled.
struct MacTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var formatter: Formatter?
    var onChange: () -> Void = {}

    func makeNSView(context: Context) -> NSTextField {
        let field = NoSubstitutionTextField()
        field.placeholderString = placeholder
        field.formatter = formatter
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
        if nsView.stringValue != text { nsView.stringValue = text }
        nsView.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: MacTextField
        init(_ parent: MacTextField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
            parent.onChange()
        }
    }
}

/// Configures the shared field editor to turn off substitutions when this field gains focus.
final class NoSubstitutionTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
            editor.smartInsertDeleteEnabled = false
        }
        return ok
    }
}
