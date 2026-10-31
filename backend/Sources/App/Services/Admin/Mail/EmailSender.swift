import Foundation
import NIOConcurrencyHelpers

struct EmailMessage: Equatable, Sendable {
    enum Kind: String, Sendable {
        case signInCode = "sign_in_code"
        case newDeviceNotice = "new_device_notice"
    }

    let kind: Kind
    let to: String
    let subject: String
    let body: String
}

/// The one door for outgoing mail (ADR-0023). Everything above it is the same
/// for every provider.
protocol EmailSender: Sendable {
    func send(_ message: EmailMessage) async throws
}

struct EmailSenderUnavailable: Error {}

/// The sender while mail is not configured: every send fails (and is logged).
struct UnavailableEmailSender: EmailSender {
    func send(_ message: EmailMessage) async throws { throw EmailSenderUnavailable() }
}

/// Prints the message body (no recipient: addresses stay out of logs) for local
/// work. Refuses to exist in production, where a printed code would be a leak.
struct ConsoleEmailSender: EmailSender {
    private let output: @Sendable (String) -> Void

    init(stage: AppConfig.Stage, output: @escaping @Sendable (String) -> Void = { print($0) }) throws {
        guard stage != .production else { throw AppConfig.Failure.invalid(AppConfig.Key.emailProvider) }
        self.output = output
    }

    func send(_ message: EmailMessage) async throws {
        output("[mail] \(message.subject)\n\(message.body)")
    }
}

/// Keeps what was sent, for tests; can be told to fail.
final class RecordingEmailSender: EmailSender {
    private struct State {
        var sent: [EmailMessage] = []
        var failuresLeft = 0
        var attempts = 0
    }
    private let state = NIOLockedValueBox(State())

    var sent: [EmailMessage] { state.withLockedValue { $0.sent } }
    var attempts: Int { state.withLockedValue { $0.attempts } }

    /// The next `count` sends throw; `Int.max` fails until reset.
    func failNext(_ count: Int = .max) { state.withLockedValue { $0.failuresLeft = count } }

    /// The code in the last sign-in mail to `address`.
    func lastCode(to address: String) -> String? {
        let body = sent.last { $0.kind == .signInCode && $0.to == address }?.body
        return body?.split(whereSeparator: { !$0.isNumber }).first { $0.count == AuthPolicy.codeLength }.map(String.init)
    }

    func send(_ message: EmailMessage) async throws {
        try state.withLockedValue { state in
            state.attempts += 1
            if state.failuresLeft > 0 {
                state.failuresLeft -= state.failuresLeft == .max ? 0 : 1
                throw EmailSenderUnavailable()
            }
            state.sent.append(message)
        }
    }
}
