import Foundation
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
