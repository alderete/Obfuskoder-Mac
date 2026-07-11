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

    // Observable mirror of the active mode's manager, so the Edit menu's
    // Undo/Redo titles + enabled state track it. Refreshed via NSUndoManager
    // notifications (which fire when event-grouped actions close) plus explicit
    // refreshes after undo/redo and on mode change.
    @ObservationIgnored private var undoObservers: [NSObjectProtocol] = []
    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var undoTitle = ""
    private(set) var redoTitle = ""
    // Two-level text-edit undo. Within a field session, typing pauses append to
    // `history` and Cmd-Z steps back through it (undo WITHIN the field). On
    // leaving the field the whole session collapses into ONE step on the mode
    // manager (cross-field undo is one step per field). history[0] is the
    // focus-in baseline; `index` is the current position; entries past `index`
    // are the redo future.
    @ObservationIgnored private var history: [FormState] = []
    @ObservationIgnored private var index = 0
    @ObservationIgnored private var editBurstIdle: Task<Void, Never>?
    private var inSession: Bool { !history.isEmpty }
    private var sessionCanUndo: Bool { inSession && (index > 0 || form != history[index]) }
    private var sessionCanRedo: Bool { inSession && form == history[index] && index < history.count - 1 }

    init() {
        for manager in [basicUndo, advancedUndo] {
            for name: NSNotification.Name in [.NSUndoManagerDidCloseUndoGroup,
                                              .NSUndoManagerDidUndoChange,
                                              .NSUndoManagerDidRedoChange] {
                undoObservers.append(NotificationCenter.default.addObserver(
                    forName: name, object: manager, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refreshUndoState() }
                })
            }
        }
        refreshUndoState()
    }
    // No deinit cleanup needed: AppModel lives for the whole app session, and the
    // observers capture [weak self]. (A nonisolated deinit can't touch the
    // MainActor-isolated observer tokens under Swift 6 anyway.)

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
        endEditBurst()          // finalize any in-progress typing as its own step first
        guard !form.activeIsEmpty else { return }
        let previous = form
        form.clearActive()
        scheduleEncode()
        activeRecorder.record(previous: previous, actionName: UIStrings.clearForm)
        refreshUndoState()
    }

    func apply(_ preset: Preset) {
        endEditBurst()          // finalize any in-progress typing as its own step first
        let previous = form
        form.apply(preset)                 // may switch mode; the switch is not undone
        scheduleEncode()
        // activeRecorder follows form.mode — which apply just set — so this records
        // on the target mode's manager and restores that mode's prior content on undo.
        activeRecorder.record(previous: previous, actionName: UIStrings.applySavedValues)
        refreshUndoState()
    }

    func undo() {
        if sessionCanUndo {                       // within-field: step back through history
            editBurstIdle?.cancel(); editBurstIdle = nil
            appendCheckpoint()                    // fold any un-paused typing into a step first
            index -= 1
            restoreSlice(history[index])
            scheduleEncode(); refreshUndoState()
            return
        }
        endEditBurst()                            // else: collapse session, undo on the mode manager
        activeUndoManager.undo(); scheduleEncode(); refreshUndoState()
    }

    func redo() {
        if sessionCanRedo {                       // within-field redo
            index += 1
            restoreSlice(history[index])
            scheduleEncode(); refreshUndoState()
            return
        }
        endEditBurst()
        activeUndoManager.redo(); scheduleEncode(); refreshUndoState()
    }

    /// Mirror the active mode's manager into the observable Edit-menu state.
    func refreshUndoState() {
        let m = activeUndoManager
        canUndo = sessionCanUndo || m.canUndo
        canRedo = sessionCanRedo || m.canRedo
        undoTitle = sessionCanUndo ? UIStrings.undoTyping : m.undoMenuItemTitle
        redoTitle = sessionCanRedo ? UIStrings.redoTyping : m.redoMenuItemTitle
    }

    /// Begin a per-field editing session (focus-in), capturing the pre-edit
    /// baseline as history[0]. Idempotent within a session.
    func beginEditBurst() {
        guard history.isEmpty else { return }
        history = [form]
        index = 0
    }

    /// Each keystroke re-arms an idle timer; a typing PAUSE records a within-field
    /// checkpoint (Cmd-Z can step back to it) — this gives undo inside the
    /// single-field Advanced editor, where you never leave to commit.
    func noteEdit() {
        if history.isEmpty { history = [form]; index = 0 }  // safety if focus-in was missed
        editBurstIdle?.cancel()
        editBurstIdle = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            if Task.isCancelled { return }
            self?.checkpoint()
        }
    }

    private func checkpoint() { appendCheckpoint(); refreshUndoState() }

    private func appendCheckpoint() {
        guard inSession, form != history[index] else { return }
        if index < history.count - 1 { history.removeLast(history.count - 1 - index) }  // drop redo future
        history.append(form)
        index += 1
    }

    /// Leaving the field (focus-out) collapses the whole session into ONE step on
    /// the mode manager, so cross-field undo is one step per field.
    func endEditBurst() {
        editBurstIdle?.cancel()
        editBurstIdle = nil
        guard !history.isEmpty else { return }
        let baseline = history[0]
        history = []
        index = 0
        guard baseline != form else { return }
        let recorder = baseline.mode == .basic ? basicRecorder : advancedRecorder
        recorder.record(previous: baseline, actionName: UIStrings.typing)
        refreshUndoState()
    }

    /// Restore only the active mode's content slice, matching FormUndoRecorder.
    private func restoreSlice(_ snapshot: FormState) {
        switch form.mode {
        case .basic: form.basic = snapshot.basic
        case .advanced: form.advanced = snapshot.advanced
        }
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
