import XCTVapor
import BanhContracts
@testable import App

final class OrderRouteTests: OrderRouteTestCase {
    func testCreatesTheOrderAndMatchesTheSharedFixtures() async throws {
        try await start()
        let created = try OrderExchange.load("order-created.json")
        try await post { res in
            XCTAssertEqual(res.status, .created)
            XCTAssertNil(res.headers.first(name: "Idempotent-Replay"))
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
            XCTAssertEqual(try res.content.decode(OrderCreatedResponse.self).createdAt, "2026-11-02T05:00:00Z")
            let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any]).keys
            XCTAssertEqual(Set(keys), ["order_code", "created_at"])
        }
        XCTAssertEqual(created.status, 201)
        XCTAssertEqual(repository.inserted.first?.platform, "ios")
        XCTAssertEqual(repository.inserted.first?.appVersion, "1.0.0")
    }

    func testRepeatReturnsTheSameBodyWithTheReplayHeader() async throws {
        try await start()
        let first = LockedBox("")
        try await post { first.set($0.body.string) }
        let replay = try OrderExchange.load("order-replay.json")
        try await post { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: "Idempotent-Replay"), replay.responseHeaders["Idempotent-Replay"])
            XCTAssertEqual(res.body.string, first.value)
        }
        XCTAssertEqual(repository.inserted.count, 1)
    }

    func testHeaderErrors() async throws {
        try await start()
        var missing = headers
        missing.remove(name: "Idempotency-Key")
        try await post(headers: missing) { try self.assertError($0, .badRequest, fixture: "order-error-idempotency-key-required.json") }
        var blank = headers
        blank.replaceOrAdd(name: "Idempotency-Key", value: "  ")
        try await post(headers: blank) { try self.assertError($0, .badRequest, fixture: "order-error-idempotency-key-required.json") }
        let bad: [(String, String)] = [
            ("Idempotency-Key", "not-a-uuid"), ("Idempotency-Key", "5e0c2f6a-4c47-1a0e-9b6e-0f3a5d9c1a10"),
            ("Idempotency-Key", "5e0c2f6a-4c47-4a0e-cb6e-0f3a5d9c1a10"), ("X-Platform", "windows"),
            ("X-App-Version", "1.0"), ("X-App-Version", "1.0.0-beta")
        ]
        for (name, value) in bad {
            var changed = headers
            changed.replaceOrAdd(name: name, value: value)
            try await post(headers: changed) { try self.assertError($0, .badRequest, fixture: "order-error-header-invalid.json") }
        }
        for name in ["X-Platform", "X-App-Version"] {
            var changed = headers
            changed.remove(name: name)
            try await post(headers: changed) { try self.assertError($0, .badRequest, fixture: "order-error-header-invalid.json") }
        }
        XCTAssertEqual(repository.calls, [])
    }

    func testOrderingPausedComesAfterHeadersAndBeforeValidation() async throws {
        try await start(orders: OrderPolicy(isEnabled: false))
        try await post(Data("not json".utf8)) { try self.assertError($0, .serviceUnavailable, fixture: "order-error-ordering-paused.json") }
        var missing = headers
        missing.remove(name: "Idempotency-Key")
        try await post(headers: missing) { XCTAssertEqual($0.status, .badRequest) }
        XCTAssertEqual(repository.calls, [])
    }

    /// The in-memory client skips the HTTP layer that enforces the body limit,
    /// so this test talks to a real listener on a free port (see `RequestBodyLimitTests`).
    func testBodyLimitIs8192Bytes() async throws {
        try await start()
        let base = try mutatedBody { $0["x"] = .string("") }.count
        let exact = try mutatedBody { $0["x"] = .string(String(repeating: "a", count: 8_192 - base)) }
        XCTAssertEqual(exact.count, 8_192)
        let over = try mutatedBody { $0["x"] = .string(String(repeating: "a", count: 8_193 - base)) }
        let live = try app.testable(method: .running(port: 0))
        try await live.test(.POST, "v1/orders", headers: headers, beforeRequest: { $0.body = ByteBuffer(data: exact) }) { res async throws in
            XCTAssertEqual(res.status, .unprocessableEntity)
        }
        try await live.test(.POST, "v1/orders", headers: headers, beforeRequest: { $0.body = ByteBuffer(data: over) }) { res async throws in
            try self.assertError(res, .payloadTooLarge, fixture: "order-error-payload-too-large.json")
        }
    }

    func testAddressLimitCountsPostsAndKeepsReadsApart() async throws {
        try await start(orders: OrderPolicy(perAddressPerHour: 2))
        try await post { XCTAssertEqual($0.status, .created) }
        try await post { XCTAssertEqual($0.status, .ok) }
        try await post { res in
            XCTAssertEqual(res.status, .tooManyRequests)
            XCTAssertEqual(res.headers.first(name: .retryAfter), "3600")
            let body = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(body.error.code, "RATE_LIMITED")
            XCTAssertEqual(body.error.details, ["retry_after_seconds": .int(3_600)])
        }
        try await app.test(.GET, "healthz") { res async throws in XCTAssertEqual(res.status, .ok) }
        XCTAssertEqual(repository.inserted.count, 1)
    }

    func testValidationFailuresMatchTheFixtureAndKeepTheDataOutOfTheLog() async throws {
        try await start()
        let body = try mutatedBody { root in
            root["customer"] = .object(["name": .string(" "), "phone": .string("0123456789"), "address": .string("Secret Street 9"),
                                        "district_id": .string(OrderTestData.districtID.uuidString)])
        }
        try await post(body) { try self.assertError($0, .unprocessableEntity, fixture: "order-error-validation-failed.json") }
        // The fixture lists the phone first; the server reports in the order of the fields: name, phone.
        XCTAssertEqual(repository.calls, [])
        let everything = capture.lines.map { "\($0.message) \($0.metadata)" }.joined()
        for secret in ["0123456789", "Secret Street", "Nguyễn", "0900"] { XCTAssertFalse(everything.contains(secret), secret) }
        let access = try XCTUnwrap(capture.lines.last { $0.message == "request" })
        XCTAssertEqual(access.metadata["route"], .string("/v1/orders"))
        XCTAssertEqual(access.metadata["error_code"], .string("VALIDATION_FAILED"))
    }

    func testNonJsonAndUnknownFieldsAreValidationFailures() async throws {
        try await start()
        for body in [Data("not json".utf8), Data(), Data("[]".utf8), try mutatedBody { $0["price_vnd"] = .int(1) }] {
            try await post(body) { res in
                XCTAssertEqual(res.status, .unprocessableEntity)
                XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "VALIDATION_FAILED")
            }
        }
        XCTAssertEqual(repository.calls, [])
    }

    func testWithoutAShopOrDatabaseTheEndpointIsUnavailable() async throws {
        app = try await Application.make(.testing)
        try await configure(app, config: .unreachableDatabase)
        try await post { try self.assertError($0, .serviceUnavailable, fixture: "order-error-service-unavailable.json") }
    }
}
