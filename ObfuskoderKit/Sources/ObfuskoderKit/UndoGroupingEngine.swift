import Foundation

/// Forms semantic undo groups from a stream of classified edits (spec §6).
/// Pure and value-typed: no timers, no AppKit. One instance per mode, so Basic
/// and Advanced coalesce by exactly the same rules. A group extends only while
/// the next edit continues the same kind at the same evolving insertion point;
/// any discontinuity — different field, different kind, a caret/selection jump,
/// or a discrete command — closes it.
public struct UndoGroupingEngine: Sendable {
    private struct OpenGroup {
        var field: FieldID
        var kind: EditKind
        var before: String
        var beforeSelection: EditSelection
        var after: String
        var afterSelection: EditSelection
    }
    private var open: OpenGroup?

    public init() {}

    public var openGroupKind: EditKind? { open?.kind }
    public var openGroupHasNetChange: Bool { open.map { $0.before != $0.after } ?? false }
    public var hasOpenGroupPublic: Bool { open != nil }

    /// Ingest one classified edit. Returns the edits committed as a result:
    /// closing a prior coalescing group can commit one, and a discrete edit
    /// commits itself immediately (so up to two).
    public mutating func ingest(_ e: TextEditEvent) -> [CommittedEdit] {
        var committed: [CommittedEdit] = []
        if e.kind.isDiscrete {
            if let c = close() { committed.append(c) }
            open = nil
            if e.before != e.after {
                committed.append(CommittedEdit(field: e.field, kind: e.kind,
                    before: e.before, beforeSelection: e.beforeSelection,
                    after: e.after, afterSelection: e.afterSelection))
            }
            return committed
        }
        if let g = open, canExtend(g, with: e) {
            open!.after = e.after
            open!.afterSelection = e.afterSelection
        } else {
            if let c = close() { committed.append(c) }
            open = OpenGroup(field: e.field, kind: e.kind, before: e.before,
                             beforeSelection: e.beforeSelection,
                             after: e.after, afterSelection: e.afterSelection)
        }
        return committed
    }

    /// Close the open group at a boundary (selection move, focus/mode change,
    /// form op, undo/redo). Returns the committed edit if it netted a change.
    public mutating func endGroup() -> CommittedEdit? {
        let c = close()
        open = nil
        return c
    }

    private func canExtend(_ g: OpenGroup, with e: TextEditEvent) -> Bool {
        g.field == e.field && g.kind == e.kind
            && g.after == e.before && g.afterSelection == e.beforeSelection
    }

    private func close() -> CommittedEdit? {
        guard let g = open, g.before != g.after else { return nil }
        return CommittedEdit(field: g.field, kind: g.kind, before: g.before,
            beforeSelection: g.beforeSelection, after: g.after, afterSelection: g.afterSelection)
    }
}
