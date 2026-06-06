import Testing
@testable import ObfuskoderKit

@Test func makeConsumesRandomInExpectedOrder() {
    // order: k(int), maskFlag(bool), [maskVal(int)], reversed(bool), 6× token(int)
    let r = ScriptedRandom(ints: [100, 200, 0, 1, 2, 3, 4, 5], bools: [true, false])
    let p = EncodeParameters.make(using: r)
    #expect(p.k == 100)
    #expect(p.mask == 200)          // maskFlag true -> reads 200
    #expect(p.reversed == false)
    #expect(p.id == "OBFUSKODER_abcdef")  // ints 0,1,2,3,4,5 -> a,b,c,d,e,f
}

@Test func makeSkipsMaskValueWhenFlagFalse() {
    let r = ScriptedRandom(ints: [50, 0, 1, 2, 3, 4, 5], bools: [false, true])
    let p = EncodeParameters.make(using: r)
    #expect(p.k == 50)
    #expect(p.mask == 0)            // maskFlag false -> no mask, no int consumed
    #expect(p.reversed == true)
    #expect(p.id == "OBFUSKODER_abcdef")
}
