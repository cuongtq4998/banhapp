import XCTest
import BanhContracts
@testable import App

final class AvailabilityServiceTests: XCTestCase {
    private func makeService(
        rules: AvailabilityRules = AvailabilityTestData.rules,
        loads: [BusinessDate: Int] = AvailabilityTestData.fixtureLoads,
        now: Date = AvailabilityTestData.clock.instant
    ) -> (AvailabilityService, FakeAvailabilityRepository) {
        let repository = FakeAvailabilityRepository(rules: rules, accepted: loads)
        return (AvailabilityService(repository: repository, calendar: ShopCalendar(clock: FixedWallClock(instant: now))), repository)
    }

    private func entries(_ cakes: Int?, service: AvailabilityService) async throws -> [String: AvailabilityDate] {
        let response = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: cakes)
        return Dictionary(uniqueKeysWithValues: response.dates.map { ($0.date, $0) })
    }

    private func assertInvalidCakes(_ cakes: Int?, rules: AvailabilityRules = AvailabilityTestData.rules, line: UInt = #line) async {
        let (service, _) = makeService(rules: rules)
        do {
            _ = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: cakes)
            XCTFail("Expected VALIDATION_FAILED for \(String(describing: cakes))", line: line)
        } catch let error as APIError {
            XCTAssertEqual(error.code, .validationFailed, line: line)
            XCTAssertEqual(error.fields?.map(\.field), ["cakes"], line: line)
        } catch {
            XCTFail("Unexpected error \(error)", line: line)
        }
    }

    // MARK: validation

    func testMissingZeroNegativeAndOverMaxCakesAreRejected() async {
        await assertInvalidCakes(nil)
        await assertInvalidCakes(0)
        await assertInvalidCakes(-1)
        await assertInvalidCakes(397) // 4 products times 99, plus one
    }

    func testMaxIsMaxQtyPerCakeTimesActiveProducts() async throws {
        let (service, _) = makeService()
        _ = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 396)
        _ = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 1)

        let twoProducts = AvailabilityRules(leadDays: 2, maxDaysAhead: 30, dailyLimit: 100, activeProductCount: 2, maxQtyPerCake: 99)
        await assertInvalidCakes(199, rules: twoProducts)
        let none = AvailabilityRules(leadDays: 2, maxDaysAhead: 30, dailyLimit: 100, activeProductCount: 0, maxQtyPerCake: 99)
        await assertInvalidCakes(1, rules: none)
    }

    // MARK: lead time and horizon

    func testListRunsFromTodayToTheHorizonInclusive() async throws {
        let (service, _) = makeService()
        let response = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 3)
        XCTAssertEqual(response.serverDate, "2026-11-02")
        XCTAssertEqual(response.dates.count, 31)
        XCTAssertEqual(response.dates.first?.date, "2026-11-02")
        XCTAssertEqual(response.dates.last?.date, "2026-12-02")
        XCTAssertEqual(response.dates.map(\.date), response.dates.map(\.date).sorted())
    }

    func testLeadTimeBoundary() async throws {
        let (service, _) = makeService()
        let list = try await entries(3, service: service)
        XCTAssertEqual(list["2026-11-02"]?.reason, .tooSoon)
        XCTAssertEqual(list["2026-11-03"]?.reason, .tooSoon)
        XCTAssertEqual(list["2026-11-04"], AvailabilityDate(date: "2026-11-04", available: true, reason: nil))
    }

    func testZeroLeadDaysMakesTodayAvailable() async throws {
        let rules = AvailabilityRules(leadDays: 0, maxDaysAhead: 5, dailyLimit: 100, activeProductCount: 4, maxQtyPerCake: 99)
        let (service, _) = makeService(rules: rules, loads: [:])
        let list = try await entries(3, service: service)
        XCTAssertEqual(list["2026-11-02"]?.available, true)
    }

    func testHorizonBoundaryAndNoTooFarEntry() async throws {
        let (service, repository) = makeService()
        let list = try await entries(3, service: service)
        XCTAssertEqual(list["2026-12-02"]?.available, true)
        XCTAssertNil(list["2026-12-03"])
        XCTAssertFalse(list.values.contains { $0.reason == .tooFar })
        XCTAssertEqual(repository.requestedRanges, [AvailabilityTestData.date("2026-11-02")...AvailabilityTestData.date("2026-12-02")])
    }

    func testHorizonEqualToLeadLeavesOneBookableDate() async throws {
        let rules = AvailabilityRules(leadDays: 2, maxDaysAhead: 2, dailyLimit: 100, activeProductCount: 4, maxQtyPerCake: 99)
        let (service, _) = makeService(rules: rules, loads: [:])
        let response = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 3)
        XCTAssertEqual(response.dates.map(\.available), [false, false, true])
    }

    // MARK: capacity

    func testFullWhenRemainingIsLessThanCakes() async throws {
        let (service, _) = makeService()
        let list = try await entries(3, service: service)
        XCTAssertEqual(list["2026-11-05"], AvailabilityDate(date: "2026-11-05", available: false, reason: .full)) // remaining 2
        XCTAssertEqual(list["2026-11-20"]?.reason, .full) // remaining 0
    }

    func testExactFitIsAvailable() async throws {
        let (service, _) = makeService()
        let list = try await entries(3, service: service) // 2026-11-04 holds 97, remaining 3
        XCTAssertEqual(list["2026-11-04"]?.available, true)
        let four = try await entries(4, service: service)
        XCTAssertEqual(four["2026-11-04"]?.reason, .full)
    }

    func testDateWithoutDayLoadRowHoldsTheWholeLimit() async throws {
        let (service, _) = makeService(loads: [:])
        let list = try await entries(100, service: service)
        XCTAssertEqual(list["2026-11-10"]?.available, true)
        let over = try await entries(101, service: service)
        XCTAssertEqual(over["2026-11-10"]?.reason, .full)
    }

    func testTooSoonWinsOverFull() async throws {
        let loads = [AvailabilityTestData.date("2026-11-03"): 100]
        let (service, _) = makeService(loads: loads)
        let list = try await entries(3, service: service)
        XCTAssertEqual(list["2026-11-03"]?.reason, .tooSoon)
    }

    func testCurrentDailyLimitIsUsedNotTheStoredOne() async throws {
        // The owner lowered the limit to 90 after 95 were accepted: no room left.
        let rules = AvailabilityRules(leadDays: 2, maxDaysAhead: 30, dailyLimit: 90, activeProductCount: 4, maxQtyPerCake: 99)
        let (service, _) = makeService(rules: rules, loads: [AvailabilityTestData.date("2026-11-10"): 95])
        let list = try await entries(1, service: service)
        XCTAssertEqual(list["2026-11-10"]?.reason, .full)
    }

    // MARK: Vietnam date

    func testMidnightRolloverFollowsVietnamTime() async throws {
        // 23:59 on 11-02 in Vietnam is still 11-02 (16:59 UTC)...
        let before = AvailabilityTestData.shopInstant("2026-11-02", hour: 23, minute: 59)
        let (earlier, _) = makeService(now: before)
        let first = try await earlier.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 3)
        XCTAssertEqual(first.serverDate, "2026-11-02")
        XCTAssertEqual(first.dates.first?.date, "2026-11-02")

        // ...and one minute later the list starts on 11-03 and 11-04 is now too soon.
        let after = AvailabilityTestData.shopInstant("2026-11-03", hour: 0, minute: 0)
        let (later, _) = makeService(loads: [:], now: after)
        let second = try await later.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 3)
        XCTAssertEqual(second.serverDate, "2026-11-03")
        XCTAssertEqual(second.dates.first?.date, "2026-11-03")
        XCTAssertEqual(second.dates.last?.date, "2026-12-03")
        XCTAssertEqual(second.dates.prefix(3).map(\.reason), [.tooSoon, .tooSoon, nil])
    }

    func testUTCDateBehindVietnamDoesNotLeakIn() async throws {
        // 2026-11-02 18:00 UTC is already 2026-11-03 01:00 in Vietnam.
        let utcEvening = Date(timeIntervalSince1970: 1_793_642_400)
        let (service, _) = makeService(now: utcEvening)
        let response = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 3)
        XCTAssertEqual(response.serverDate, "2026-11-03")
    }

    func testMonthAndYearBoundariesAreCrossedByTheCalendar() async throws {
        let now = AvailabilityTestData.shopInstant("2026-12-30", hour: 9, minute: 0)
        let rules = AvailabilityRules(leadDays: 2, maxDaysAhead: 3, dailyLimit: 100, activeProductCount: 4, maxQtyPerCake: 99)
        let (service, _) = makeService(rules: rules, loads: [:], now: now)
        let response = try await service.makeAvailability(shopID: AppConfig.testShopID, requestedCakes: 1)
        XCTAssertEqual(response.dates.map(\.date), ["2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02"])
    }

    // MARK: BusinessDate parsing

    func testBusinessDateParsesOnlyTheWireForm() {
        XCTAssertEqual(BusinessDate(isoString: "2026-11-02"), BusinessDate(year: 2026, month: 11, day: 2))
        for bad in ["", "2026-1-02", "2026-13-01", "2026-11-32", "20261102", "2026-11-02T00", "abcd-ef-gh"] {
            XCTAssertNil(BusinessDate(isoString: bad), bad)
        }
    }
}
