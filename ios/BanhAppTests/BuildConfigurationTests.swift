import XCTest
@testable import BanhApp

final class BuildConfigurationTests: XCTestCase {
    /// The base URL comes from the build setting, not from code: this proves the xcconfig value
    /// reaches Info.plist (a broken merge would stop the app at start).
    func testTheAppBundleCarriesAValidAPIBaseURLFromTheBuildSetting() throws {
        let host = try XCTUnwrap(Bundle(identifier: "app.banh.customer"))
        let url = BuildConfiguration.apiBaseURL(in: host)
        XCTAssertNotNil(url.host)
        XCTAssertTrue(["http", "https"].contains(url.scheme))
    }

    func testTheAppBundleHasAVersionForTheClientHeader() throws {
        let host = try XCTUnwrap(Bundle(identifier: "app.banh.customer"))
        XCTAssertNotEqual(BuildConfiguration.appVersion(in: host), "0")
    }
}
