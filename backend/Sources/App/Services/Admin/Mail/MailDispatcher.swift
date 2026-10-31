import Foundation
import Logging

/// Sends mail off the request path: one try, one retry after a pause, then the
/// failure is logged (kind only, never the address) and dropped. A failed mail
/// never changes the answer the person already got (FR-7, ADR-0023).
struct MailDispatcher: Sendable {
    static let defaultRetryDelay: Duration = .seconds(5)

    let sender: any EmailSender
    let work: BackgroundWork
    let retryDelay: Duration

    func sendAfterResponse(_ message: EmailMessage, logger: Logger, onSent: (@Sendable () async -> Void)? = nil) {
        let sender = sender, retryDelay = retryDelay
        work.run {
            for attempt in 1...2 {
                do {
                    try await sender.send(message)
                    await onSent?()
                    return
                } catch {
                    if attempt == 1 { try? await Task.sleep(for: retryDelay) }
                }
            }
            logger.warning("Mail not sent", metadata: ["mail_kind": .string(message.kind.rawValue)])
        }
    }
}
