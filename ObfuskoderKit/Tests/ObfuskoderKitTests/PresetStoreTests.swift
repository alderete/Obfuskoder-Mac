import Testing
import Foundation
@testable import ObfuskoderKit

@MainActor
private func tempStore() -> (PresetStore, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("obfuskoder-tests-\(UUID().uuidString)", isDirectory: true)
    let url = dir.appendingPathComponent("presets.json")
    return (PresetStore(fileURL: url), url)
}

@MainActor @Test func savesWithUniqueName() throws {
    let (store, _) = tempStore()
    let p = try store.save(name: "Personal", payload: .advanced("<b>hi</b>"))
    #expect(store.presets.count == 1)
    #expect(store.presets.first == p)
}

@MainActor @Test func rejectsDuplicateName() throws {
    let (store, _) = tempStore()
    _ = try store.save(name: "Dup", payload: .advanced("a"))
    #expect(throws: PresetError.duplicateName("Dup")) {
        _ = try store.save(name: "Dup", payload: .advanced("b"))
    }
}

@MainActor @Test func replaceUpdatesExisting() throws {
    let (store, _) = tempStore()
    let p = try store.save(name: "P", payload: .advanced("a"))
    try store.replace(id: p.id, name: "P", payload: .advanced("b"))
    #expect(store.presets.first?.payload == .advanced("b"))
}

@MainActor @Test func renameAndDelete() throws {
    let (store, _) = tempStore()
    let p = try store.save(name: "Old", payload: .advanced("a"))
    try store.rename(id: p.id, to: "New")
    #expect(store.presets.first?.name == "New")
    try store.delete(id: p.id)
    #expect(store.presets.isEmpty)
}

@MainActor @Test func renameToExistingNameThrows() throws {
    let (store, _) = tempStore()
    _ = try store.save(name: "A", payload: .advanced("a"))
    let b = try store.save(name: "B", payload: .advanced("b"))
    #expect(throws: PresetError.duplicateName("A")) {
        try store.rename(id: b.id, to: "A")
    }
}

@MainActor @Test func persistsAcrossReload() throws {
    let (store, url) = tempStore()
    _ = try store.save(name: "Keep", payload: .advanced("data"))
    let reloaded = PresetStore(fileURL: url)
    #expect(reloaded.presets.count == 1)
    #expect(reloaded.presets.first?.name == "Keep")
}

@MainActor @Test func reordersPresets() throws {
    let (store, _) = tempStore()
    _ = try store.save(name: "1", payload: .advanced("a"))
    _ = try store.save(name: "2", payload: .advanced("b"))
    store.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
    #expect(store.presets.map(\.name) == ["2", "1"])
}
