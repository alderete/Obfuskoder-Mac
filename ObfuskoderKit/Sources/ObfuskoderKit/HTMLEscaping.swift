import Foundation

func htmlEscapeText(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
}

func htmlEscapeAttribute(_ s: String) -> String {
    htmlEscapeText(s).replacingOccurrences(of: "\"", with: "&quot;")
}

/// Equivalent to JS encodeURIComponent's unreserved set: A–Z a–z 0–9 - _ . ~
func percentEncodeComponent(_ s: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-_.~")
    return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
}
