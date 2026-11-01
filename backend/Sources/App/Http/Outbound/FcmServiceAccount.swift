import Foundation
import _CryptoExtras

/// The parts of a Google service-account file the push client uses.
struct FcmServiceAccount {
    let clientEmail: String
    let key: _RSA.Signing.PrivateKey

    private struct File: Decodable {
        let clientEmail: String
        let privateKey: String
        enum CodingKeys: String, CodingKey { case clientEmail = "client_email", privateKey = "private_key" }
    }

    /// - Throws: when the text is not JSON, lacks a field or holds no usable RSA key.
    static func parse(_ json: String) throws -> FcmServiceAccount {
        let file = try JSONDecoder().decode(File.self, from: Data(json.utf8))
        return FcmServiceAccount(clientEmail: file.clientEmail, key: try _RSA.Signing.PrivateKey(pemRepresentation: file.privateKey))
    }
}
