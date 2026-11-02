import Foundation
import Crypto

/// Keyed hash (HMAC-SHA256) for cursors and limiter keys, so neither holds a phone.
struct LookupKeyHasher: Sendable {
    private let key: SymmetricKey

    init(secret: String) { key = SymmetricKey(data: Data(secret.utf8)) }

    func hash(_ text: String) -> String {
        Data(HMAC<SHA256>.authenticationCode(for: Data(text.utf8), using: key)).map { String(format: "%02x", $0) }.joined()
    }

    func matches(_ tag: String, for text: String) -> Bool {
        // Constant time on equal-length hex strings.
        let expected = Array(hash(text).utf8), given = Array(tag.utf8)
        guard expected.count == given.count else { return false }
        return zip(expected, given).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
