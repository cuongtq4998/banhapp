import Foundation

/// How long rows live after they stop being useful (data-model/05 section 14).
struct MaintenancePolicy: Sendable {
    /// Pause between two runs; the first run is at start-up.
    let interval: Duration
    /// Sign-in codes keep their address this long after expiry.
    let authCodeGrace: TimeInterval
    /// Revoked or expired sessions stay this long for support.
    let sessionGrace: TimeInterval
    /// Security events older than this are dropped.
    let securityEventAge: TimeInterval

    static let standard = MaintenancePolicy(
        interval: .seconds(86_400),
        authCodeGrace: 24 * 3_600,
        sessionGrace: 30 * 86_400,
        securityEventAge: 180 * 86_400
    )

    struct Cutoffs: Equatable, Sendable {
        let authCodeExpiredBefore: Date
        let sessionEndedBefore: Date
        let securityEventBefore: Date
    }

    /// Returns the instants that rows must be older than to be purged.
    func cutoffs(now: Date) -> Cutoffs {
        Cutoffs(
            authCodeExpiredBefore: now.addingTimeInterval(-authCodeGrace),
            sessionEndedBefore: now.addingTimeInterval(-sessionGrace),
            securityEventBefore: now.addingTimeInterval(-securityEventAge)
        )
    }
}
