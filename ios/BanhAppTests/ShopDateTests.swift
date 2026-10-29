import XCTest
@testable import BanhApp

final class ShopDateTests: XCTestCase {
    func testParsesIsoAndFormatsAsDayMonthYear() throws {
        let date = try XCTUnwrap(ShopDate(iso: "2026-11-04"))
        XCTAssertEqual(date.displayText, "04/11/2026")
        XCTAssertEqual(date.iso, "2026-11-04")
    }

    func testRejectsTextThatIsNotARealDate() {
        for text in ["", "2026-13-01", "2026-02-30", "2026-1-01", "26-11-04", "2026/11/04", "abc", "2026-11-04T00:00"] {
            XCTAssertNil(ShopDate(iso: text), text)
        }
    }

    func testAddingDaysCrossesMonthAndYearAndLeapDay() {
        XCTAssertEqual(ShopDate(year: 2026, month: 12, day: 31).adding(days: 1).iso, "2027-01-01")
        XCTAssertEqual(ShopDate(year: 2028, month: 2, day: 28).adding(days: 1).iso, "2028-02-29")
        XCTAssertEqual(ShopDate(year: 2026, month: 11, day: 2).adding(days: 30).iso, "2026-12-02")
    }

    func testWeekdayStartsOnMonday() {
        XCTAssertEqual(ShopDate(year: 2026, month: 11, day: 2).weekdayIndex, 0) // Monday
        XCTAssertEqual(ShopDate(year: 2026, month: 11, day: 1).weekdayIndex, 6) // Sunday
        XCTAssertEqual(ShopDate(year: 2026, month: 11, day: 7).weekdayIndex, 5) // Saturday
    }

    func testMonthArithmetic() {
        let date = ShopDate(year: 2026, month: 11, day: 20)
        XCTAssertEqual(date.daysInMonth, 30)
        XCTAssertEqual(date.adding(months: 2).iso, "2027-01-01")
        XCTAssertEqual(ShopDate(year: 2027, month: 1, day: 5).monthsSince(date), 2)
        XCTAssertEqual(date.firstOfMonth.iso, "2026-11-01")
    }

    func testOrderingFollowsTheCalendar() {
        XCTAssertLessThan(ShopDate(year: 2026, month: 11, day: 30), ShopDate(year: 2026, month: 12, day: 1))
    }

    func testDevicePreferencesDoNotMatter() {
        // Shifting uses a fixed calendar, so a date never moves with the device time zone.
        XCTAssertEqual(ShopDate(year: 2026, month: 3, day: 29).adding(days: 1).iso, "2026-03-30")
    }
}
