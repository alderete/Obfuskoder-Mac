import Foundation

/// Registers undoable form actions as mode-slice snapshots that also carry the
/// focus/caret to restore (spec §7/§8). Undo restores `before` + `undoFocus`;
/// the automatically-registered redo restores `after` + `redoFocus`. Restoring
/// only the action's mode slice preserves the inactive mode and never reverses a
/// mode switch (ADR §5). `UndoManager` is Foundation, so this stays
/// unit-testable; the app owns one recorder per mode, each wired to that mode's
/// `UndoManager`.
@MainActor
public final class FormActionRecorder {
    private let undoManager: UndoManager
    private let getForm: () -> FormState
    private let apply: (FormState, RestoreTarget?) -> Void

    public init(undoManager: UndoManager,
                get: @escaping () -> FormState,
                apply: @escaping (FormState, RestoreTarget?) -> Void) {
        self.undoManager = undoManager
        self.getForm = get
        self.apply = apply
    }

    /// Register one undoable action that restores `mode`'s content slice.
    /// Undo applies `before` + `undoFocus`; redo applies `after` + `redoFocus`.
    public func record(mode: FormMode, before: FormState, after: FormState,
                       name: String, undoFocus: RestoreTarget?, redoFocus: RestoreTarget?) {
        undoManager.registerUndo(withTarget: self) { rec in
            MainActor.assumeIsolated {
                rec.restore(before, mode: mode, focus: undoFocus)
                // Symmetric redo: reverse the direction and re-register the undo.
                rec.record(mode: mode, before: after, after: before,
                           name: name, undoFocus: redoFocus, redoFocus: undoFocus)
            }
        }
        undoManager.setActionName(name)
    }

    private func restore(_ snapshot: FormState, mode: FormMode, focus: RestoreTarget?) {
        var next = getForm()
        switch mode {
        case .basic:    next.basic = snapshot.basic
        case .advanced: next.advanced = snapshot.advanced
        }
        apply(next, focus)
    }
}
