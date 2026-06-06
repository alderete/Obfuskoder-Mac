import Foundation

public enum PresetPayload: Codable, Equatable, Sendable {
    case basic(BasicFields)
    case advanced(String)
}

public struct Preset: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var payload: PresetPayload
    public init(id: UUID = UUID(), name: String, payload: PresetPayload) {
        self.id = id
        self.name = name
        self.payload = payload
    }
}
