import Foundation
import JavaScriptCore

public enum SelfCheckError: Error, Equatable {
    case plaintextLeak
    case atSignPresent
    case roundTripMismatch(recovered: String)
    case engineError(String)
}

enum SelfCheck {
    /// ENC-2 + ENC-3 (SPEC §7.3).
    static func verifyStringProperties(_ artifact: EncodedArtifact, email: String?) throws {
        if artifact.html.contains(artifact.input) { throw SelfCheckError.plaintextLeak } // ENC-2
        if let email, !email.isEmpty, artifact.html.contains(email) {                    // ENC-2
            throw SelfCheckError.plaintextLeak
        }
        if artifact.html.contains("@") { throw SelfCheckError.atSignPresent }            // ENC-3
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

        let harness = """
        var __captured = null;
        var document = {
            _e: {},
            getElementById: function(id) { return this._e[id] || null; }
        };
        document._e["\(artifact.spanID)"] = {
            set outerHTML(v) { __captured = v; },
            get outerHTML() { return ""; }
        };
        document._e["\(artifact.scriptID)"] = { parentNode: { removeChild: function() {} } };
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
}
