import Foundation
import Crypto

enum TokenKind: String, Sendable {
    case access = "at"
    case refresh = "rt"
}

/// A credential string `<kind>_<session id>_<64 hex>` (api/05 section 9).
/// The session id lets the server find the row; only the SHA-256 of the whole
/// string is stored.
struct SessionToken: Equatable, Sendable {
    let kind: TokenKind
    let sessionID: UUID
    let text: String

    var hash: Data { Data(SHA256.hash(data: Data(text.utf8))) }

    private static let secretLength = 64

    static func issue(_ kind: TokenKind, sessionID: UUID) -> SessionToken {
        let secret = SymmetricKey(size: .bits256).withUnsafeBytes { bytes in
            bytes.map { String(format: "%02x", $0) }.joined()
        }
        return SessionToken(kind: kind, sessionID: sessionID, text: "\(kind.rawValue)_\(sessionID.uuidString.lowercased())_\(secret)")
    }

    /// Nil for anything that is not exactly the issued shape.
    static func parse(_ text: String) -> SessionToken? {
        let parts = text.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count == 3, let kind = TokenKind(rawValue: String(parts[0])),
              parts[1] == parts[1].lowercased(), let id = UUID(uuidString: String(parts[1])),
              parts[2].count == secretLength,
              parts[2].allSatisfy({ $0.isASCII && ($0.isNumber || ("a"..."f").contains($0)) }) else { return nil }
        return SessionToken(kind: kind, sessionID: id, text: text)
    }
}
