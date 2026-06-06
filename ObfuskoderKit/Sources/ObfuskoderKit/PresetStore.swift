import Foundation
import Observation

public enum PresetError: Error, Equatable {
    case duplicateName(String)
    case notFound
}

@MainActor
@Observable
public final class PresetStore {
    public private(set) var presets: [Preset] = []
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public func save(name: String, payload: PresetPayload) throws -> Preset {
        try ensureNameAvailable(name, excluding: nil)
        let preset = Preset(name: name, payload: payload)
        presets.append(preset)
        try persist()
        return preset
    }

    public func replace(id: UUID, name: String, payload: PresetPayload) throws {
        guard let idx = presets.firstIndex(where: { $0.id == id }) else { throw PresetError.notFound }
        try ensureNameAvailable(name, excluding: id)
        presets[idx].name = name
        presets[idx].payload = payload
        try persist()
    }

    public func rename(id: UUID, to newName: String) throws {
        guard let idx = presets.firstIndex(where: { $0.id == id }) else { throw PresetError.notFound }
        try ensureNameAvailable(newName, excluding: id)
        presets[idx].name = newName
        try persist()
    }

    public func delete(id: UUID) throws {
        guard let idx = presets.firstIndex(where: { $0.id == id }) else { throw PresetError.notFound }
        presets.remove(at: idx)
        try persist()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Replicate MutableCollection.move(fromOffsets:toOffset:) without SwiftUI dependency
        var result = presets
        let moved = source.map { result[$0] }
        // Remove from highest index first to preserve indices
        for idx in source.reversed() {
            result.remove(at: idx)
        }
        // Adjust destination for removed elements below it
        let adjustedDest = destination - source.filter { $0 < destination }.count
        result.insert(contentsOf: moved, at: adjustedDest)
        presets = result
        try? persist()
    }

    public func nameExists(_ name: String) -> Bool {
        presets.contains { $0.name == name }
    }

    private func ensureNameAvailable(_ name: String, excluding id: UUID?) throws {
        if presets.contains(where: { $0.name == name && $0.id != id }) {
            throw PresetError.duplicateName(name)
        }
    }

    private func persist() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(presets)
        try data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Preset].self, from: data) else { return }
        presets = decoded
    }
}
