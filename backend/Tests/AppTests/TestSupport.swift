import Foundation
import Logging
import NIOConcurrencyHelpers
@testable import App

enum TestPaths {
    /// `backend/`, derived from this file so tests do not depend on the
    /// working directory.
    static let backend = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // AppTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // backend

    static let migrations = backend.appendingPathComponent("db/migrations").path
    static let seed = backend.appendingPathComponent("db/seed/sample.sql")
    static let contractFixtures = backend
        .deletingLastPathComponent()
        .appendingPathComponent("contracts/fixtures")
}

struct StubCatalogRepository: CatalogRepository {
    let behaviour: @Sendable (UUID) async throws -> CatalogSnapshot
    func loadCatalog(shopID: UUID) async throws -> CatalogSnapshot { try await behaviour(shopID) }
}

struct StubProbe: DatabaseProbe {
    let behaviour: @Sendable () async throws -> Void
    func ping() async throws { try await behaviour() }
}

/// A value written by a stub and read by the test.
final class LockedBox<Value: Sendable>: Sendable {
    private let box: NIOLockedValueBox<Value>
    init(_ value: Value) { box = NIOLockedValueBox(value) }
    var value: Value { box.withLockedValue { $0 } }
    func set(_ value: Value) { box.withLockedValue { $0 = value } }
}

/// Collects log lines so tests can assert on what would reach the log sink.
final class LogCapture: @unchecked Sendable {
    // Invariant: `entries` is only touched under `lock`.
    private let lock = NIOLock()
    private var entries: [(message: String, metadata: Logger.Metadata)] = []

    var lines: [(message: String, metadata: Logger.Metadata)] { lock.withLock { entries } }

    func append(_ message: String, _ metadata: Logger.Metadata) {
        lock.withLock { entries.append((message, metadata)) }
    }

    func makeLogger() -> Logger {
        Logger(label: "test") { _ in CapturingHandler(capture: self) }
    }
}

private struct CapturingHandler: LogHandler {
    let capture: LogCapture
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        capture.append("\(event.message)", metadata.merging(event.metadata ?? [:]) { $1 })
    }
}

extension AppConfig {
    /// Points Fluent at a port nobody listens on: no connection is opened
    /// until a query runs, so tests get a request database handle for free.
    /// Fake credentials; this repository is public.
    static let unreachableDatabase = AppConfig(
        stage: .local,
        port: 8080,
        databaseURL: "postgres://test:test@127.0.0.1:1/test"
    )
}

extension AppConfig {
    static let testShopID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    /// A local configuration that names a shop and (as above) has a database
    /// handle nobody listens behind.
    static func localWithShop(
        rateLimitReadPerMinute: Int = Default.rateLimitReadPerMinute,
        trustProxy: Bool = false,
        publicAssetBaseURL: String = Default.publicAssetBaseURL
    ) -> AppConfig {
        AppConfig(
            stage: .local,
            port: 8080,
            databaseURL: "postgres://test:test@127.0.0.1:1/test",
            shopID: testShopID,
            trustProxy: trustProxy,
            rateLimitReadPerMinute: rateLimitReadPerMinute,
            publicAssetBaseURL: publicAssetBaseURL
        )
    }
}

extension AppServices {
    /// Replaces the catalogue repository factory with one answering `behaviour`.
    mutating func stubCatalogRepository(_ behaviour: @escaping @Sendable (UUID) async throws -> CatalogSnapshot) {
        repositories.makeCatalogRepository = { _ in StubCatalogRepository(behaviour: behaviour) }
    }

    /// Replaces the database probe factory with one answering `behaviour`.
    mutating func stubDatabaseProbe(_ behaviour: @escaping @Sendable () async throws -> Void) {
        repositories.makeDatabaseProbe = { _ in StubProbe(behaviour: behaviour) }
    }
}

/// In-memory availability repository: fixed rules and a fixed `day_load` table.
/// Records the ranges it was asked for so tests can check what the service reads.
final class FakeAvailabilityRepository: AvailabilityRepository {
    let rules: AvailabilityRules
    let accepted: [BusinessDate: Int]
    private let ranges = LockedBox<[ClosedRange<BusinessDate>]>([])

    init(rules: AvailabilityRules, accepted: [BusinessDate: Int] = [:]) {
        self.rules = rules
        self.accepted = accepted
    }

    var requestedRanges: [ClosedRange<BusinessDate>] { ranges.value }

    func loadRules(shopID: UUID) async throws -> AvailabilityRules { rules }

    func loadAcceptedCakes(shopID: UUID, from: BusinessDate, through: BusinessDate) async throws -> [BusinessDate: Int] {
        ranges.set(ranges.value + [from...through])
        return accepted.filter { (from...through).contains($0.key) }
    }
}

extension AppServices {
    mutating func stubAvailabilityRepository(_ repository: any AvailabilityRepository) {
        repositories.makeAvailabilityRepository = { _ in repository }
    }
}
