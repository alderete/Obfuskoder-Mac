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

    static func buildArtifact(input: String,
                              parameters p: EncodeParameters,
                              fallbackMessage: String) -> EncodedArtifact {
        let nums = encodeScalars(input, with: p)
        let numbers = nums.map(String.init).joined(separator: ",")
        let spanID = p.id
        let scriptID = p.id + "_s"
        let r = p.reversed ? 1 : 0

        let decoderJS =
            "(function(){var d=[\(numbers)];var k=\(p.k),m=\(p.mask),r=\(r);" +
            "if(r)d.reverse();var s=\"\";for(var i=0;i<d.length;i++){var n=d[i];" +
            "if(m)n=n^m;n=n-k;s+=String.fromCodePoint(n);}" +
            "var el=document.getElementById(\"\(spanID)\");if(el){el.outerHTML=s;}" +
            "var sc=document.getElementById(\"\(scriptID)\");" +
            "if(sc&&sc.parentNode){sc.parentNode.removeChild(sc);}})();"

        let html =
            "<span id=\"\(spanID)\">\(fallbackMessage)</span>" +
            "<script id=\"\(scriptID)\">\(decoderJS)</script>"

        return EncodedArtifact(html: html, spanID: spanID, scriptID: scriptID,
                               decoderJS: decoderJS, input: input)
    }

    static func makeArtifact(input: String,
                             fallbackMessage: String,
                             random: RandomSource) -> EncodedArtifact {
        buildArtifact(input: input,
                      parameters: EncodeParameters.make(using: random),
                      fallbackMessage: fallbackMessage)
    }
}
