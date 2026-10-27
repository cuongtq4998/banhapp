import Foundation
import XCTest
@testable import BanhContracts

final class AvailabilityResponseTests: XCTestCase {
    func testDecodesTheOkFixture() throws {
        let response = try FixtureFiles.decode(AvailabilityResponse.self, from: "availability-ok.json")
        XCTAssertEqual(response.serverDate, "2026-11-02")
        XCTAssertEqual(response.dates.count, 31)
        XCTAssertEqual(response.dates.first, AvailabilityDate(date: "2026-11-02", available: false, reason: .tooSoon))
        XCTAssertEqual(response.dates.last?.date, "2026-12-02")
    }

    func testFixtureIsConsistent() throws {
        let response = try FixtureFiles.decode(AvailabilityResponse.self, from: "availability-ok.json")
        for entry in response.dates {
            XCTAssertEqual(entry.available, entry.reason == nil, entry.date)
        }
        XCTAssertEqual(Set(response.dates.compactMap(\.reason)), [.tooSoon, .full])
    }

    func testAvailableDateEncodesAnExplicitNullReason() throws {
        let data = try JSONEncoder().encode(AvailabilityDate(date: "2026-11-04", available: true, reason: nil))
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"reason\":null"))
    }
}
