import Foundation

/// Enforces the no-`@` guarantee for the fallback message at the input layer
/// (SPEC: an `@` in the fallback fails the encoder self-check on every attempt).
public enum FallbackSanitizer {
    /// Removes every "@" from a proposed edit and returns the cursor position
    /// adjusted for the characters removed before it. Offsets are UTF-16 code
    /// units, matching the NSRange values AppKit field editors use.
    public static func strippingAtSigns(from text: String, cursor: Int) -> (text: String, cursor: Int) {
        let atSign = UInt16(("@" as Unicode.Scalar).value)
        let units = Array(text.utf16)
        let clamped = min(max(cursor, 0), units.count)
        let removedBeforeCursor = units[..<clamped].filter { $0 == atSign }.count
        let kept = units.filter { $0 != atSign }
        return (String(decoding: kept, as: UTF16.self), clamped - removedBeforeCursor)
    }
}
