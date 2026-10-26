import Foundation
import NIOConcurrencyHelpers

/// In-memory request counter per client key (ADR-0014).
///
/// Fixed windows: a client may send `limit` requests in each window. The
/// window edge allows a short burst of up to twice the limit, which is fine
/// for an abuse guard and avoids storing a timestamp per request. Counts live
/// in memory and reset on restart, as ADR-0014 accepts for a single instance.
/// Time is passed in, so tests need no sleeping and no wall clock.
final class FixedWindowRateLimiter: Sendable {
    struct Decision: Equatable, Sendable {
        let isAllowed: Bool
        /// Whole seconds until the window ends; at least 1.
        let retryAfterSeconds: Int
    }

    private struct State {
        var windowStart: Date
        var counts: [String: Int] = [:]
    }

    private let limit: Int
    private let windowSeconds: TimeInterval
    // Invariant: every access to the state goes through `state.withLockedValue`.
    private let state: NIOLockedValueBox<State?> = NIOLockedValueBox(nil)

    init(limit: Int, windowSeconds: TimeInterval) {
        self.limit = limit
        self.windowSeconds = windowSeconds
    }

    func registerRequest(clientKey: String, at now: Date) -> Decision {
        state.withLockedValue { stored in
            var current = stored ?? State(windowStart: now)
            // A new window drops all counts, which also bounds the memory.
            if now.timeIntervalSince(current.windowStart) >= windowSeconds || now < current.windowStart {
                current = State(windowStart: now)
            }
            let used = current.counts[clientKey] ?? 0
            let isAllowed = used < limit
            // A refused request is not counted, so a client that keeps
            // retrying is let in again exactly when the window ends.
            if isAllowed { current.counts[clientKey] = used + 1 }
            let remaining = current.windowStart.addingTimeInterval(windowSeconds).timeIntervalSince(now)
            stored = current
            return Decision(isAllowed: isAllowed, retryAfterSeconds: max(1, Int(remaining.rounded(.up))))
        }
    }
}
