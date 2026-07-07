import Foundation

/// Something that owns a whole-form value that undo can restore. The setter is
/// expected to carry any side effects (e.g. re-encoding), so undo and redo
/// re-run them exactly as a live edit would.
@MainActor
public protocol FormUndoable: AnyObject {
    var undoableForm: FormState { get set }
}

/// Coordinates whole-form undo (Clear Form, Apply Preset, and their restores)
/// on the window's shared `UndoManager` — the same manager the Basic-mode
/// field editors and the Advanced `NSTextView` register their fine-grained
/// text edits on (FIX-3).
///
/// Those two undo granularities can't safely share a stack: a text-edit action
/// records character *ranges*, and once a whole-form change rewrites the text
/// out from under it, replaying that action reads past the new content —
/// garbled text or a range exception. So a *top-level* whole-form change first
/// clears the manager, replacing the mixed stack with one coherent, whole-form
/// undo. Replays triggered by undo/redo themselves must not clear (that would
/// destroy the redo stack being built), which is why the clear is gated on
/// `isUndoing`/`isRedoing`.
@MainActor
public enum FormUndo {
    /// Change `target`'s form to `newState` as a single undoable step.
    public static func change<T: FormUndoable>(_ target: T,
                                               to newState: FormState,
                                               actionName: String,
                                               undoManager: UndoManager?) {
        let previous = target.undoableForm
        if let undoManager, !undoManager.isUndoing, !undoManager.isRedoing {
            // Drop stale fine-grained text-edit actions before they can replay
            // against content this change replaces wholesale.
            undoManager.removeAllActions()
        }
        target.undoableForm = newState
        registerRestore(target, to: previous, actionName: actionName, undoManager: undoManager)
    }

    private static func registerRestore<T: FormUndoable>(_ target: T,
                                                         to snapshot: FormState,
                                                         actionName: String,
                                                         undoManager: UndoManager?) {
        guard let undoManager else { return }
        // `[weak undoManager]`: the manager retains this action, so a strong
        // capture would cycle and leak the manager plus its snapshots.
        undoManager.registerUndo(withTarget: target) { [weak undoManager] target in
            let current = target.undoableForm
            target.undoableForm = snapshot
            registerRestore(target, to: current, actionName: actionName, undoManager: undoManager)
        }
        undoManager.setActionName(actionName)
    }
}
