import XCTVapor
@testable import App

/// The date filters match the list date, not the requested date.
final class OrderListDateFilterTests: AdminOrderTestCase {
    /// Both `delivery_date` and `date_preset` match list_date.
    func testDateAndPresetFiltersMatchTheListDateNotTheRequestedDate() async throws {
        let staff = try await phone(.staff)
        let moved = try await place(.init(status: "DeliveryDateScheduled", date: day(0), expectedDate: day(1)))
        let plain = try await place(.init(date: day(1)))
        let stays = try await place(.init(date: day(0)))
        let tomorrow = try await listCodes(staff, "delivery_date=\(day(1))")
        XCTAssertEqual(Set(tomorrow), [moved, plain])
        let today = try await listCodes(staff, "date_preset=today")
        XCTAssertEqual(today, [stays])
        let preset = try await listCodes(staff, "date_preset=tomorrow")
        XCTAssertEqual(Set(preset), [moved, plain])
    }
}
