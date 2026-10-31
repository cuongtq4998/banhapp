import BanhContracts
import Foundation

/// The order the shop received: the code for S-9. `isReplay` is true when the server answered an
/// earlier attempt with the same key (200, `Idempotent-Replay`), so no second order exists (AC-19).
nonisolated struct PlacedOrder: Equatable, Sendable {
    let code: String
    let isReplay: Bool
}

/// Edge to `POST /v1/orders` (api.md 4.3); the review screen and the tests depend on this protocol.
nonisolated protocol OrderAPI: Sendable {
    /// Sends one attempt. `idempotencyKey` stays the same for a pure retry (ADR-0008 v1.1). Throws `OrderFailure`.
    func placeOrder(_ body: OrderRequestBody, idempotencyKey: UUID) async throws -> PlacedOrder
}

nonisolated struct HTTPOrderAPI: OrderAPI {
    /// The order call gives up after 10 s (api.md section 5, UI document 5.8); the outcome is then unknown.
    static let timeout: Duration = .seconds(10)

    private static let path = "v1/orders"
    private static let keyHeader = "Idempotency-Key"
    private static let replayHeader = "Idempotent-Replay"
    private static let createdStatus = 201
    private static let replayStatus = 200

    private let client: APIClient
    private let timeout: Duration

    init(client: APIClient, timeout: Duration = HTTPOrderAPI.timeout) {
        self.client = client
        self.timeout = timeout
    }

    func placeOrder(_ body: OrderRequestBody, idempotencyKey: UUID) async throws -> PlacedOrder {
        let payload = try JSONEncoder().encode(body)
        let headers = [Self.keyHeader: idempotencyKey.uuidString.lowercased()]
        let client = client
        let parts = timeout.components
        let seconds = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        let data: Data, response: HTTPURLResponse
        do {
            (data, response) = try await withTimeout(timeout) {
                try await client.post(path: Self.path, body: payload, headers: headers, timeout: seconds)
            }
        } catch APIError.timeout {
            throw OrderFailure.timeout
        } catch {
            throw OrderFailure.offline
        }
        guard response.statusCode == Self.createdStatus || response.statusCode == Self.replayStatus else {
            throw OrderFailure.from(data: data, response: response)
        }
        // A success status with a body that is not the contract may still hold a stored order, so it is
        // handled like an unknown outcome: the retry keeps the key and the server replays.
        guard let created = try? JSONDecoder().decode(OrderCreatedResponse.self, from: data) else {
            throw OrderFailure.server(.internalError)
        }
        let replay = response.value(forHTTPHeaderField: Self.replayHeader) == "true"
        return PlacedOrder(code: created.orderCode, isReplay: replay)
    }
}
