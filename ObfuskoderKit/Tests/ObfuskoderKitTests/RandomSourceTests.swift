import Testing
@testable import ObfuskoderKit

@Test func systemRandomStaysInRange() {
    let r = SystemRandomSource()
    for _ in 0..<200 {
        let v = r.int(in: 3...250)
        #expect(v >= 3 && v <= 250)
    }
}

@Test func scriptedRandomReturnsQueuedValuesInOrder() {
    let r = ScriptedRandom(ints: [7, 42, 1, 2, 3, 4, 5, 6], bools: [true, false])
    #expect(r.int(in: 0...999) == 7)
    #expect(r.bool() == true)
    #expect(r.int(in: 0...999) == 42)
    #expect(r.bool() == false)
}

// MARK: - Test-only helper

final class ScriptedRandom: RandomSource {
    private var ints: [Int]
    private var bools: [Bool]
    private var intCursor = 0
    private var boolCursor = 0
    init(ints: [Int], bools: [Bool]) { self.ints = ints; self.bools = bools }
    func int(in range: ClosedRange<Int>) -> Int {
        defer { intCursor += 1 }
        return ints[intCursor]
    }
    func bool() -> Bool {
        defer { boolCursor += 1 }
        return bools[boolCursor]
    }
}
