import XCTest
@testable import App

final class PushConfigTests: XCTestCase {
    private func config(_ variables: [String: String], stage: String = "local") throws -> PushConfig {
        try PushConfig(environment: EnvironmentVariables(variables), stage: AppConfig.Stage(rawValue: stage) ?? .local)
    }

    private var live: [String: String] {
        [
            "PUSH_PROVIDER": "live", "APNS_KEY_ID": "K", "APNS_TEAM_ID": "T", "APNS_TOPIC": "app.example.admin",
            "APNS_PRIVATE_KEY": PushTestKeys.apns.pemRepresentation.replacingOccurrences(of: "\n", with: "\\n"),
            "FCM_PROJECT_ID": "p", "FCM_SERVICE_ACCOUNT_JSON": PushTestKeys.fcmCredentials.serviceAccountJSON
        ]
    }

    private func fails(_ variables: [String: String], stage: String = "local", _ expected: AppConfig.Failure, line: UInt = #line) {
        XCTAssertThrowsError(try config(variables, stage: stage), line: line) { XCTAssertEqual($0 as? AppConfig.Failure, expected, line: line) }
    }

    func testUnsetOrOffIsOff() throws {
        XCTAssertEqual(try config([:]), .off)
        XCTAssertEqual(try config(["PUSH_PROVIDER": "off"]).provider, .off)
    }

    func testRecordingIsRefusedInProduction() throws {
        XCTAssertEqual(try config(["PUSH_PROVIDER": "recording"]).provider, .recording)
        fails(["PUSH_PROVIDER": "recording"], stage: "production", .invalid("PUSH_PROVIDER"))
    }

    func testUnknownProviderIsRefused() {
        fails(["PUSH_PROVIDER": "console"], .invalid("PUSH_PROVIDER"))
    }

    func testLiveWithAllValuesRestoresLineBreaksInTheKey() throws {
        let parsed = try config(live, stage: "production")
        XCTAssertEqual(parsed.provider, .live)
        XCTAssertEqual(parsed.apns?.privateKey, PushTestKeys.apns.pemRepresentation)
        XCTAssertEqual(parsed.apns?.topic, "app.example.admin")
        XCTAssertEqual(parsed.fcm?.projectID, "p")
    }

    func testLiveNeedsEveryValue() {
        for name in ["APNS_KEY_ID", "APNS_TEAM_ID", "APNS_PRIVATE_KEY", "APNS_TOPIC", "FCM_PROJECT_ID", "FCM_SERVICE_ACCOUNT_JSON"] {
            var variables = live
            variables[name] = nil
            fails(variables, stage: "production", .missing(name))
        }
    }

    func testCredentialsWithoutTheSwitchStopTheStart() {
        fails(["APNS_KEY_ID": "K"], .missing("PUSH_PROVIDER"))
        fails(["FCM_PROJECT_ID": "p"], .missing("PUSH_PROVIDER"))
    }

    func testBrokenKeysAreRefusedAtStart() {
        var badKey = live
        badKey["APNS_PRIVATE_KEY"] = "not a key"
        fails(badKey, .invalid("APNS_PRIVATE_KEY"))
        var badJSON = live
        badJSON["FCM_SERVICE_ACCOUNT_JSON"] = "{}"
        fails(badJSON, .invalid("FCM_SERVICE_ACCOUNT_JSON"))
    }

    func testFailureNeverShowsTheValue() {
        var badKey = live
        badKey["APNS_PRIVATE_KEY"] = "secret-looking-text"
        XCTAssertThrowsError(try config(badKey)) { XCTAssertFalse("\($0)".contains("secret-looking-text")) }
    }

    func testAppConfigCarriesPushConfig() throws {
        var variables = live
        variables["APP_ENV"] = "staging"
        variables["PORT"] = "8080"
        variables["DATABASE_URL"] = "postgres://x@127.0.0.1:1/x"
        variables["SHOP_ID"] = UUID().uuidString
        XCTAssertEqual(try AppConfig(variables: variables).push.provider, .live)
    }
}
