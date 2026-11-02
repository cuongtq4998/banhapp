import Foundation

/// The store-review account (ADR-0027, BR-14): one address that signs in with
/// one fixed code, as staff, and sees demo orders only. Off unless both
/// `REVIEW_ACCOUNT_EMAIL` and `REVIEW_ACCOUNT_CODE` are set; one without the
/// other stops the start. The code is a secret: it is never printed, logged
/// or echoed in an error, and the description below hides both values.
struct ReviewAccountConfig: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Name shown for the account; the address itself is never shown to others.
    static let displayName = "Review Demo"

    let email: String
    let code: String

    init(email: String, code: String) {
        self.email = email
        self.code = code
    }

    var description: String { "ReviewAccountConfig(redacted)" }
    var debugDescription: String { description }

    /// Nil when neither variable is set (the feature is off).
    init?(environment: EnvironmentVariables) throws {
        typealias Key = AppConfig.Key
        let rawEmail = environment.value(Key.reviewAccountEmail), rawCode = environment.value(Key.reviewAccountCode)
        if rawEmail == nil && rawCode == nil { return nil }
        guard let rawEmail else { throw AppConfig.Failure.missing(Key.reviewAccountEmail) }
        guard let rawCode else { throw AppConfig.Failure.missing(Key.reviewAccountCode) }
        guard let address = EmailAddress(rawEmail) else { throw AppConfig.Failure.invalid(Key.reviewAccountEmail) }
        guard SignInCodes.isWellFormed(rawCode) else { throw AppConfig.Failure.invalid(Key.reviewAccountCode) }
        self.init(email: address.value, code: rawCode)
    }

    /// True for the one configured address (already normalised by `EmailAddress`).
    func isReviewAddress(_ address: EmailAddress) -> Bool { address.value == email }
}
