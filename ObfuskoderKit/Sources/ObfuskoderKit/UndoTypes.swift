import Foundation

/// A caret (length 0) or ranged selection, in UTF-16 offsets to match AppKit's
/// `NSRange`.
public struct EditSelection: Equatable, Sendable {
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
    public var beforeSelection: EditSelection
    public var after: String
    public var afterSelection: EditSelection
    public var command: EditCommand?
    public init(before: String, beforeSelection: EditSelection,
                after: String, afterSelection: EditSelection,
                command: EditCommand? = nil) {
        self.before = before
        self.beforeSelection = beforeSelection
        self.after = after
        self.afterSelection = afterSelection
        self.command = command
    }
}

/// A classified edit ready for grouping.
public struct TextEditEvent: Sendable {
    public var field: FieldID
    public var kind: EditKind
    public var before: String
    public var beforeSelection: EditSelection
    public var after: String
    public var afterSelection: EditSelection
    public init(field: FieldID, kind: EditKind, before: String,
                beforeSelection: EditSelection, after: String, afterSelection: EditSelection) {
        self.field = field
        self.kind = kind
        self.before = before
        self.beforeSelection = beforeSelection
        self.after = after
        self.afterSelection = afterSelection
    }
}

/// Where a restore should place first responder + caret/selection (spec §7/§8).
public struct RestoreTarget: Equatable, Sendable {
    public var field: FieldID
    public var selection: EditSelection
    public init(field: FieldID, selection: EditSelection) {
        self.field = field
        self.selection = selection
    }
}

/// A closed, net-changing group ready to register as one undo action.
public struct CommittedEdit: Equatable, Sendable {
    public var field: FieldID
    public var kind: EditKind
    public var before: String
    public var beforeSelection: EditSelection
    public var after: String
    public var afterSelection: EditSelection
    public init(field: FieldID, kind: EditKind, before: String,
                beforeSelection: EditSelection, after: String, afterSelection: EditSelection) {
        self.field = field
        self.kind = kind
        self.before = before
        self.beforeSelection = beforeSelection
        self.after = after
        self.afterSelection = afterSelection
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
