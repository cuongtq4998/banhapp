import XCTVapor
import BanhContracts
@testable import App

/// Shared setup of the `POST /v1/orders` route tests: the real middleware and
/// routes over a fake repository and a pinned clock (2026-11-02).
class OrderRouteTestCase: XCTestCase {
    var app: Application!
    var repository = FakeOrderRepository()
    let capture = LogCapture()

    func start(orders: OrderPolicy = OrderPolicy()) async throws {
        app = try await Application.make(.testing)
        app.logger = capture.makeLogger()
        try await configure(app, config: .localWithShop(orders: orders))
        app.services.clock = AvailabilityTestData.clock
        let fake = repository
        app.services.repositories.makeOrderRepository = { _ in fake }
    }

    override func tearDown() async throws {
        try await app?.asyncShutdown()
    }

    var headers: HTTPHeaders {
        ["Idempotency-Key": OrderTestData.keyText, "X-Platform": "ios", "X-App-Version": "1.0.0", "Content-Type": "application/json"]
    }

    func post(
        _ body: Data? = nil, headers: HTTPHeaders? = nil, _ check: @escaping (XCTHTTPResponse) async throws -> Void
    ) async throws {
        let payload = try body ?? OrderTestData.fixtureBody()
        try await app.test(.POST, "v1/orders", headers: headers ?? self.headers, body: ByteBuffer(data: payload), afterResponse: { res async throws in
            try await check(res)
        })
    }

    /// The error body of `res` must equal the shared fixture (the request id aside).
    func assertError(_ res: XCTHTTPResponse, _ status: HTTPResponseStatus, fixture: String, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(res.status, status, file: file, line: line)
        let expected = try JSONDecoder().decode(APIErrorResponse.self, from: OrderTestData.fixtureBody(fixture))
        let actual = try res.content.decode(APIErrorResponse.self)
        XCTAssertEqual(actual.error, expected.error, file: file, line: line)
        XCTAssertFalse(actual.requestID.isEmpty, file: file, line: line)
    }

    func mutatedBody(_ change: (inout [String: JSONValue]) -> Void) throws -> Data {
        guard case .object(var object) = try OrderTestData.json(OrderTestData.fixtureBody()) else { return Data() }
        change(&object)
        return try JSONEncoder().encode(JSONValue.object(object))
    }
}
