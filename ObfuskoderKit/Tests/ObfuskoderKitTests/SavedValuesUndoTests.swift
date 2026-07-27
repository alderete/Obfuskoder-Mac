import Testing
import Foundation
@testable import ObfuskoderKit

@MainActor
private func seeded() throws -> (PresetStore, SavedValuesUndo, [Preset]) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("obfuskoder-svu-\(UUID().uuidString)", isDirectory: true)
    let store = PresetStore(fileURL: dir.appendingPathComponent("presets.json"))
    let a = try store.save(name: "A", payload: .advanced("a"))
    let b = try store.save(name: "B", payload: .advanced("b"))
    let c = try store.save(name: "C", payload: .advanced("c"))
    return (store, SavedValuesUndo(store: store), [a, b, c])
}

@MainActor @Test func deleteUndoRestoresAtIndex() throws {
    let (store, undo, p) = try seeded()
    try undo.delete(id: p[1].id, actionName: "Delete B")
    #expect(store.presets.map(\.id) == [p[0].id, p[2].id])
    #expect(undo.canUndo)
    undo.undo()
    #expect(store.presets.map(\.id) == [p[0].id, p[1].id, p[2].id])
}

@MainActor @Test func deleteRedoDeletesAgain() throws {
    let (store, undo, p) = try seeded()
    try undo.delete(id: p[1].id, actionName: "Delete B")
    undo.undo()
    #expect(undo.canRedo)
    undo.redo()
    #expect(store.presets.map(\.id) == [p[0].id, p[2].id])
}

@MainActor @Test func reorderUndoRestoresOrder() throws {
    let (store, undo, p) = try seeded()
    undo.move(fromOffsets: IndexSet(integer: 0), toOffset: 3, actionName: "Move A")
    #expect(store.presets.map(\.id) == [p[1].id, p[2].id, p[0].id])
    undo.undo()
    #expect(store.presets.map(\.id) == [p[0].id, p[1].id, p[2].id])
    undo.redo()
    #expect(store.presets.map(\.id) == [p[1].id, p[2].id, p[0].id])
}

@MainActor @Test func renameBetweenDeleteAndUndoIsPreserved() throws {
    let (store, undo, p) = try seeded()
    try undo.delete(id: p[0].id, actionName: "Delete A")
    try store.rename(id: p[2].id, to: "C-renamed")
    undo.undo()
    #expect(store.presets.first(where: { $0.id == p[2].id })?.name == "C-renamed")
    #expect(store.presets.contains { $0.id == p[0].id })
}

@MainActor @Test func emptyStackIsNoOp() throws {
    let (_, undo, _) = try seeded()
    #expect(!undo.canUndo)
    #expect(!undo.canRedo)
    undo.undo()
    undo.redo()
}

@MainActor @Test func resetClearsStack() throws {
    let (_, undo, p) = try seeded()
    try undo.delete(id: p[0].id, actionName: "Delete A")
    #expect(undo.canUndo)
    undo.reset()
    #expect(!undo.canUndo)
}
