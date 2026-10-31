import XCTest
import XCTVapor
import NIOConcurrencyHelpers
@testable import AppUnderTest

final class HealthEdgeTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        // A port nobody listens on: Fluent opens no connection until a query
        // runs, and the request then has a database handle for the stubbed probe.
        try await configure(app, config: AppConfig(stage: .local, port: 8080, databaseURL: "postgres://qa:qa@127.0.0.1:1/qa"))
    }

    override func tearDown() async throws { try await app.asyncShutdown() }

    private func stub(_ probe: QAProbe) {
        app.services.repositories.makeDatabaseProbe = { _ in probe }
    }

    private func body(_ res: XCTHTTPResponse) throws -> [String: String] {
        try JSONDecoder().decode([String: String].self, from: Data(res.body.readableBytesView))
    }

    func testShallowBodyIsExactlyStatusOk() async throws {
        try await app.test(.GET, "healthz") { res async throws in
            XCTAssertEqual(try self.body(res), ["status": "ok"])
            XCTAssertTrue(res.headers.contentType?.description.hasPrefix("application/json") ?? false)
        }
    }

    func testOnlyGetIsServed() async throws {
        for method in [HTTPMethod.POST, .PUT, .DELETE, .PATCH] {
            try await app.test(method, "healthz") { res async throws in
                XCTAssertNotEqual(res.status, .ok, "\(method)")
                XCTAssertLessThan(res.status.code, 500, "\(method)")
            }
        }
    }

    func testHeadRequestDoesNotFailLikeAServerError() async throws {
        // Uptime monitors often probe with HEAD.
        try await app.test(.HEAD, "healthz") { res async throws in
            XCTAssertLessThan(res.status.code, 500)
            XCTAssertEqual(res.status, .ok, "HEAD should mirror GET so HEAD-based monitors stay green")
        }
    }

    func testTrailingSlashAndCase() async throws {
        try await app.test(.GET, "healthz/") { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "HEALTHZ") { res async throws in XCTAssertLessThan(res.status.code, 500) }
    }

    func testDeepQueryVariants() async throws {
        let failing = QAProbe { throw DatabaseProbeError() }
        stub(failing)
        for query in ["deep=true", "deep=", "deep", "deep=1%20", "other=1", "deep=0&deep=1x"] {
            try await app.test(.GET, "healthz?\(query)") { res async throws in
                XCTAssertEqual(res.status, .ok, query)
            }
        }
        try await app.test(.GET, "healthz?deep=1&deep=0") { res async throws in
            // First value wins or last wins; either way never a 500.
            XCTAssertLessThan(res.status.code, 500)
        }
    }

    func testDegradedBodyAndHeaders() async throws {
        stub(QAProbe { throw DatabaseProbeError() })
        try await app.test(.GET, "healthz?deep=1") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
            XCTAssertEqual(try self.body(res), ["status": "degraded"])
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
        }
    }

    func testErrorDetailsNeverLeakIntoResponse() async throws {
        stub(QAProbe { throw LeakyError() })
        try await app.test(.GET, "healthz?deep=1") { res async throws in
            let text = String(buffer: res.body)
            XCTAssertFalse(text.contains("hunter2"))
            XCTAssertFalse(text.contains("internal.example"))
        }
    }

    func testDeadlineIsAboutTwoSeconds() async throws {
        stub(QAProbe { try await Task.sleep(for: .seconds(10)) })
        let started = ContinuousClock.now
        try await app.test(.GET, "healthz?deep=1") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
        }
        let elapsed = ContinuousClock.now - started
        XCTAssertGreaterThan(elapsed, .milliseconds(1800))
        XCTAssertLessThan(elapsed, .milliseconds(3500))
    }

    func testFastSuccessDoesNotWaitForDeadline() async throws {
        stub(QAProbe {})
        let started = ContinuousClock.now
        try await app.test(.GET, "healthz?deep=1") { res async throws in XCTAssertEqual(res.status, .ok) }
        XCTAssertLessThan(ContinuousClock.now - started, .milliseconds(500))
    }

    func testManyParallelDeepChecksWithSlowDatabase() async throws {
        stub(QAProbe { try await Task.sleep(for: .seconds(6)) })
        let started = ContinuousClock.now
        let app: Application = self.app
        let codes = try await withThrowingTaskGroup(of: UInt.self) { group in
            for _ in 0..<25 {
                group.addTask {
                    let code = NIOLockedValueBox<UInt>(0)
                    try await app.test(.GET, "healthz?deep=1") { res async throws in code.withLockedValue { $0 = res.status.code } }
                    return code.withLockedValue { $0 }
                }
            }
            var all: [UInt] = []
            for try await c in group { all.append(c) }
            return all
        }
        XCTAssertEqual(codes.count, 25)
        XCTAssertTrue(codes.allSatisfy { $0 == 503 })
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(5), "checks must run concurrently, not queue")
    }

    func testRecoveryAfterFailureNoStickyState() async throws {
        let failing = NIOLockedValueBox(true)
        stub(QAProbe { if failing.withLockedValue({ $0 }) { throw DatabaseProbeError() } })
        try await app.test(.GET, "healthz?deep=1") { res async throws in XCTAssertEqual(res.status, .serviceUnavailable) }
        failing.withLockedValue { $0 = false }
        try await app.test(.GET, "healthz?deep=1") { res async throws in XCTAssertEqual(res.status, .ok) }
    }

    func testFixturesMatchWireFormat() async throws {
        for (name, expected) in [("healthz-ok.json", "ok"), ("healthz-degraded.json", "degraded")] {
            let data = try Data(contentsOf: QAPaths.fixtures.appendingPathComponent(name))
            XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: data), ["status": expected])
        }
    }
}
