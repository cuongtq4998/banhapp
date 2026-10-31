import BanhContracts
import Foundation
@testable import BanhApp

/// An order API that answers from a script and records every attempt (body and key). The last answer
/// repeats when the script runs out. `delay` holds each call, to test a send that is still running.
final class ScriptedOrderAPI: OrderAPI, @unchecked Sendable {
    typealias Reply = Result<PlacedOrder, OrderFailure>

    private let lock = NSLock()
    private var replies: [Reply]
    private var recorded: [(body: OrderRequestBody, key: UUID)] = []
    private let delay: Duration?

    init(_ replies: [Reply], delay: Duration? = nil) {
        self.replies = replies
        self.delay = delay
    }

    var calls: [(body: OrderRequestBody, key: UUID)] { lock.withLock { recorded } }
    var keys: [UUID] { calls.map(\.key) }

    func placeOrder(_ body: OrderRequestBody, idempotencyKey: UUID) async throws -> PlacedOrder {
        let reply: Reply = lock.withLock {
            recorded.append((body, idempotencyKey))
            return replies.count > 1 ? replies.removeFirst() : (replies.first ?? .failure(.server(.internalError)))
        }
        if let delay { try await Task.sleep(for: delay) }
        return try reply.get()
    }
}
