import Foundation

/// Settings of `POST /v1/orders/lookup` (api/10, ADR-0034). None of the
/// numbers is ever sent to a client.
struct LookupPolicy: Sendable {
    enum Default {
        static let retentionDays = 30
        static let pageSize = 10
        static let maxPages = 5
        static let floorMilliseconds = 250
        static let perPhonePerHour = 10
        static let perAddressPerHour = 30
        static let perInstallationPerHour = 20
        static let windowSeconds: TimeInterval = 3_600
        static let trustedProxyHops = 1
    }

    enum Key {
        static let keySecret = "LOOKUP_KEY_SECRET"
        static let retentionDays = "LOOKUP_RETENTION_DAYS"
        static let floorMilliseconds = "LOOKUP_FLOOR_MS"
        static let clientAddressHeader = "CLIENT_ADDRESS_HEADER"
        static let trustedProxyHops = "TRUSTED_PROXY_HOPS"
    }

    var retentionDays = Default.retentionDays
    var pageSize = Default.pageSize
    var maxPages = Default.maxPages
    var floorMilliseconds = Default.floorMilliseconds
    var perPhonePerHour = Default.perPhonePerHour
    var perAddressPerHour = Default.perAddressPerHour
    var perInstallationPerHour = Default.perInstallationPerHour
    var windowSeconds = Default.windowSeconds
    /// Empty means the socket peer address.
    var clientAddressHeader = ""
    var trustedProxyHops = Default.trustedProxyHops
    /// Key of the cursor and limiter hashes; random per process when unset.
    var keySecret = UUID().uuidString + UUID().uuidString

    init() {}

    /// Unset or malformed numbers keep the defaults; values are never logged.
    init(environment: [String: String]) {
        let env = EnvironmentVariables(environment)
        retentionDays = env.value(Key.retentionDays).flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil } ?? Default.retentionDays
        floorMilliseconds = env.value(Key.floorMilliseconds).flatMap(Int.init).flatMap { $0 >= 0 ? $0 : nil } ?? Default.floorMilliseconds
        trustedProxyHops = env.value(Key.trustedProxyHops).flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil } ?? Default.trustedProxyHops
        clientAddressHeader = env.value(Key.clientAddressHeader) ?? ""
        if let secret = env.value(Key.keySecret) { keySecret = secret }
    }

    var retention: TimeInterval { TimeInterval(retentionDays) * 24 * 3_600 }
}
