import Foundation

/// Settings of admin e-mail sign-in (ADR-0022, ADR-0023). Both secrets are
/// optional as a pair: with neither set the feature is off and `/v1/auth`
/// answers `SERVICE_UNAVAILABLE`, so a deployment that has not prepared the
/// mail provider keeps serving customers.
struct AdminAuthConfig: Equatable, Sendable {
    /// Implementations of `EmailSender` that need no provider account.
    /// Neither may run in production: one prints codes, the other keeps them.
    enum EmailProvider: String, Sendable {
        case console
        case recording
    }

    /// Shortest accepted `AUTH_CODE_PEPPER` (deployment/04 section 11).
    static let minPepperLength = 32
    static let defaultEmailMaxPerDay = 80

    let pepper: String
    let emailProvider: EmailProvider
    /// Code requests (registered or not) per UTC day (auth.md section 4.2).
    let emailMaxPerDay: Int

    init(pepper: String, emailProvider: EmailProvider, emailMaxPerDay: Int = defaultEmailMaxPerDay) {
        self.pepper = pepper
        self.emailProvider = emailProvider
        self.emailMaxPerDay = emailMaxPerDay
    }

    init?(environment: EnvironmentVariables, stage: AppConfig.Stage) throws {
        typealias Key = AppConfig.Key
        let pepper = environment.value(Key.authCodePepper)
        let provider = environment.value(Key.emailProvider)
        if pepper == nil && provider == nil { return nil }
        guard let pepper else { throw AppConfig.Failure.missing(Key.authCodePepper) }
        guard let provider else { throw AppConfig.Failure.missing(Key.emailProvider) }
        guard pepper.utf8.count >= Self.minPepperLength else { throw AppConfig.Failure.invalid(Key.authCodePepper) }
        guard let kind = EmailProvider(rawValue: provider), stage != .production else {
            throw AppConfig.Failure.invalid(Key.emailProvider)
        }
        var maxPerDay = Self.defaultEmailMaxPerDay
        if let text = environment.value(Key.emailMaxPerDay) {
            guard let parsed = Int(text), parsed >= 1 else { throw AppConfig.Failure.invalid(Key.emailMaxPerDay) }
            maxPerDay = parsed
        }
        self.init(pepper: pepper, emailProvider: kind, emailMaxPerDay: maxPerDay)
    }
}
