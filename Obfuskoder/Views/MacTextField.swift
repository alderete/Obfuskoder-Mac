import SwiftUI
import AppKit
import ObfuskoderKit

/// NSTextField wrapper that disables macOS text substitutions so emails/HTML are
/// never mangled, and reports rich edit events so the model can own undo (spec
/// §6/§7). Native field-editor undo is disabled — the model is the undo domain.
struct MacTextField: NSViewRepresentable {
    @Binding var text: String
    let field: FieldID
    var placeholder: String = ""
    var formatter: Formatter?
    var font: NSFont?
    /// When set and the field is empty, pressing Tab fills the field with this
    /// value and keeps focus with the caret at the end of the inserted text
    /// (ghost-text auto-completion); a second Tab then advances as usual.
    var tabCompletion: (() -> String)?
    /// Reports one raw edit (before/after text + caret/selection + command hint)
    /// for classification and grouping by the model.
    var onEdit: (RawTextEdit) -> Void = { _ in }
    /// Reports a pure caret/selection move (no text change) — ends the open group.
    var onSelection: (EditSelection) -> Void = { _ in }
    var onFocus: () -> Void = {}
    var onBlur: () -> Void = {}
    /// A focus/selection restore requested by undo/redo; applied when it targets
    /// this field, then consumed.
    var pendingRestore: RestoreTarget?
    var onConsumeRestore: () -> Void = {}

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
        if nsView.stringValue != text {
            nsView.stringValue = text
            context.coordinator.syncBaseline(nsView)
        }
        // Attributed placeholder: the default placeholder gray reads nearly as
        // dark as real text at the field size; tertiaryLabelColor keeps ghost
        // text clearly ghostly.
        nsView.placeholderAttributedString = placeholder.isEmpty ? nil :
            NSAttributedString(string: placeholder, attributes: [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: nsView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            ])
        // Undo/redo focus + caret restoration. Deferred so it runs after this
        // view-update pass (avoids "modifying state during update").
        if let restore = pendingRestore, restore.field == field {
            let onConsume = onConsumeRestore
            DispatchQueue.main.async { [weak nsView] in
                guard let nsView else { return }
                context.coordinator.applyRestore(restore, to: nsView)
                onConsume()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTextField
        private var lastText = ""
        private var lastSelection = EditSelection(location: 0)
        private var pendingCommand: EditCommand?
        private var selectionObserver: NSObjectProtocol?

        init(_ parent: MacTextField) { self.parent = parent }

        private func currentRange(_ control: NSControl) -> EditSelection {
            guard let editor = control.currentEditor() else { return lastSelection }
            let r = editor.selectedRange
            return EditSelection(location: r.location, length: r.length)
        }

        /// Resync the pre-edit baseline after a programmatic text change.
        func syncBaseline(_ control: NSControl) {
            lastText = control.stringValue
            lastSelection = currentRange(control)
        }

        func applyRestore(_ restore: RestoreTarget, to control: NSTextField) {
            control.window?.makeFirstResponder(control)
            if let editor = control.currentEditor() {
                let len = (control.stringValue as NSString).length
                let loc = min(max(restore.selection.location, 0), len)
                let sel = min(max(restore.selection.length, 0), len - loc)
                editor.selectedRange = NSRange(location: loc, length: sel)
            }
            lastText = control.stringValue
            lastSelection = restore.selection
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let before = lastText
            let beforeSel = lastSelection
            let after = field.stringValue
            let afterSel = currentRange(field)
            parent.text = after
            parent.onEdit(RawTextEdit(before: before, beforeSelection: beforeSel,
                                      after: after, afterSelection: afterSel, command: pendingCommand))
            lastText = after
            lastSelection = afterSel
            pendingCommand = nil
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            syncBaseline(field)
            parent.onFocus()
            observeSelection(field)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            if let t = selectionObserver { NotificationCenter.default.removeObserver(t); selectionObserver = nil }
            parent.onBlur()
        }

        /// Report pure caret/selection moves. The `string == lastText` guard skips
        /// the selection change that accompanies a text edit (handled in
        /// controlTextDidChange), so continuous typing still coalesces.
        private func observeSelection(_ field: NSTextField) {
            guard let editor = field.currentEditor() as? NSTextView else { return }
            if let t = selectionObserver { NotificationCenter.default.removeObserver(t) }
            selectionObserver = NotificationCenter.default.addObserver(
                forName: NSTextView.didChangeSelectionNotification, object: editor, queue: .main) { [weak self] note in
                guard let self, let editor = note.object as? NSTextView, editor.string == self.lastText else { return }
                let sel = EditSelection(location: editor.selectedRange.location, length: editor.selectedRange.length)
                guard sel != self.lastSelection else { return }
                self.lastSelection = sel
                self.parent.onSelection(sel)
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            // Tab in an empty field accepts the ghost-text completion as one
            // discrete action; focus stays with the caret at the end.
            if selector == #selector(NSResponder.insertTab(_:)),
               control.stringValue.trimmingCharacters(in: .whitespaces).isEmpty,
               let completion = parent.tabCompletion?(), !completion.isEmpty {
                let nsLen = (completion as NSString).length
                textView.string = completion
                textView.selectedRange = NSRange(location: nsLen, length: 0)
                parent.text = completion
                parent.onEdit(RawTextEdit(before: "", beforeSelection: EditSelection(location: 0),
                                          after: completion, afterSelection: EditSelection(location: nsLen),
                                          command: .completeLinkText))
                lastText = completion
                lastSelection = EditSelection(location: nsLen)
                return true
            }
            pendingCommand = deleteCommand(for: selector)
            return false
        }
    }
}

/// Maps a text-editing `doCommandBy:` selector to a delete-direction hint, so the
/// classifier can name backward vs. forward deletion (shared by both editors).
func deleteCommand(for selector: Selector) -> EditCommand? {
    switch selector {
    case #selector(NSResponder.deleteBackward(_:)),
         #selector(NSResponder.deleteWordBackward(_:)),
         #selector(NSResponder.deleteToBeginningOfLine(_:)),
         #selector(NSResponder.deleteToBeginningOfParagraph(_:)):
        return .deleteBackward
    case #selector(NSResponder.deleteForward(_:)),
         #selector(NSResponder.deleteWordForward(_:)),
         #selector(NSResponder.deleteToEndOfLine(_:)),
         #selector(NSResponder.deleteToEndOfParagraph(_:)):
        return .deleteForward
    default:
        return nil
    }
}

/// Configures the shared field editor to turn off substitutions and native undo
/// when this field gains focus. Disabling the field editor's `allowsUndo` keeps
/// main-form fields out of the router's auxiliary-undo path (see UndoRouter).
final class NoSubstitutionTextField: NSTextField {
    /// Main-form fields disable native undo (the model owns undo); auxiliary
    /// fields (Settings, sheets) keep it (spec §12.1).
    var disablesNativeUndo = true

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            if disablesNativeUndo { editor.allowsUndo = false }
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
