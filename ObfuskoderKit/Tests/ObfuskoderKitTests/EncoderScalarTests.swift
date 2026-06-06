import Testing
@testable import ObfuskoderKit

@Test func encodesScalarsWithOffsetOnly() {
    let p = EncodeParameters(k: 5, mask: 0, reversed: false, id: "OBFUSKODER_aaaaaa")
    // "AB" -> [65+5, 66+5] = [70, 71]
    #expect(Encoder.encodeScalars("AB", with: p) == [70, 71])
}

@Test func encodesScalarsWithMaskThenReverse() {
    let p = EncodeParameters(k: 5, mask: 1, reversed: true, id: "OBFUSKODER_aaaaaa")
    // "AB": (65+5)^1=71, (66+5)^1=70 -> [71,70] reversed -> [70,71]
    #expect(Encoder.encodeScalars("AB", with: p) == [70, 71])
}

@Test func handlesNonBMPScalars() {
    let p = EncodeParameters(k: 3, mask: 0, reversed: false, id: "OBFUSKODER_aaaaaa")
    // "😀" is U+1F600 = 128512 -> 128515
    #expect(Encoder.encodeScalars("😀", with: p) == [128515])
}
