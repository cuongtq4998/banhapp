#if DEBUG
import BanhContracts
import Foundation

/// `POST /v1/orders` for the UI tests (launch argument `-BanhStubBackend order:<scenario>`). Answers
/// come from the contract fixtures `order-created.json`, `order-replay.json` and `order-error-*.json`
/// and go through the same `OrderFailure.from` as the real client, so the error mapping under test is
/// the shipped one. The fixtures are read from the repository (this file's path); PRICE_CHANGED is built
/// in place with the ids of the stub catalog, because the fixture uses other product ids.
final class StubOrderAPI: OrderAPI, @unchecked Sendable {
    enum Scenario {
        case success, slow, offline, lostAnswer, priceChanged
        case error(fixture: String)

        init(_ name: String) {
            switch name {
            case LaunchArgument.orderSlow: self = .slow
            case LaunchArgument.orderOffline: self = .offline
            case LaunchArgument.orderLostAnswer: self = .lostAnswer
            case LaunchArgument.orderPriceChanged: self = .priceChanged
            case let name where name.hasPrefix(LaunchArgument.orderErrorPrefix):
                self = .error(fixture: "order-" + name)
            default: self = .success
            }
        }
    }

    private static let slowDelay: Duration = .seconds(3)
    private static let lostAnswerDelay: Duration = .milliseconds(300)
    private static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("contracts/fixtures")

    private let scenario: Scenario
    private let lock = NSLock()
    private var calls = 0
    private var stored: [UUID: String] = [:]

    init(_ scenario: Scenario) {
        self.scenario = scenario
    }

    func placeOrder(_ body: OrderRequestBody, idempotencyKey: UUID) async throws -> PlacedOrder {
        let call = lock.withLock { () -> Int in
            calls += 1
            return calls
        }
        switch scenario {
        case .success:
            return accept(idempotencyKey, firstCode: LaunchArgument.confirmationCode)
        case .slow:
            try await Task.sleep(for: Self.slowDelay)
            // A second POST gets another code, so the test sees a double send.
            return PlacedOrder(code: call == 1 ? LaunchArgument.confirmationCode : LaunchArgument.otherCode, isReplay: false)
        case .offline:
            if call == 1 { throw OrderFailure.offline }
            return accept(idempotencyKey, firstCode: LaunchArgument.confirmationCode)
        case .lostAnswer:
            if call == 1 {
                _ = accept(idempotencyKey, firstCode: LaunchArgument.confirmationCode)
                try await Task.sleep(for: Self.lostAnswerDelay)
                throw OrderFailure.timeout
            }
            return accept(idempotencyKey, firstCode: LaunchArgument.otherCode)
        case .priceChanged:
            if body.expectedTotalVND != Self.changedTotal { throw try Self.priceChangedFailure() }
            return accept(idempotencyKey, firstCode: LaunchArgument.confirmationCode)
        case .error(let fixture):
            if call == 1 { throw Self.failure(fixture: fixture) }
            return accept(idempotencyKey, firstCode: LaunchArgument.confirmationCode)
        }
    }

    /// Stores a new order under the key, or answers the stored one again (`order-replay.json`).
    private func accept(_ key: UUID, firstCode: String) -> PlacedOrder {
        lock.withLock {
            if let code = stored[key] { return PlacedOrder(code: code, isReplay: true) }
            stored[key] = firstCode
            return PlacedOrder(code: firstCode, isReplay: false)
        }
    }

    // MARK: Errors

    private static let statuses: [String: Int] = [
        "min-qty": 422, "date-lead": 422, "date-horizon": 422, "district-unserved": 422, "validation-failed": 422,
        "idempotency-key-reused": 422, "date-capacity": 409, "product-unavailable": 409, "slot-unavailable": 409,
        "rate-limited": 429, "ordering-paused": 503, "service-unavailable": 503, "internal-error": 500,
        "payload-too-large": 413, "header-invalid": 400, "idempotency-key-required": 400,
    ]

    private static func failure(fixture: String) -> OrderFailure {
        let name = String(fixture.dropFirst("order-error-".count))
        guard let data = try? Data(contentsOf: fixtures.appendingPathComponent(fixture + ".json")) else {
            return .server(.internalError)
        }
        return failure(status: statuses[name] ?? 500, data: data)
    }

    private static func failure(status: Int, data: Data) -> OrderFailure {
        let url = URL(string: "http://localhost/v1/orders")!
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return OrderFailure.from(data: data, response: response)
    }

    // The review of the UI tests: 2 x Bánh chuối + 1 x Bánh đậu xanh nhân mỡ + fee 20.000. The banana goes
    // from 35.000 to 40.000.
    private static let changedTotal = 2 * 40_000 + 45_000 + 20_000

    private static func priceChangedFailure() throws -> OrderFailure {
        let banana = UITestStubData.id(11), porkFat = UITestStubData.id(12)
        let json = """
        {"error":{"code":"PRICE_CHANGED","message_key":"MSG_PRICE_CHANGED","details":{
        "items":[{"product_id":"\(banana)","price_vnd":40000},{"product_id":"\(porkFat)","price_vnd":45000}],
        "delivery_fee_vnd":20000,"total_vnd":\(changedTotal)}},"request_id":"stub"}
        """
        return failure(status: 409, data: Data(json.utf8))
    }
}
#endif
