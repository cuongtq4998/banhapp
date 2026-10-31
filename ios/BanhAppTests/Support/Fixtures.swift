import Foundation
import XCTest

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

    /// A recorded exchange (`order-created.json`, `order-replay.json`): status, headers and body.
    static func exchange(_ name: String) throws -> (status: Int, headers: [String: String], body: Data) {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data(name)) as? [String: Any])
        return (
            try XCTUnwrap(root["status"] as? Int),
            root["response_headers"] as? [String: String] ?? [:],
            try JSONSerialization.data(withJSONObject: try XCTUnwrap(root["body"]))
        )
    }
}
