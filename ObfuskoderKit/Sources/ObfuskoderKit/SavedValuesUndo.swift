import Foundation

/// Per-session undo/redo for saved-value DELETE and REORDER, on a stack
/// separate from the form undo. Registers granular inverse operations so
/// interleaved renames (which use native field undo) are never clobbered.
/// The caller supplies the localized action name.
///
/// Grouping uses the default `groupsByEvent = true`: each user action (a
/// delete, a drag/Move, or a menu undo) is a single run-loop event and so
/// becomes exactly one undo step — no explicit grouping needed.
@MainActor
public final class SavedValuesUndo {
    private let store: PresetStore
    private let undoManager: UndoManager

    public init(store: PresetStore, undoManager: UndoManager = UndoManager()) {
        self.store = store
        self.undoManager = undoManager
    }

    public var canUndo: Bool { undoManager.canUndo }
    public var canRedo: Bool { undoManager.canRedo }
    public var undoMenuItemTitle: String { undoManager.undoMenuItemTitle }
    public var redoMenuItemTitle: String { undoManager.redoMenuItemTitle }

    public func undo() { if undoManager.canUndo { undoManager.undo() } }
    public func redo() { if undoManager.canRedo { undoManager.redo() } }
    public func reset() { undoManager.removeAllActions() }

    // MARK: Delete

    public func delete(id: UUID, actionName: String) throws {
        guard let index = store.presets.firstIndex(where: { $0.id == id }) else {
            throw PresetError.notFound
        }
        let preset = store.presets[index]
        try store.delete(id: id)
        registerReinsert(preset: preset, index: index, name: actionName)
    }

    /// State just became "deleted"; register the UNDO that re-inserts.
    private func registerReinsert(preset: Preset, index: Int, name: String) {
        undoManager.setActionName(name)
        undoManager.registerUndo(withTarget: self) { target in
            target.store.insert(preset, at: index)
            target.registerRedelete(preset: preset, index: index, name: name)
        }
    }

    /// State just became "re-inserted" (an undo); register the REDO that deletes.
    private func registerRedelete(preset: Preset, index: Int, name: String) {
        undoManager.setActionName(name)
        undoManager.registerUndo(withTarget: self) { target in
            try? target.store.delete(id: preset.id)
            target.registerReinsert(preset: preset, index: index, name: name)
        }
    }

    // MARK: Reorder

    public func move(fromOffsets source: IndexSet, toOffset destination: Int, actionName: String) {
        let previous = store.presets.map(\.id)
        store.move(fromOffsets: source, toOffset: destination)
        let current = store.presets.map(\.id)
        registerReorder(restore: previous, reapply: current, name: actionName)
    }

    /// Order just changed; register the UNDO that restores `restore`, whose
    /// handler in turn sets up the REDO that restores `reapply`.
    private func registerReorder(restore: [UUID], reapply: [UUID], name: String) {
        undoManager.setActionName(name)
        undoManager.registerUndo(withTarget: self) { target in
            target.store.setOrder(restore)
            target.registerReorder(restore: reapply, reapply: restore, name: name)
        }
    }
}
