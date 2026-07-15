import Foundation

/// A caret (length 0) or ranged selection, in UTF-16 offsets to match AppKit's
/// `NSRange`.
public struct TextSelection: Equatable, Sendable {
    public var location: Int
    public var length: Int
    public init(location: Int, length: Int = 0) {
        self.location = location
        self.length = length
    }
}

/// Identifies an editable field across both modes' form histories.
public enum FieldID: Hashable, Sendable {
    case email, linkText, linkTitle, subject   // Basic
    case advancedHTML                          // Advanced

    /// Which mode's history this field belongs to.
    public var mode: FormMode { self == .advancedHTML ? .advanced : .basic }
}

/// The semantic class of a single edit (spec §6/§10).
public enum EditKind: Equatable, Sendable {
    case insert, deleteBackward, deleteForward
    case cut, paste, replace, completeLinkText

    /// Discrete kinds are always their own single-action group and never coalesce.
    public var isDiscrete: Bool {
        switch self {
        case .insert, .deleteBackward, .deleteForward: return false
        case .cut, .paste, .replace, .completeLinkText: return true
        }
    }
}

/// A hint from the AppKit capture layer when the originating command is known.
public enum EditCommand: Sendable {
    case deleteBackward, deleteForward, cut, paste, completeLinkText
}

/// Raw before/after captured by a view before classification.
public struct RawTextEdit: Sendable {
    public var before: String
    public var beforeSelection: TextSelection
    public var after: String
    public var afterSelection: TextSelection
    public var command: EditCommand?
    public init(before: String, beforeSelection: TextSelection,
                after: String, afterSelection: TextSelection,
                command: EditCommand? = nil) {
        self.before = before
        self.beforeSelection = beforeSelection
        self.after = after
        self.afterSelection = afterSelection
        self.command = command
    }
}

extension FormState {
    /// Read/write one field's text by identity, so undo records stay generic.
    public subscript(field: FieldID) -> String {
        get {
            switch field {
            case .email: return basic.email
            case .linkText: return basic.linkText
            case .linkTitle: return basic.linkTitle
            case .subject: return basic.subject
            case .advancedHTML: return advanced
            }
        }
        set {
            switch field {
            case .email: basic.email = newValue
            case .linkText: basic.linkText = newValue
            case .linkTitle: basic.linkTitle = newValue
            case .subject: basic.subject = newValue
            case .advancedHTML: advanced = newValue
            }
        }
    }
}
