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
    case selfCheckFailedRepeatedly
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
        for _ in 0..<maxAttempts {
            let art = Encoder.makeArtifact(input: input, fallbackMessage: fallbackMessage, random: random)
            do {
                try SelfCheck.verify(art, email: email)
                return Snippet(html: art.html, decodedSource: input)
            } catch {
                continue   // extremely rare random-id collision; retry
            }
        }
        throw ObfuskodeError.selfCheckFailedRepeatedly
    }
}
