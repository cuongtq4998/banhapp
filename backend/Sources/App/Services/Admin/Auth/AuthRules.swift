import Foundation

/// The time and counter rules of sign-in, as pure functions of the stored
/// facts and "now", so every boundary is testable without a database.
enum AuthRules {
    /// Seconds still to wait before the next code, or nil when one may be sent.
    /// Allowed at exactly the wait (30 s after the last code).
    static func resendWait(lastCreatedAt: Date?, now: Date) -> Int? {
        guard let last = lastCreatedAt else { return nil }
        let remaining = last.addingTimeInterval(AuthPolicy.resendWait).timeIntervalSince(now)
        return remaining > 0 ? Int(remaining.rounded(.up)) : nil
    }

    /// Seconds until the hourly limit frees a slot, or nil when under it.
    /// `createdInWindow` holds the codes created after `now - 1 hour`.
    static func hourlyWait(createdInWindow: [Date], now: Date) -> Int? {
        let sorted = createdInWindow.sorted()
        guard sorted.count >= AuthPolicy.codesPerHour else { return nil }
        let frees = sorted[sorted.count - AuthPolicy.codesPerHour].addingTimeInterval(AuthPolicy.hourWindow)
        return max(1, Int(frees.timeIntervalSince(now).rounded(.up)))
    }

    /// A code is valid strictly before its expiry (10:00 is too late).
    static func isExpired(expiresAt: Date, now: Date) -> Bool { now >= expiresAt }

    static func isVoid(wrongCount: Int) -> Bool { wrongCount >= AuthPolicy.maxWrongEntries }

    enum RefreshDecision: Equatable {
        case expired
        /// The current credential: normal rotation.
        case rotate
        /// The previous credential inside the grace: the answer was lost.
        case rotateAgain
        /// A replaced credential used too late, or an unknown one.
        case reuse
    }

    /// A session lives strictly less than 7 days after its last refresh.
    static func refreshDecision(
        presented: Data, current: Data, previous: Data?, rotatedAt: Date?, expiresAt: Date, now: Date
    ) -> RefreshDecision {
        if now >= expiresAt { return .expired }
        if presented == current { return .rotate }
        if let previous, presented == previous, let rotatedAt,
           now.timeIntervalSince(rotatedAt) <= AuthPolicy.refreshGrace { return .rotateAgain }
        return .reuse
    }
}
