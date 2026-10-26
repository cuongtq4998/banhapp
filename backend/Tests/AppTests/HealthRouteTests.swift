import XCTVapor
import BanhContracts
import NIOConcurrencyHelpers
@testable import App

final class HealthRouteTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        let config = AppConfig(stage: .local, port: 8080, databaseURL: nil)
        try await configure(app, config: config, migrationFiles: [])
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func fixture(_ name: String) throws -> HealthResponse {
        let data = try Data(contentsOf: TestPaths.contractFixtures.appendingPathComponent(name))
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    func testShallowReturnsOkWithoutTouchingDatabase() async throws {
        let called = NIOLockedValueBox(false)
        app.services.databaseProbe = StubProbe { called.withLockedValue { $0 = true } }

        try await app.test(.GET, "healthz") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
            XCTAssertEqual(try res.content.decode(HealthResponse.self), try self.fixture("healthz-ok.json"))
        }
        XCTAssertFalse(called.withLockedValue { $0 }, "shallow check must not query the database")
    }

    func testDeepReturnsOkWhenDatabaseAnswers() async throws {
        app.services.databaseProbe = StubProbe {}
        try await app.test(.GET, "healthz?deep=1") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(HealthResponse.self).status, .ok)
        }
    }

    func testDeepReturns503WhenDatabaseFails() async throws {
        app.services.databaseProbe = StubProbe { throw DatabaseProbeError() }
        try await app.test(.GET, "healthz?deep=1") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
            XCTAssertEqual(try res.content.decode(HealthResponse.self), try self.fixture("healthz-degraded.json"))
        }
    }

    func testDeepReturns503WhenDatabaseIsSlow() async throws {
        let slowness = AppConfig.Default.healthDeepTimeoutSeconds + 3
        app.services.databaseProbe = StubProbe { try await Task.sleep(for: .seconds(slowness)) }
        let started = ContinuousClock.now
        try await app.test(.GET, "healthz?deep=1") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
        }
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(slowness), "deadline must cut the wait short")
    }

    func testDeepWithoutDatabaseConfiguredIsDegraded() async throws {
        try await app.test(.GET, "healthz?deep=1") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
        }
    }

    func testOtherDeepValuesStayShallow() async throws {
        app.services.databaseProbe = StubProbe { throw DatabaseProbeError() }
        try await app.test(.GET, "healthz?deep=0") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testUnknownPathIsNotFound() async throws {
        try await app.test(.GET, "nope") { res async throws in
            XCTAssertEqual(res.status, .notFound)
        }
    }
}
