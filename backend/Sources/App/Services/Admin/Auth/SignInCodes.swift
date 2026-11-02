import Foundation
import Crypto

/// Creation and checking of the 6-digit code. Only a keyed hash over address
/// and code is stored (`AUTH_CODE_PEPPER`), so a database leak does not give
/// usable codes.
struct SignInCodes: Sendable {
    private let key: SymmetricKey

    init(pepper: String) {
        key = SymmetricKey(data: Data(pepper.utf8))
    }

    static func makeCode() -> String {
        String(format: "%0\(AuthPolicy.codeLength)d", Int.random(in: 0..<1_000_000))
    }

    func hmac(email: EmailAddress, code: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: message(email, code), using: key))
    }

    func matches(_ stored: Data, email: EmailAddress, code: String) -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(stored, authenticating: message(email, code), using: key)
    }

    /// Hash for the row of an unregistered address: same shape, never matches.
    static func phantomHash() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    /// Exactly six ASCII digits; anything else is a validation error, not a wrong entry.
    static func isWellFormed(_ code: String) -> Bool {
        code.utf8.count == AuthPolicy.codeLength && code.utf8.allSatisfy { (48...57).contains($0) }
    }

    private func message(_ email: EmailAddress, _ code: String) -> Data {
        Data("\(email.value):\(code)".utf8)
    }
}
