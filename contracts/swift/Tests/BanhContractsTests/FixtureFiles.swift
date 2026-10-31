import Foundation

/// Reads the shared contract fixtures (`contracts/fixtures`), located from
/// this file so the tests do not depend on the working directory.
enum FixtureFiles {
    private static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // BanhContractsTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // swift
        .deletingLastPathComponent() // contracts
        .appendingPathComponent("fixtures")

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(name))
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(type, from: data(name))
    }
}
