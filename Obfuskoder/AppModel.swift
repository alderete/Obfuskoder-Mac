import SwiftUI
import Observation
import AppKit
import ObfuskoderKit

enum ResultState: Equatable {
    case empty
    case snippet(Snippet)
    case failure
}

@MainActor
@Observable
final class AppModel {
    var form = FormState()
    var showDecodedSource = false
    private(set) var result: ResultState = .empty
    private(set) var showCopiedFeedback = false
    /// Increments per copy so the UI can pulse on every copy, including
    /// repeat copies inside the feedback window (COLOR-3).
    private(set) var copyCount = 0

    var debounceSeconds: Double = AppConfig.defaultDebounceSeconds
    var fallbackMessage: String = AppConfig.defaultFallbackMessage

    private var encodeTask: Task<Void, Never>?
    private var copyFeedbackTask: Task<Void, Never>?

    /// Call whenever the form, debounce, or fallback changes.
    func scheduleEncode() {
        encodeTask?.cancel()
        guard let input = form.canonicalInput else {
            result = .empty
            return
        }
        let email = form.emailForSelfCheck
        let fallback = fallbackMessage
        let delay = debounceSeconds

        encodeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            let engine = ObfuskodeEngine(fallbackMessage: fallback)
            let outcome: ResultState
            do {
                let snippet = try await Task.detached(priority: .userInitiated) {
                    try engine.encode(input, email: email)
                }.value
                outcome = .snippet(snippet)
            } catch {
                outcome = .failure
            }
            if Task.isCancelled { return }
            self?.result = outcome
        }
    }

    var snippetText: String? {
        if case .snippet(let s) = result { return s.html }
        return nil
    }

    var decodedSource: String? {
        if case .snippet(let s) = result { return s.decodedSource }
        return nil
    }

    func clearActiveForm(undoManager: UndoManager?) {
        guard !form.activeIsEmpty else { return }
        let previous = form
        form.clearActive()
        scheduleEncode()
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreForm(previous, undoManager: undoManager)
        }
        undoManager?.setActionName(UIStrings.clearForm)
    }

    func restoreForm(_ snapshot: FormState, undoManager: UndoManager?) {
        let current = form
        form = snapshot
        scheduleEncode()
        undoManager?.registerUndo(withTarget: self) { target in
            target.restoreForm(current, undoManager: undoManager)
        }
        undoManager?.setActionName(UIStrings.clearForm)
    }

    func apply(_ preset: Preset) {
        form.apply(preset)
        scheduleEncode()
    }

    /// Copy the current snippet to the pasteboard and flash transient "Copied" feedback.
    /// Shared by the Copy button and the Copy Snippet (⇧⌘C) menu command.
    func copySnippet() {
        guard let html = snippetText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(html, forType: .string)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: UIStrings.copied])
        showCopiedFeedback = true
        copyCount += 1
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { return }
            self?.showCopiedFeedback = false
        }
    }
}
