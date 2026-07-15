import SwiftUI
import AppKit
import ObfuskoderKit

/// NSTextView wrapper for the Advanced HTML field: monospaced, spell/substitution-free,
/// scrollable. Reports rich edit events so the model owns undo (spec §6/§7);
/// native undo is disabled.
struct MacTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onEdit: (RawTextEdit) -> Void = { _ in }
    var onSelection: (EditSelection) -> Void = { _ in }
    var onFocus: () -> Void = {}
    var onBlur: () -> Void = {}
    var pendingRestore: RestoreTarget?
    var onConsumeRestore: () -> Void = {}

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.autohidesScrollers = true
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
        textView.isRichText = false
        // Derive from a text style so the editor honors the user's text-size
        // override (Typography's rule: no fixed point sizes).
        textView.font = .monospacedSystemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        // Undo is model-owned (per-mode grouping engine); native NSTextView undo
        // would register on a manager we don't drive. See ADR-0001.
        textView.allowsUndo = false
        textView.selectedTextAttributes = [.backgroundColor: NSColor.appTextSelection]
        textView.textContainerInset = NSSize(width: 4, height: 6)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.syncBaseline(textView)
        }
        if let restore = pendingRestore, restore.field == .advancedHTML {
            let onConsume = onConsumeRestore
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                context.coordinator.applyRestore(restore, to: textView)
                onConsume()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacTextEditor
        private var lastText = ""
        private var lastSelection = EditSelection(location: 0)
        private var pendingCommand: EditCommand?

        init(_ parent: MacTextEditor) { self.parent = parent }

        private func range(_ tv: NSTextView) -> EditSelection {
            EditSelection(location: tv.selectedRange().location, length: tv.selectedRange().length)
        }

        func syncBaseline(_ tv: NSTextView) {
            lastText = tv.string
            lastSelection = range(tv)
        }

        func applyRestore(_ restore: RestoreTarget, to tv: NSTextView) {
            tv.window?.makeFirstResponder(tv)
            let len = (tv.string as NSString).length
            let loc = min(max(restore.selection.location, 0), len)
            let sel = min(max(restore.selection.length, 0), len - loc)
            let nsRange = NSRange(location: loc, length: sel)
            tv.setSelectedRange(nsRange)
            tv.scrollRangeToVisible(nsRange)          // §7.1/§8: reveal the restored range
            lastText = tv.string
            lastSelection = restore.selection
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let before = lastText
            let beforeSel = lastSelection
            let after = tv.string
            let afterSel = range(tv)
            parent.text = after
            parent.onEdit(RawTextEdit(before: before, beforeSelection: beforeSel,
                                      after: after, afterSelection: afterSel, command: pendingCommand))
            lastText = after
            lastSelection = afterSel
            pendingCommand = nil
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            syncBaseline(tv)
            parent.onFocus()
        }

        func textDidEndEditing(_ notification: Notification) { parent.onBlur() }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, tv.string == lastText else { return }
            let sel = range(tv)
            guard sel != lastSelection else { return }
            lastSelection = sel
            parent.onSelection(sel)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            pendingCommand = deleteCommand(for: selector)
            return false
        }
    }
}
