import Foundation
import NIOConcurrencyHelpers

/// The three lookup limits and the floor counter (api/10 10.14.5).
final class LookupGuard: Sendable {
    private let phone: FixedWindowRateLimiter
    private let address: FixedWindowRateLimiter
    private let installation: FixedWindowRateLimiter

    init(policy: LookupPolicy) {
        phone = FixedWindowRateLimiter(limit: policy.perPhonePerHour, windowSeconds: policy.windowSeconds)
        address = FixedWindowRateLimiter(limit: policy.perAddressPerHour, windowSeconds: policy.windowSeconds)
        installation = FixedWindowRateLimiter(limit: policy.perInstallationPerHour, windowSeconds: policy.windowSeconds)
    }

    /// Throws the one `RATE_LIMITED` answer whichever key tripped. A valid
    /// cursor skips only the phone budget.
    func check(phoneKey: String, addressKey: String, installationKey: String?, hasCursor: Bool, cursorIsValid: Bool, at now: Date) throws {
        var decisions = [address.registerRequest(clientKey: addressKey, at: now)]
        if let installationKey { decisions.append(installation.registerRequest(clientKey: installationKey, at: now)) }
        if !(hasCursor && cursorIsValid) { decisions.append(phone.registerRequest(clientKey: phoneKey, at: now)) }
        guard let refused = decisions.filter({ !$0.isAllowed }).map(\.retryAfterSeconds).max() else { return }
        throw APIError.rateLimited(retryAfterSeconds: refused)
    }
}

/// Counter without any phone in it.
final class LookupMetrics: Sendable {
    private let exceeded = NIOLockedValueBox(0)
    var floorExceededCount: Int { exceeded.withLockedValue { $0 } }
    func recordFloorExceeded() { exceeded.withLockedValue { $0 += 1 } }
}
