import Foundation
import Vapor
@testable import AppUnderTest

enum QAPaths {
    /// `backend/`, derived from this file: backend/Tests/qa/Tests/QATests/Support.swift
    static let backend = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // QATests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // qa
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // backend
    static let repo = backend.deletingLastPathComponent()
    static let migrations = backend.appendingPathComponent("db/migrations").path
    static let seed = backend.appendingPathComponent("db/seed/sample.sql")
    static let fixtures = repo.appendingPathComponent("contracts/fixtures")

    static func text(_ relative: String) throws -> String {
        try String(contentsOf: repo.appendingPathComponent(relative), encoding: .utf8)
    }
}

struct QAProbe: DatabaseProbe {
    let behaviour: @Sendable () async throws -> Void
    func ping() async throws { try await behaviour() }
}

struct LeakyError: Error, CustomStringConvertible {
    var description: String { "connection failed password=hunter2 host=db.internal.example" }
}
