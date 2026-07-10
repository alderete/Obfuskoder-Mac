import Foundation

/// Records form-content changes as snapshot-based undo steps on a caller-provided
/// `UndoManager`. Undo restores the prior CONTENT but always keeps the *current*
/// mode — mode switching is never undoable (SPEC §3). A symmetric redo is
/// registered automatically. Pure and UI-framework-free so it is unit-testable
/// (same pattern as `PreviewNavigationPolicy`); the app owns one recorder per
/// mode, each wired to that mode's `UndoManager`.
@MainActor
public final class FormUndoRecorder {
    private let undoManager: UndoManager
    private let getForm: () -> FormState
    private let setForm: (FormState) -> Void

    public init(undoManager: UndoManager,
                get: @escaping () -> FormState,
                set: @escaping (FormState) -> Void) {
        self.undoManager = undoManager
        self.getForm = get
        self.setForm = set
    }

    /// Register the transition from `previous` to the current form as one undo
    /// step named `actionName`. Undo restores `previous`'s content (mode kept);
    /// the automatically-registered redo restores the current content.
    public func record(previous: FormState, actionName: String) {
        let current = getForm()
        undoManager.registerUndo(withTarget: self) { recorder in
            MainActor.assumeIsolated {
                recorder.restore(content: previous)
                recorder.record(previous: current, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
    }

    /// Restore a snapshot's content while preserving the current mode, so undo
    /// never switches modes.
    private func restore(content snapshot: FormState) {
        var next = snapshot
        next.mode = getForm().mode
        setForm(next)
    }
}
