import Foundation
import NIOConcurrencyHelpers

/// In-memory request counter per client key (ADR-0014, ADR-0017).
///
/// Fixed windows per address: a client may send `limit` requests in each
/// window, and its window starts at its own first counted request. The window
/// edge allows a short burst of up to twice the limit, which is fine for an
/// abuse guard and avoids storing a timestamp per request. Counts live in
/// memory and reset on restart, as ADR-0014 accepts for a single instance.
/// Time is passed in, so tests need no sleeping and no wall clock.
final class FixedWindowRateLimiter: Sendable {
    struct Decision: Equatable, Sendable {
        let isAllowed: Bool
        /// Whole seconds until the window ends; at least 1.
        let retryAfterSeconds: Int
    }

    /// Upper bound on remembered addresses, so a flood of distinct (or
    /// forged) addresses cannot grow memory without limit.
    static let maxTrackedAddresses = 10_000

    private struct Window {
        var start: Date
        var count: Int
    }

    private let limit: Int
    private let windowSeconds: TimeInterval
    private let maxAddresses: Int
    // Invariant: every access to the windows goes through `windows.withLockedValue`.
    private let windows: NIOLockedValueBox<[String: Window]> = NIOLockedValueBox([:])

    init(limit: Int, windowSeconds: TimeInterval, maxAddresses: Int = FixedWindowRateLimiter.maxTrackedAddresses) {
        self.limit = limit
        self.windowSeconds = windowSeconds
        self.maxAddresses = maxAddresses
    }

    func registerRequest(clientKey: String, at now: Date) -> Decision {
        windows.withLockedValue { stored in
            var window = stored[clientKey] ?? Window(start: now, count: 0)
            // A clock that stepped backwards would otherwise lock the client
            // out until the old window end; treat it as a new window.
            if isExpired(window, at: now) || now < window.start {
                window = Window(start: now, count: 0)
            }
            let isAllowed = window.count < limit
            // A refused request is not counted, so a client that keeps
            // retrying is let in again exactly when its window ends.
            if isAllowed {
                window.count += 1
                if stored[clientKey] == nil { makeRoom(in: &stored, at: now) }
                stored[clientKey] = window
            }
            let remaining = window.start.addingTimeInterval(windowSeconds).timeIntervalSince(now)
            return Decision(isAllowed: isAllowed, retryAfterSeconds: max(1, Int(remaining.rounded(.up))))
        }
    }

    private func isExpired(_ window: Window, at now: Date) -> Bool {
        now.timeIntervalSince(window.start) >= windowSeconds
    }

    /// Keeps the table below its bound before a new address is added: expired
    /// windows go first (they hold no information), and only when none is
    /// expired the oldest window is dropped.
    private func makeRoom(in table: inout [String: Window], at now: Date) {
        guard table.count >= maxAddresses else { return }
        table = table.filter { !isExpired($0.value, at: now) }
        guard table.count >= maxAddresses,
              let oldest = table.min(by: { $0.value.start < $1.value.start })?.key else { return }
        table.removeValue(forKey: oldest)
    }
}
