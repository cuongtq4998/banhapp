import XCTest
import BanhContracts
@testable import App

final class PushTokenRequestTests: XCTestCase {
    private func parse(_ json: String) throws -> PushTokenRequest {
        try PushTokenRequest.parse(JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8)))
    }

    private func field(_ json: String, line: UInt = #line) -> String? {
        do { _ = try parse(json); XCTFail("accepted", line: line); return nil } catch let error as APIError {
            XCTAssertEqual(error.code, .validationFailed, line: line)
            return error.fields?.first?.field
        } catch { XCTFail("\(error)", line: line); return nil }
    }

    func testIOSNeedsAnEnvironment() throws {
        let ok = try parse(#"{"platform":"ios","token":"abc","apns_environment":"sandbox"}"#)
        XCTAssertEqual(ok, PushTokenRequest(platform: .ios, token: "abc", apnsEnvironment: "sandbox"))
        XCTAssertEqual(field(#"{"platform":"ios","token":"abc"}"#), "apns_environment")
        XCTAssertEqual(field(#"{"platform":"ios","token":"abc","apns_environment":"beta"}"#), "apns_environment")
        XCTAssertEqual(field(#"{"platform":"ios","token":"abc","apns_environment":null}"#), "apns_environment")
    }

    func testAndroidIgnoresTheEnvironment() throws {
        XCTAssertEqual(try parse(#"{"platform":"android","token":"a:b-c_d"}"#).apnsEnvironment, nil)
        XCTAssertEqual(try parse(#"{"platform":"android","token":"t","apns_environment":"sandbox"}"#).apnsEnvironment, nil)
    }

    func testPlatformAndTokenRules() throws {
        XCTAssertEqual(field(#"{"platform":"web","token":"abc"}"#), "platform")
        XCTAssertEqual(field(#"{"token":"abc"}"#), "platform")
        XCTAssertEqual(field(#"{"platform":5,"token":"abc"}"#), "platform")
        XCTAssertEqual(field(#"{"platform":"android"}"#), "token")
        XCTAssertEqual(field(#"{"platform":"android","token":""}"#), "token")
        XCTAssertEqual(field(#"{"platform":"android","token":7}"#), "token")
        XCTAssertEqual(field(#"{"platform":"android","token":"a b"}"#), "token")
        XCTAssertEqual(field(#"{"platform":"android","token":"a\nb"}"#), "token")
        XCTAssertEqual(field(#"{"platform":"android","token":"\#(String(repeating: "x", count: 513))"}"#), "token")
        XCTAssertEqual(try parse(#"{"platform":"android","token":"\#(String(repeating: "x", count: 512))"}"#).token.count, 512)
    }

    func testUnknownKeysAreRefused() {
        XCTAssertEqual(field(#"{"platform":"android","token":"abc","name":"x"}"#), "name")
    }
}
