import Foundation

public struct FormState: Equatable, Sendable {
    public var mode: FormMode
    public var basic: BasicFields
    public var advanced: String

    public init(mode: FormMode = .basic,
                basic: BasicFields = BasicFields(),
                advanced: String = "") {
        self.mode = mode
        self.basic = basic
        self.advanced = advanced
    }

    /// The HTML to encode for the active mode, or nil when the active form is invalid/empty.
    public var canonicalInput: String? {
        switch mode {
        case .basic:
            return basic.canonicalHTML()
        case .advanced:
            let trimmed = advanced.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    /// The email to leak-check (basic mode only, when valid).
    public var emailForSelfCheck: String? {
        guard mode == .basic else { return nil }
        let trimmed = basic.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return EmailValidator.isValid(trimmed) ? trimmed : nil
    }

    public var activeIsEmpty: Bool {
        switch mode {
        case .basic:
            return basic == BasicFields()
        case .advanced:
            return advanced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public mutating func clearActive() {
        switch mode {
        case .basic: basic = BasicFields()
        case .advanced: advanced = ""
        }
    }

    /// Snapshot of the active mode's values (SPEC §6.7).
    public func payload() -> PresetPayload {
        switch mode {
        case .basic: return .basic(basic)
        case .advanced: return .advanced(advanced)
        }
    }

    /// Restore the form to a saved preset's state.
    public mutating func apply(_ preset: Preset) {
        switch preset.payload {
        case .basic(let fields):
            mode = .basic
            basic = fields
        case .advanced(let text):
            mode = .advanced
            advanced = text
        }
    }
}
