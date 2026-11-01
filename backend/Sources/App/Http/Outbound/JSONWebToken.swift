import Foundation
import Crypto
import _CryptoExtras

/// Compact signed tokens for the two push services: ES256 for APNs and RS256
/// for the Google OAuth assertion. Header and claims are encoded with sorted
/// keys so the same input gives the same text.
enum JSONWebToken {
    static func es256<Header: Encodable, Claims: Encodable>(header: Header, claims: Claims, key: P256.Signing.PrivateKey) throws -> String {
        try make(header: header, claims: claims) { try key.signature(for: $0).rawRepresentation }
    }

    static func rs256<Header: Encodable, Claims: Encodable>(header: Header, claims: Claims, key: _RSA.Signing.PrivateKey) throws -> String {
        try make(header: header, claims: claims) { try key.signature(for: $0, padding: .insecurePKCS1v1_5).rawRepresentation }
    }

    private static func make<Header: Encodable, Claims: Encodable>(
        header: Header, claims: Claims, sign: (Data) throws -> Data
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let input = try base64URL(encoder.encode(header)) + "." + base64URL(encoder.encode(claims))
        return input + "." + base64URL(try sign(Data(input.utf8)))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
