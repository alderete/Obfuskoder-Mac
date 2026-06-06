public protocol RandomSource {
    func int(in range: ClosedRange<Int>) -> Int
    func bool() -> Bool
}

public struct SystemRandomSource: RandomSource {
    public init() {}
    public func int(in range: ClosedRange<Int>) -> Int { Int.random(in: range) }
    public func bool() -> Bool { Bool.random() }
}
