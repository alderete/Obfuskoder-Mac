import SwiftUI
import AppKit

/// NSTextView wrapper for the Advanced HTML field: monospaced, spell/substitution-free, scrollable.
struct MacTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onChange: () -> Void = {}
    var onEditBegin: () -> Void = {}
    var onEditEnd: () -> Void = {}

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
        // Undo is model-owned (per-mode snapshots); native NSTextView undo would
        // double-register on a manager we don't drive. See undo-routing-findings.
        textView.allowsUndo = false
        textView.selectedTextAttributes = [.backgroundColor: NSColor.appTextSelection]
        textView.textContainerInset = NSSize(width: 4, height: 6)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MacTextEditor
        init(_ parent: MacTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onChange()
        }

        func textDidBeginEditing(_ notification: Notification) { parent.onEditBegin() }
        func textDidEndEditing(_ notification: Notification) { parent.onEditEnd() }
    }
}
