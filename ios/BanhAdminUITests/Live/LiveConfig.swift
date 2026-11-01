import Foundation
import XCTest

/// Settings of the live operating-flow run (docs/engineering/dev-guide.md, "Live end-to-end run").
/// Everything comes from environment variables (`TEST_RUNNER_<NAME>` on the xcodebuild command line), so
/// the normal test plan, which sets none of them, skips every live test.
enum Live {
    private static let env = ProcessInfo.processInfo.environment

    static var enabled: Bool { env["E2E_LIVE"] == "1" }
    static var reuseOrders: Bool { env["E2E_REUSE_ORDERS"] == "1" }
    static var baseURL: URL { URL(string: env["E2E_API_BASE_URL"] ?? "http://127.0.0.1:8080")! }
    /// Folder for the state file, the numbered screenshots and the backend log.
    static var directory: URL { URL(fileURLWithPath: env["E2E_DIR"] ?? NSTemporaryDirectory()) }
    static var shotsDirectory: URL { URL(fileURLWithPath: env["E2E_SHOTS_DIR"] ?? directory.appending(path: "ios").path) }
    /// The console output of the backend under test (the one-time codes and the log audit read it).
    static var logURL: URL { URL(fileURLWithPath: env["E2E_BACKEND_LOG"] ?? directory.appending(path: "backend-ios.log").path) }
    static var stateURL: URL { directory.appending(path: "ios-state.json") }

    static let customerBundle = "app.banh.customer"
    static let adminBundle = "app.banh.admin"

    /// Fake people. The phone is a fake number of the 090000xxxx range.
    static let ownerEmail = "owner.demo@example.com"
    static let staffEmail = "staff.ios@example.com"
    static let staffName = "Staff Ios"
    static let customerPhone = "0900000101"

    static func requireEnabled() throws {
        try XCTSkipUnless(enabled, "live end-to-end test: set TEST_RUNNER_E2E_LIVE=1 (needs a running backend)")
    }
}

/// One order placed through the customer app, as the customer typed it.
struct LiveOrder: Codable {
    var code: String
    var name: String
    var phone: String
    var address: String
    var district: String
    var date: String
    var total: String
}

/// State shared between the test methods (and readable after a crash): the orders and what was found.
struct LiveState: Codable {
    var order1: LiveOrder?
    var order2: LiveOrder?
    var cakeName: String?
    var cakeID: String?
    var notes: [String] = []

    static func load() -> LiveState {
        guard let data = try? Data(contentsOf: Live.stateURL), let state = try? JSONDecoder().decode(LiveState.self, from: data)
        else { return LiveState() }
        return state
    }

    func save() {
        try? FileManager.default.createDirectory(at: Live.directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) { try? data.write(to: Live.stateURL) }
    }
}
