import Foundation

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
}
