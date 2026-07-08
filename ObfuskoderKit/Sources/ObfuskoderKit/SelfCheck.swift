import Foundation
import JavaScriptCore

public enum SelfCheckError: Error, Equatable {
    /// The fallback message contains the input or the email — deterministic;
    /// the user must change the fallback (or the input).
    case fallbackContainsPlaintext
    /// Plaintext found in the snippet outside the fallback (encoder bug).
    case plaintextLeak
    case atSignPresent
    case roundTripMismatch(recovered: String)
    case engineError(String)
}

enum SelfCheck {
    /// ENC-2 + ENC-3 (SPEC §7.3).
    static func verifyStringProperties(_ artifact: EncodedArtifact, email: String?) throws {
        // ENC-2: plaintext can only surface in the fallback text — the input
        // is encoded to numbers, the ids are random, and the decoder skeleton
        // is fixed. Incidental substring matches are not leaks (SPEC §7.1),
        // so the input counts only when it reads as standalone text in the
        // fallback ("hello" in "well hello there"), not as a fragment of an
        // unrelated word ("a" in "JavaScript").
        if containsStandalone(artifact.input, in: artifact.fallback) {
            throw SelfCheckError.fallbackContainsPlaintext
        }
        if let email, !email.isEmpty {
            // The raw email is categorical: any occurrence in the fallback is
            // a leak (a real address can't appear incidentally).
            if artifact.fallback.contains(email) {
                throw SelfCheckError.fallbackContainsPlaintext
            }
            // Defense-in-depth: the raw email anywhere else in the snippet is
            // an encoder bug, not a retryable random collision.
            if artifact.html.contains(email) { throw SelfCheckError.plaintextLeak }
        }
        if artifact.html.contains("@") { throw SelfCheckError.atSignPresent }  // ENC-3
    }

    /// ENC-1 + ENC-2 + ENC-3.
    static func verify(_ artifact: EncodedArtifact, email: String?) throws {
        try verifyStringProperties(artifact, email: email)
        try verifyRoundTrip(artifact)
    }

    /// ENC-1: execute the decoder against a faked `document` in JavaScriptCore and
    /// confirm the recovered string equals the input verbatim (SPEC §7.3).
    static func verifyRoundTrip(_ artifact: EncodedArtifact) throws {
        guard let context = JSContext() else {
            throw SelfCheckError.engineError("could not create JSContext")
        }
        var thrown: String?
        context.exceptionHandler = { _, value in thrown = value?.toString() }

        let spanID = artifact.spanID
        let scriptID = artifact.scriptID

        let harness = """
        var __captured = null;
        var document = {
            _e: {},
            getElementById: function(id) { return this._e[id] || null; }
        };
        document._e["\(spanID)"] = {
            set outerHTML(v) { __captured = v; },
            get outerHTML() { return ""; }
        };
        document._e["\(scriptID)"] = { parentNode: { removeChild: function() {} } };
        \(artifact.decoderJS)
        __captured;
        """

        let result = context.evaluateScript(harness)
        if let thrown { throw SelfCheckError.engineError(thrown) }
        let recovered = (result?.isNull == true) ? "" : (result?.toString() ?? "")
        if recovered != artifact.input {
            throw SelfCheckError.roundTripMismatch(recovered: recovered)
        }
    }

    /// True when `needle` occurs in `haystack` not flanked by letters or
    /// digits — readable as standalone text rather than as an incidental
    /// fragment of an unrelated word (SPEC §7.1).
    private static func containsStandalone(_ needle: String, in haystack: String) -> Bool {
        guard !needle.isEmpty, !haystack.isEmpty else { return false }
        func isWordChar(_ c: Character) -> Bool { c.isLetter || c.isNumber }
        var searchStart = haystack.startIndex
        while let found = haystack.range(of: needle, range: searchStart..<haystack.endIndex) {
            let clearBefore = found.lowerBound == haystack.startIndex
                || !isWordChar(haystack[haystack.index(before: found.lowerBound)])
            let clearAfter = found.upperBound == haystack.endIndex
                || !isWordChar(haystack[found.upperBound])
            if clearBefore && clearAfter { return true }
            searchStart = haystack.index(after: found.lowerBound)
        }
        return false
    }
}
