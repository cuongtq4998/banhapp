import Foundation
import Crypto

/// A strong HTTP entity tag (RFC 9110 section 8.8.3) derived from the exact
/// bytes of a response, so two responses share a tag only when they are
/// identical. The tag is the first 128 bits of the SHA-256 digest: far more
/// than enough to tell catalogue versions apart, and shorter on the wire.
struct EntityTag: Equatable, Sendable {
    /// The quoted wire form, for example `"3f9a..."`.
    let headerValue: String

    static let hexLength = 32

    init(hashing body: Data) {
        let digest = SHA256.hash(data: body)
        self.headerValue = "\"" + digest.hexString.prefix(Self.hexLength) + "\""
    }

    /// Whether an `If-None-Match` header (a list of tags, a weak form, or `*`)
    /// names this tag. Weak comparison, as RFC 9110 prescribes for this header.
    func isListed(inIfNoneMatch header: String?) -> Bool {
        guard let header else { return false }
        return header.split(separator: ",").contains { candidate in
            let tag = candidate.trimmingCharacters(in: .whitespaces)
            return tag == "*" || tag.removingWeakPrefix == headerValue
        }
    }
}

private extension String {
    var removingWeakPrefix: String {
        hasPrefix("W/") ? String(dropFirst(2)) : self
    }
}

extension SHA256Digest {
    /// Lower-case hexadecimal form of the whole digest.
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
