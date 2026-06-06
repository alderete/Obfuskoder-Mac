import Foundation

struct EncodeParameters: Equatable {
    let k: Int          // [3, 250]
    let mask: Int       // 0 = no mask, else [1, 255]
    let reversed: Bool
    let id: String      // span id; script id = id + "_s"

    static func make(using random: RandomSource) -> EncodeParameters {
        let k = random.int(in: 3...250)
        let mask = random.bool() ? random.int(in: 1...255) : 0
        let reversed = random.bool()
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var token = ""
        for _ in 0..<6 { token.append(alphabet[random.int(in: 0...(alphabet.count - 1))]) }
        return EncodeParameters(k: k, mask: mask, reversed: reversed, id: "OBFUSKODER_" + token)
    }
}

struct EncodedArtifact: Equatable {
    let html: String
    let spanID: String
    let scriptID: String
    let decoderJS: String
    let input: String
}

enum Encoder {
    static func encodeScalars(_ input: String, with p: EncodeParameters) -> [Int] {
        var nums = input.unicodeScalars.map { scalar -> Int in
            var n = Int(scalar.value) + p.k
            if p.mask != 0 { n = n ^ p.mask }
            return n
        }
        if p.reversed { nums.reverse() }
        return nums
    }
}
