import XCTest

final class BanhAppTests: XCTestCase {
    /// Guards ADR-0005: the app declares iOS 17.0 as its minimum, so a project-setting
    /// regression (for example back to the template's iOS 15) fails a test.
    func testMinimumOSVersionMatchesAdr0005() throws {
        let host = Bundle(identifier: "app.banh.customer")
        let minimum = host?.object(forInfoDictionaryKey: "MinimumOSVersion") as? String
        XCTAssertEqual(minimum, "17.0")
    }
}
