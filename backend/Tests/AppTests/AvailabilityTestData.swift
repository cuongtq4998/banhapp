import Foundation
@testable import App

/// Rules and loads that reproduce the shared fixture `availability-ok.json`.
enum AvailabilityTestData {
    static let rules = AvailabilityRules(leadDays: 2, maxDaysAhead: 30, dailyLimit: 100, activeProductCount: 4, maxQtyPerCake: 99)

    static func date(_ text: String) -> BusinessDate { BusinessDate(isoString: text)! }

    /// 2026-11-04 holds 97 (exact fit for 3 cakes), 2026-11-05 holds 98 (too full), 2026-11-20 is at the limit.
    static let fixtureLoads: [BusinessDate: Int] = [
        date("2026-11-04"): 97, date("2026-11-05"): 98, date("2026-11-20"): 100
    ]

    /// 2026-11-02 at noon, shop time; the `server_date` of the fixture.
    static let clock = CatalogTestData.fixtureClock

    /// An instant for `YYYY-MM-DD HH:MM` in shop time (UTC+7).
    static func shopInstant(_ date: String, hour: Int, minute: Int) -> Date {
        let day = date.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: ShopCalendar.utcOffsetSeconds)!
        return calendar.date(from: DateComponents(year: day[0], month: day[1], day: day[2], hour: hour, minute: minute))!
    }
}
