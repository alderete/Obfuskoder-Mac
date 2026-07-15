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

    // Per-mode undo (spec §3/§4: two independent, mode-scoped stacks). Each mode
    // owns an UndoManager (the committed-action stack) and a semantic grouping
    // engine (forms §6 groups). groupsByEvent is off so each committed action is
    // its own step even when two commit in one event (e.g. paste closing a prior
    // typing run). @ObservationIgnored: not observed UI state.
    @ObservationIgnored let basicUndo = UndoManager()
    @ObservationIgnored let advancedUndo = UndoManager()
    var activeUndoManager: UndoManager { form.mode == .basic ? basicUndo : advancedUndo }

    @ObservationIgnored private var basicEngine = UndoGroupingEngine()
    @ObservationIgnored private var advancedEngine = UndoGroupingEngine()

    @ObservationIgnored private lazy var basicRecorder = FormActionRecorder(
        undoManager: basicUndo,
        get: { [weak self] in self?.form ?? FormState() },
        apply: { [weak self] form, focus in self?.applyRestored(form, focus) })
    @ObservationIgnored private lazy var advancedRecorder = FormActionRecorder(
        undoManager: advancedUndo,
        get: { [weak self] in self?.form ?? FormState() },
        apply: { [weak self] form, focus in self?.applyRestored(form, focus) })
    private func recorder(for mode: FormMode) -> FormActionRecorder {
        mode == .basic ? basicRecorder : advancedRecorder
    }

    // Observable mirror of the active mode's manager, so the Edit menu's
    // Undo/Redo titles + enabled state track it. Refreshed via NSUndoManager
    // notifications (which fire when a group closes) plus explicit refreshes
    // after each intake, undo/redo, and mode change.
    @ObservationIgnored private var undoObservers: [NSObjectProtocol] = []
    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var undoTitle = ""
    private(set) var redoTitle = ""

    // Focus/caret to restore after undo/redo, consumed by the field views (§7/§8).
    private(set) var pendingRestore: RestoreTarget?
    func consumePendingRestore() { pendingRestore = nil }

    // Most recently focused field + last known selection per field, for Clear/
    // Apply undo focus (spec §7.3/§7.4).
    @ObservationIgnored private var lastFocusedField: FieldID?
    @ObservationIgnored private var lastSelection: [FieldID: EditSelection] = [:]

    init() {
        for manager in [basicUndo, advancedUndo] {
            manager.groupsByEvent = false
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
        closeActiveGroup()                              // §7.3: close any open text group first
        guard !form.activeIsEmpty else { return }       // §7.3: already-empty ⇒ no-op, no history
        let mode = form.mode
        let before = form
        let focusField = lastFocusedField.map { $0.mode == mode ? $0 : firstField(mode) } ?? firstField(mode)
        let focusSel = lastSelection[focusField] ?? EditSelection(location: 0)
        form.clearActive()
        scheduleEncode()
        grouped(mode) {
            recorder(for: mode).record(
                mode: mode, before: before, after: form, name: UIStrings.clearForm,
                undoFocus: RestoreTarget(field: focusField, selection: focusSel),
                redoFocus: RestoreTarget(field: firstField(mode), selection: EditSelection(location: 0)))
        }
        refreshUndoState()
    }

    func apply(_ preset: Preset, name: String) {
        closeActiveGroup()                              // §7.4: close the SOURCE mode's open group
        let destination: FormMode = { if case .basic = preset.payload { return .basic } else { return .advanced } }()
        let before = form
        form.apply(preset)                              // may switch mode; the switch is not undone
        scheduleEncode()
        // §7.4: identical destination content records nothing and keeps the redo future.
        let changed = destination == .basic ? before.basic != form.basic : before.advanced != form.advanced
        guard changed else { refreshUndoState(); return }
        let priorFocus = lastFocusedField.flatMap { $0.mode == destination ? $0 : nil } ?? firstField(destination)
        grouped(destination) {
            recorder(for: destination).record(
                mode: destination, before: before, after: form, name: UIStrings.undoApply(name),
                undoFocus: RestoreTarget(field: priorFocus, selection: lastSelection[priorFocus] ?? EditSelection(location: 0)),
                redoFocus: RestoreTarget(field: firstField(destination), selection: EditSelection(location: 0)))
        }
        refreshUndoState()
    }

    func undo() {
        closeActiveGroup()                        // §6: end any open text group before undoing
        guard activeUndoManager.canUndo else { return }   // harmless no-op at the bottom
        activeUndoManager.undo(); scheduleEncode(); refreshUndoState()
    }

    func redo() {
        closeActiveGroup()
        guard activeUndoManager.canRedo else { return }
        activeUndoManager.redo(); scheduleEncode(); refreshUndoState()
    }

    /// Mirror the active mode's manager into the observable Edit-menu state. An
    /// open, net-changing text group is undoable "Undo <name>" before it commits,
    /// and while it's open the redo future is suppressed (spec §9).
    func refreshUndoState() {
        let m = activeUndoManager
        let engine = activeEngineSnapshot()
        let openHasChange = engine.openGroupHasNetChange
        let openName = engine.openGroupKind.map(actionName)
        canUndo = openHasChange || m.canUndo
        canRedo = !openHasChange && m.canRedo
        undoTitle = openHasChange
            ? m.undoMenuTitle(forUndoActionName: openName ?? "")
            : m.undoMenuItemTitle
        redoTitle = m.redoMenuItemTitle
    }

    // MARK: - Edit intake (from the field views)

    /// A field view reports a raw edit; classify it, feed the mode's grouping
    /// engine, and register any groups the new edit closes.
    func handleFieldEdit(_ field: FieldID, _ raw: RawTextEdit) {
        let kind = classifyEdit(before: raw.before, beforeSelection: raw.beforeSelection,
                                after: raw.after, afterSelection: raw.afterSelection, command: raw.command)
        let event = TextEditEvent(field: field, kind: kind, before: raw.before,
                                  beforeSelection: raw.beforeSelection,
                                  after: raw.after, afterSelection: raw.afterSelection)
        lastFocusedField = field
        lastSelection[field] = raw.afterSelection
        for committed in mutateEngine(field.mode, { $0.ingest(event) }) { register(committed) }
        refreshUndoState()
    }

    /// A caret/selection move with no text change — ends the open group (spec §6)
    /// without itself creating history.
    func noteSelection(_ field: FieldID, _ selection: EditSelection) {
        lastFocusedField = field
        lastSelection[field] = selection
        if let committed = mutateEngine(field.mode, { $0.endGroup() }) { register(committed) }
        refreshUndoState()
    }

    func noteFocus(_ field: FieldID) { lastFocusedField = field }

    /// Focus left a field — end its open group. Leaving preserves the groups
    /// already formed; it never merges them (spec §6).
    func noteBlur(_ field: FieldID) {
        if let committed = mutateEngine(field.mode, { $0.endGroup() }) { register(committed) }
        refreshUndoState()
    }

    /// Switch modes, ending the source mode's open group first (spec §4). The
    /// switch itself is not undoable and clears neither history.
    func switchMode(to mode: FormMode) {
        guard form.mode != mode else { return }
        if let committed = mutateEngine(form.mode, { $0.endGroup() }) { register(committed) }
        form.mode = mode
        scheduleEncode()
        refreshUndoState()
    }

    // MARK: - Undo plumbing

    /// End the active mode's open text group, registering it if it netted a change.
    private func closeActiveGroup() {
        if let committed = mutateEngine(form.mode, { $0.endGroup() }) { register(committed) }
    }

    /// Register one committed group as a discrete, focus-aware undo step.
    private func register(_ c: CommittedEdit) {
        var before = form; before[c.field] = c.before
        var after = form;  after[c.field] = c.after
        grouped(c.field.mode) {
            recorder(for: c.field.mode).record(
                mode: c.field.mode, before: before, after: after, name: actionName(c.kind),
                undoFocus: RestoreTarget(field: c.field, selection: c.beforeSelection),
                redoFocus: RestoreTarget(field: c.field, selection: c.afterSelection))
        }
    }

    /// Restore the form + request the focus/selection move; used by the recorders.
    private func applyRestored(_ restored: FormState, _ focus: RestoreTarget?) {
        form = restored
        pendingRestore = focus
        scheduleEncode()
    }

    private func actionName(_ kind: EditKind) -> String {
        switch kind {
        case .insert: return UIStrings.undoTyping
        case .deleteBackward, .deleteForward: return UIStrings.undoDelete
        case .cut: return UIStrings.undoCut
        case .paste: return UIStrings.undoPaste
        case .replace: return UIStrings.undoReplace
        case .completeLinkText: return UIStrings.undoCompleteLinkText
        }
    }

    private func firstField(_ mode: FormMode) -> FieldID { mode == .basic ? .email : .advancedHTML }

    /// Mutate the active mode's engine in place (a struct can't be a computed lvalue).
    private func mutateEngine<R>(_ mode: FormMode, _ body: (inout UndoGroupingEngine) -> R) -> R {
        mode == .basic ? body(&basicEngine) : body(&advancedEngine)
    }
    private func activeEngineSnapshot() -> UndoGroupingEngine { form.mode == .basic ? basicEngine : advancedEngine }

    /// Wrap a single registration in its own undo group (groupsByEvent is off, so
    /// each committed action becomes one discrete step).
    private func grouped(_ mode: FormMode, _ body: () -> Void) {
        let mgr = mode == .basic ? basicUndo : advancedUndo
        mgr.beginUndoGrouping()
        body()
        mgr.endUndoGrouping()
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
