import Foundation

/// Classify a raw edit into a semantic `EditKind`. An explicit command hint from
/// the capture layer always wins; otherwise infer from the before/after diff.
public func classifyEdit(before: String, beforeSelection: EditSelection,
                         after: String, afterSelection: EditSelection,
                         command: EditCommand?) -> EditKind {
    switch command {
    case .deleteBackward: return .deleteBackward
    case .deleteForward:  return .deleteForward
    case .cut:            return .cut
    case .paste:          return .paste
    case .completeLinkText: return .completeLinkText
    case nil: break
    }
    // No explicit command: infer from the diff.
    if beforeSelection.length > 0, before != after { return .replace }
    let beforeCount = before.count, afterCount = after.count
    if afterCount > beforeCount { return afterCount - beforeCount > 1 ? .paste : .insert }
    if afterCount < beforeCount {
        return afterSelection.location < beforeSelection.location ? .deleteBackward : .deleteForward
    }
    return .replace   // same length, changed content ⇒ selection replacement
}
