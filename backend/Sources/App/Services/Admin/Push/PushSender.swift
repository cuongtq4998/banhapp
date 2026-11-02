import Foundation
import NIOConcurrencyHelpers

/// What a new-order notification says: order code, number of cakes and the
/// delivery date, nothing else (FR-26). There is no field for a name, phone,
/// address or note, so none can leak into a payload.
struct PushMessage: Equatable, Sendable {
    let orderCode: String
    let cakes: Int
    let deliveryDate: BusinessDate

    /// The date as the notification text shows it (`dd/MM/yyyy`).
    var displayDate: String { String(format: "%02d/%02d/%04d", deliveryDate.day, deliveryDate.month, deliveryDate.year) }

    /// Arguments of `PUSH_NEW_ORDER_BODY` (api/06 10.12), in order.
    var bodyArguments: [String] { [orderCode, String(cakes), displayDate] }
}

/// One registered phone (a `device_session` row with a token).
struct PushTarget: Equatable, Sendable {
    enum Platform: String, Sendable {
        case ios
        case android
    }

    let platform: Platform
    let token: String
    /// `production` or `sandbox`; only for iOS.
    let apnsEnvironment: String?
}

enum PushOutcome: Equatable, Sendable {
    case delivered
    /// The service says the token is dead: the caller deletes it (ADR-0024).
    case invalidToken
    /// Refused for a reason retrying will not change (bad request, rights).
    case rejected
}

/// The one door for outgoing push (ADR-0024). A throw means "try again later"
/// (network, timeout, 5xx); a returned outcome is final.
protocol PushSender: Sendable {
    func send(_ message: PushMessage, to target: PushTarget) async throws -> PushOutcome
}

struct PushSenderUnavailable: Error {}

/// Keeps what was sent, for tests; can be told to fail or to call a token dead.
final class RecordingPushSender: PushSender {
    struct Sent: Equatable, Sendable {
        let message: PushMessage
        let target: PushTarget
    }

    private struct State {
        var sent: [Sent] = []
        var attempts = 0
        var failuresLeft = 0
        var deadTokens: Set<String> = []
        var firstSendAt: Date?
    }
    private let state = NIOLockedValueBox(State())

    var sent: [Sent] { state.withLockedValue { $0.sent } }
    var attempts: Int { state.withLockedValue { $0.attempts } }
    /// Tokens delivered to, in send order.
    var tokens: [String] { sent.map(\.target.token) }

    /// The next `count` sends throw; `Int.max` fails until reset.
    func failNext(_ count: Int = .max) { state.withLockedValue { $0.failuresLeft = count } }
    func markDead(_ token: String) { state.withLockedValue { _ = $0.deadTokens.insert(token) } }

    func send(_ message: PushMessage, to target: PushTarget) async throws -> PushOutcome {
        try state.withLockedValue { state in
            state.attempts += 1
            if state.failuresLeft > 0 {
                state.failuresLeft -= state.failuresLeft == .max ? 0 : 1
                throw PushSenderUnavailable()
            }
            if state.deadTokens.contains(target.token) { return .invalidToken }
            state.sent.append(Sent(message: message, target: target))
            return .delivered
        }
    }
}
