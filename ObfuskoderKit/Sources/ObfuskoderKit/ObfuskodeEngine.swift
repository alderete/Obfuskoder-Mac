import Foundation

public struct Snippet: Equatable, Sendable {
    public let html: String
    public let decodedSource: String
    public init(html: String, decodedSource: String) {
        self.html = html
        self.decodedSource = decodedSource
    }
}

public enum ObfuskodeError: Error, Equatable {
    /// A deterministic self-check failure that retrying cannot fix (the
    /// fallback message leaks plaintext or contains '@').
    case selfCheckFailed(SelfCheckError)
    /// Every attempt failed a randomness-dependent check; the last underlying
    /// cause is attached.
    case selfCheckFailedRepeatedly(last: SelfCheckError)
}

public struct ObfuskodeEngine: Sendable {
    public var fallbackMessage: String
    public var maxAttempts: Int

    public init(fallbackMessage: String, maxAttempts: Int = AppConfig.maxSelfCheckAttempts) {
        self.fallbackMessage = fallbackMessage
        self.maxAttempts = maxAttempts
    }

    /// Encode `input` to a verified snippet. `email` (when non-nil) is also checked for leakage.
    public func encode(_ input: String,
                       email: String? = nil,
                       random: RandomSource = SystemRandomSource()) throws -> Snippet {
        var lastError = SelfCheckError.engineError("no attempts made")
        for _ in 0..<max(1, maxAttempts) {
            let art = Encoder.makeArtifact(input: input, fallbackMessage: fallbackMessage, random: random)
            do {
                try SelfCheck.verify(art, email: email)
                return Snippet(html: art.html, decodedSource: input)
            } catch let error as SelfCheckError {
                switch error {
                case .fallbackContainsPlaintext, .plaintextLeak, .atSignPresent:
                    // Deterministic: the same fallback/input fails every
                    // attempt — surface the cause instead of burning retries.
                    throw ObfuskodeError.selfCheckFailed(error)
                case .roundTripMismatch, .engineError:
                    lastError = error
                    continue   // may depend on the random parameters; retry
                }
            }
        }
        throw ObfuskodeError.selfCheckFailedRepeatedly(last: lastError)
    }
}
