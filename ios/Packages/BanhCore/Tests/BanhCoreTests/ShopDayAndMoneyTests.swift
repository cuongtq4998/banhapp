import Testing
@testable import BanhCore

struct ShopDayAndMoneyTests {
    @Test func moneyGroupsThousandsWithDots() {
        #expect(MoneyFormatter.format(0) == "0 ₫")
        #expect(MoneyFormatter.format(999) == "999 ₫")
        #expect(MoneyFormatter.format(120_000) == "120.000 ₫")
        #expect(MoneyFormatter.format(1_250_000) == "1.250.000 ₫")
    }

    @Test func daysBetweenDatesAcrossMonthAndLeapYear() throws {
        let server = try #require(ShopDay("2026-11-02"))
        #expect(try #require(ShopDay("2026-11-02")).days(since: server) == 0)
        #expect(try #require(ShopDay("2026-10-31")).days(since: server) == -2)
        #expect(try #require(ShopDay("2026-11-03")).days(since: server) == 1)
        #expect(try #require(ShopDay("2028-03-01")).days(since: ShopDay("2028-02-28")!) == 2)
        #expect(try #require(ShopDay("2027-01-01")).days(since: ShopDay("2026-12-31")!) == 1)
    }

    @Test func addingDaysRoundTripsAndFormats() throws {
        let day = try #require(ShopDay("2026-12-31"))
        #expect(day.adding(days: 1).wire == "2027-01-01")
        #expect(day.adding(days: -365).wire == "2025-12-31")
        #expect(day.shortText == "31/12")
        #expect(day.longText == "31/12/2026")
        #expect(try #require(ShopDay("2026-03-05")).shortText == "05/03")
    }

    @Test func rejectsMalformedDates() {
        for text in ["", "2026-1-02", "26-11-02", "2026-13-01", "2026-11-00", "abcd-11-02", "2026-11-02T00"] {
            #expect(ShopDay(text) == nil, "\(text)")
        }
    }
}
