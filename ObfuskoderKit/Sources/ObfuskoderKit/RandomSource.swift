public protocol RandomSource {
    func int(in range: ClosedRange<Int>) -> Int
    func bool() -> Bool
}

/// Stateless system randomness. Explicitly `Sendable` (a public type isn't
/// implicitly Sendable across modules) so callers can inject it into a
/// `Task.detached`/`@concurrent` encode — the engine's Sendable contract
/// (SPEC §8).
public struct SystemRandomSource: RandomSource, Sendable {
    public init() {}
    public func int(in range: ClosedRange<Int>) -> Int { Int.random(in: range) }
    public func bool() -> Bool { Bool.random() }
}
