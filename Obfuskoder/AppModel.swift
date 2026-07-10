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

    // Per-mode undo (SPEC §3: two independent, mode-scoped stacks). Each mode's
    // fields, Clear, and Apply register on its own manager; mode switching is
    // never undoable. @ObservationIgnored: not observed UI state.
    @ObservationIgnored let basicUndo = UndoManager()
    @ObservationIgnored let advancedUndo = UndoManager()
    var activeUndoManager: UndoManager { form.mode == .basic ? basicUndo : advancedUndo }
    @ObservationIgnored private lazy var basicRecorder = FormUndoRecorder(
        undoManager: basicUndo,
        get: { [weak self] in self?.form ?? FormState() },
        set: { [weak self] in self?.form = $0 })
    @ObservationIgnored private lazy var advancedRecorder = FormUndoRecorder(
        undoManager: advancedUndo,
        get: { [weak self] in self?.form ?? FormState() },
        set: { [weak self] in self?.form = $0 })
    private var activeRecorder: FormUndoRecorder {
        form.mode == .basic ? basicRecorder : advancedRecorder
    }

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

    func clearActiveForm() {
        guard !form.activeIsEmpty else { return }
        let previous = form
        form.clearActive()
        scheduleEncode()
        activeRecorder.record(previous: previous, actionName: UIStrings.clearForm)
    }

    func apply(_ preset: Preset) {
        let previous = form
        form.apply(preset)                 // may switch mode; the switch is not undone
        scheduleEncode()
        // activeRecorder follows form.mode — which apply just set — so this records
        // on the target mode's manager and restores that mode's prior content on undo.
        activeRecorder.record(previous: previous, actionName: UIStrings.applySavedValues)
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
