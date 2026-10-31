import BanhContracts
import XCTest
@testable import BanhApp

/// `POST /v1/orders` on the wire: headers, body, success, replay and one test per error fixture (AC-19,
/// api.md 4.3 and section 5, ADR-0008).
final class HTTPOrderAPITests: XCTestCase {
    private let key = UUID(uuidString: "5E0C2F6A-4C47-4A0E-9B6E-0F3A5D9C1A10")!

    private func makeAPI(
        _ replies: [StubHTTPTransport.Reply], timeout: Duration = .seconds(10)
    ) -> (HTTPOrderAPI, StubHTTPTransport) {
        let transport = StubHTTPTransport(replies)
        let client = APIClient(baseURL: URL(string: "http://localhost:8080")!, appVersion: "1.0.0", transport: transport)
        return (HTTPOrderAPI(client: client, timeout: timeout), transport)
    }

    private func requestBody() throws -> OrderRequestBody {
        try Fixtures.decode(OrderRequestBody.self, from: "order-request.json")
    }

    func testSendsTheBodyWithTheContractHeaders() async throws {
        let created = try Fixtures.exchange("order-created.json")
        let (api, transport) = makeAPI([.response(status: 201, body: created.body)])
        _ = try await api.placeOrder(try requestBody(), idempotencyKey: key)

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:8080/v1/orders")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "5e0c2f6a-4c47-4a0e-9b6e-0f3a5d9c1a10")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Platform"), "ios")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-Version"), "1.0.0")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let sent = try JSONDecoder().decode(OrderRequestBody.self, from: try XCTUnwrap(request.httpBody))
        XCTAssertEqual(sent, try requestBody())
    }

    func testCreatedAndReplayGiveTheSameCodeAndTellThemApart() async throws {
        let created = try Fixtures.exchange("order-created.json")
        let replay = try Fixtures.exchange("order-replay.json")
        let (api, _) = makeAPI([
            .response(status: created.status, headers: created.headers, body: created.body),
            .response(status: replay.status, headers: replay.headers, body: replay.body),
        ])
        let first = try await api.placeOrder(try requestBody(), idempotencyKey: key)
        let second = try await api.placeOrder(try requestBody(), idempotencyKey: key)
        XCTAssertEqual(first, PlacedOrder(code: "BT-7K3M9Q", isReplay: false))
        XCTAssertEqual(second, PlacedOrder(code: "BT-7K3M9Q", isReplay: true))
    }

    func testEveryErrorFixtureMapsToItsState() async throws {
        let id = ResourceID(UUID(uuidString: "0b8f1f0e-1111-4a00-8000-000000000002")!)
        let expected: [(name: String, status: Int, failure: OrderFailure?)] = [
            ("min-qty", 422, .minQty(2)), ("date-lead", 422, .dateLead(days: 2)),
            ("date-horizon", 422, .dateHorizon(maxDays: 30)), ("date-capacity", 409, .dateCapacity(deliveryDate: "2026-11-05")),
            ("district-unserved", 422, .districtUnserved), ("slot-unavailable", 409, .slotUnavailable),
            ("product-unavailable", 409, .productUnavailable([id])), ("idempotency-key-reused", 422, .keyReused),
            ("rate-limited", 429, .rateLimited(retryAfterSeconds: 3600)),
            ("ordering-paused", 503, .server(.orderingPaused)), ("service-unavailable", 503, .server(.serviceUnavailable)),
            ("internal-error", 500, .server(.internalError)), ("payload-too-large", 413, .server(.payloadTooLarge)),
            ("header-invalid", 400, .server(.headerInvalid)),
            ("idempotency-key-required", 400, .server(.idempotencyKeyRequired)),
        ]
        for (name, status, failure) in expected {
            let (api, _) = makeAPI([.response(status: status, body: try Fixtures.data("order-error-\(name).json"))])
            await assertFails(api, with: try XCTUnwrap(failure), name)
        }
    }

    func testValidationFailedKeepsTheFieldEntries() async throws {
        let (api, _) = makeAPI([.response(status: 422, body: try Fixtures.data("order-error-validation-failed.json"))])
        do {
            _ = try await api.placeOrder(try requestBody(), idempotencyKey: key)
            XCTFail("Expected a failure")
        } catch OrderFailure.validation(let fields) {
            XCTAssertEqual(fields.map(\.field), ["customer.name", "customer.phone"])
            XCTAssertEqual(fields.map(\.messageKey), ["ERR_NAME_REQUIRED", "ERR_PHONE_INVALID"])
        }
    }

    func testPriceChangedCarriesTheNewPrices() async throws {
        let (api, _) = makeAPI([.response(status: 409, body: try Fixtures.data("order-error-price-changed.json"))])
        do {
            _ = try await api.placeOrder(try requestBody(), idempotencyKey: key)
            XCTFail("Expected a failure")
        } catch OrderFailure.priceChanged(let details) {
            XCTAssertEqual(details.totalVND, 130_000)
            XCTAssertEqual(details.deliveryFeeVND, 20_000)
            XCTAssertEqual(details.items.map(\.priceVND), [55_000])
        }
    }

    func testAnUnknownCodeAndABodyThatIsNotTheContractAreServerErrors() async throws {
        let unknown = Data(#"{"error":{"code":"BRAND_NEW","message_key":"ERR_SERVER","details":{}},"request_id":"x"}"#.utf8)
        let (api, _) = makeAPI([.response(status: 500, body: unknown)])
        await assertFails(api, with: .server(.internalError), "unknown code")
        let (proxy, _) = makeAPI([.response(status: 502, body: Data("<html>".utf8))])
        await assertFails(proxy, with: .server(.internalError), "proxy page")
        let (garbled, _) = makeAPI([.response(status: 201, body: Data("{}".utf8))])
        await assertFails(garbled, with: .server(.internalError), "201 without a code")
    }

    func testNoConnectionAndTimeoutAreDistinct() async throws {
        let (offline, _) = makeAPI([.failure(.networkUnavailable)])
        await assertFails(offline, with: .offline, "offline")
        let (timedOut, _) = makeAPI([.failure(.timeout)])
        await assertFails(timedOut, with: .timeout, "transport timeout")
    }

    func testACallThatNeverAnswersTimesOutAtTheLimit() async throws {
        let client = APIClient(
            baseURL: URL(string: "http://localhost:8080")!, appVersion: "1.0.0", transport: HangingTransport()
        )
        let api = HTTPOrderAPI(client: client, timeout: .milliseconds(100))
        await assertFails(api, with: .timeout, "hanging")
    }

    private func assertFails(
        _ api: HTTPOrderAPI, with expected: OrderFailure, _ label: String, file: StaticString = #filePath, line: UInt = #line
    ) async {
        do {
            _ = try await api.placeOrder(try requestBody(), idempotencyKey: key)
            XCTFail("\(label): expected a failure", file: file, line: line)
        } catch let failure as OrderFailure {
            XCTAssertEqual(failure, expected, label, file: file, line: line)
        } catch {
            XCTFail("\(label): \(error)", file: file, line: line)
        }
    }
}

/// A transport whose request never completes until it is cancelled.
private struct HangingTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: .seconds(60))
        throw APIError.networkUnavailable
    }
}
