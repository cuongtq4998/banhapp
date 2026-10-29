import Foundation

/// The configuration of `POST /v1/orders` that is not a shop rule: the
/// ordering switch and the abuse limits (ADR-0014, auth.md section 4).
struct OrderPolicy: Equatable, Sendable {
    enum Default {
        static let isEnabled = true
        /// api.md section 1: orders per client address per hour.
        static let perAddressPerHour = 10
        /// api.md section 1, ADR-0014: accepted orders per normalised phone per 24 hours.
        static let perPhonePerDay = 5
        static let addressWindowSeconds: TimeInterval = 3_600
    }

    /// `ORDERING_ENABLED=false` answers 503 `ORDERING_PAUSED`.
    let isEnabled: Bool
    let perAddressPerHour: Int
    let perPhonePerDay: Int
    /// Not an environment variable: tests shorten it to see the reset.
    let addressWindowSeconds: TimeInterval

    init(
        isEnabled: Bool = Default.isEnabled,
        perAddressPerHour: Int = Default.perAddressPerHour,
        perPhonePerDay: Int = Default.perPhonePerDay,
        addressWindowSeconds: TimeInterval = Default.addressWindowSeconds
    ) {
        self.isEnabled = isEnabled
        self.perAddressPerHour = perAddressPerHour
        self.perPhonePerDay = perPhonePerDay
        self.addressWindowSeconds = addressWindowSeconds
    }

    /// Unset variables keep the defaults; a malformed value fails the start
    /// and names only the variable (never its value).
    init(environment: EnvironmentVariables) throws {
        typealias Key = AppConfig.Key
        var enabled = Default.isEnabled
        if let text = environment.value(Key.orderingEnabled) {
            switch text.lowercased() {
            case "true": enabled = true
            case "false": enabled = false
            default: throw AppConfig.Failure.invalid(Key.orderingEnabled)
            }
        }
        self.init(
            isEnabled: enabled,
            perAddressPerHour: try Self.positiveInt(environment, Key.rateLimitOrderPerHour, default: Default.perAddressPerHour),
            perPhonePerDay: try Self.positiveInt(environment, Key.orderMaxPerPhonePerDay, default: Default.perPhonePerDay)
        )
    }

    private static func positiveInt(_ environment: EnvironmentVariables, _ key: String, default fallback: Int) throws -> Int {
        guard let text = environment.value(key) else { return fallback }
        guard let parsed = Int(text), parsed >= 1 else { throw AppConfig.Failure.invalid(key) }
        return parsed
    }
}
