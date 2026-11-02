import XCTest
@testable import App

/// BR-9: open orders of any age, final orders for 90 days from placement.
final class OrderWindowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var window: OrderWindow { OrderWindow(shopID: UUID(), now: now, demoOnly: false) }
    private func ago(days: Double, seconds: Double = 0) -> Date { now.addingTimeInterval(-days * 86_400 - seconds) }

    func testOpenOrdersAreShownAtAnyAge() {
        for status in OrderStatus.open {
            XCTAssertTrue(window.shows(status: status, placedAt: ago(days: 1000)), "\(status)")
        }
    }

    func testFinalOrdersAreShownUpToExactlyNinetyDays() {
        for status in OrderStatus.final {
            XCTAssertTrue(window.shows(status: status, placedAt: ago(days: Double(OrderWindow.finalDays))), "\(status) at 90 days")
            XCTAssertFalse(window.shows(status: status, placedAt: ago(days: Double(OrderWindow.finalDays), seconds: 1)), "\(status) past 90")
            XCTAssertTrue(window.shows(status: status, placedAt: now), "\(status) today")
        }
    }

    func testTheWindowIsNinetyDays() { XCTAssertEqual(OrderWindow.finalDays, 90) }

    func testListDateIsTheExpectedDateWhenSetElseTheRequestedDate() {
        XCTAssertEqual(OrderListDate.value(expected: "2026-11-05", requested: "2026-11-03"), "2026-11-05")
        XCTAssertEqual(OrderListDate.value(expected: nil, requested: "2026-11-03"), "2026-11-03")
    }
}
