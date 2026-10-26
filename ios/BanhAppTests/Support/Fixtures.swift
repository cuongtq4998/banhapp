import Foundation

/// Reads the shared contract fixtures (`contracts/fixtures`). The tests run on the host Mac, not
/// inside the simulator sandbox, and the fixtures live outside the Xcode project, so the folder is
/// found from this source file and not from the bundle or the working directory.
enum Fixtures {
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Support
        .deletingLastPathComponent() // BanhAppTests
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // repository root

    private static let directory = repositoryRoot.appendingPathComponent("contracts/fixtures")

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(name))
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(type, from: data(name))
    }

    static func names(withPrefix prefix: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }
            .sorted()
    }
}
