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

struct StubProbe: DatabaseProbe {
    let behaviour: @Sendable () async throws -> Void
    func ping() async throws { try await behaviour() }
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

extension AppServices {
    /// Replaces the database probe factory with one answering `behaviour`.
    mutating func stubDatabaseProbe(_ behaviour: @escaping @Sendable () async throws -> Void) {
        repositories.makeDatabaseProbe = { _ in StubProbe(behaviour: behaviour) }
    }
}
