import XCTest
@testable import App

final class WallClockAndCalendarTests: XCTestCase {
    private func instant(_ iso: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso))
    }

    func testBusinessDateIsVietnamDateAcrossUTCMidnight() throws {
        // 17:00 UTC is already the next day at UTC+7.
        let calendar = ShopCalendar(clock: FixedWallClock(instant: try instant("2026-10-26T17:00:00Z")))
        XCTAssertEqual(calendar.today().description, "2026-10-27")
        XCTAssertEqual(calendar.businessDate(of: try instant("2026-10-26T16:59:59Z")).description, "2026-10-26")
    }

    func testAddingDaysCrossesMonthAndYear() {
        let calendar = ShopCalendar(clock: SystemWallClock())
        let date = BusinessDate(year: 2026, month: 12, day: 30)
        XCTAssertEqual(calendar.adding(days: 3, to: date).description, "2027-01-02")
        XCTAssertEqual(calendar.adding(days: -30, to: date).description, "2026-11-30")
    }

    func testDatesCompareChronologically() {
        XCTAssertLessThan(BusinessDate(year: 2026, month: 2, day: 28), BusinessDate(year: 2026, month: 3, day: 1))
    }

    func testReplacingTheClockMovesTheCalendar() throws {
        var services = AppServices(
            clock: SystemWallClock(),
            databaseProbe: UnconfiguredProbe(),
            orderCodes: RandomOrderCodeGenerator()
        )
        services.clock = FixedWallClock(instant: try instant("2026-01-01T00:00:00Z"))
        XCTAssertEqual(services.calendar.today().description, "2026-01-01")
    }
}

final class OrderCodeGeneratorTests: XCTestCase {
    func testCodesMatchTheFormatAndTheDatabaseRule() throws {
        let generator = RandomOrderCodeGenerator()
        let regex = try NSRegularExpression(pattern: OrderCodeFormat.pattern)
        for _ in 0..<500 {
            let code = generator.makeCode()
            XCTAssertEqual(regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code)), 1, code)
        }
    }

    func testAlphabetExcludesLookalikes() {
        XCTAssertEqual(OrderCodeFormat.alphabet.count, 31)
        XCTAssertTrue(Set("01ILO").isDisjoint(with: OrderCodeFormat.alphabet))
    }

    func testIndexSourceDrivesTheCharacters() {
        let first = RandomOrderCodeGenerator(randomIndex: { _ in 0 })
        XCTAssertEqual(first.makeCode(), "BT-222222")
        let last = RandomOrderCodeGenerator(randomIndex: { $0 - 1 })
        XCTAssertEqual(last.makeCode(), "BT-ZZZZZZ")
    }

    func testCodesVary() {
        let generator = RandomOrderCodeGenerator()
        XCTAssertGreaterThan(Set((0..<50).map { _ in generator.makeCode() }).count, 45)
    }
}

final class DatabasePoolSizingTests: XCTestCase {
    func testProductNeverExceedsTheBudget() {
        for poolMax in 1...40 {
            for cores in 1...64 {
                let loops = DatabasePoolSizing.eventLoopCount(poolMax: poolMax, coreCount: cores)
                let perLoop = DatabasePoolSizing.connectionsPerLoop(poolMax: poolMax, eventLoopCount: loops)
                XCTAssertLessThanOrEqual(loops * perLoop, poolMax, "poolMax \(poolMax) cores \(cores)")
                XCTAssertGreaterThanOrEqual(perLoop, 1)
            }
        }
    }

    func testUsesAllCoresWhenBudgetAllows() {
        XCTAssertEqual(DatabasePoolSizing.eventLoopCount(poolMax: 20, coreCount: 4), 4)
        XCTAssertEqual(DatabasePoolSizing.connectionsPerLoop(poolMax: 20, eventLoopCount: 4), 5)
    }
}

final class DeadlineTests: XCTestCase {
    func testReturnsTheResultWhenFastEnough() async throws {
        let value = try await withDeadline(.seconds(5)) { 42 }
        XCTAssertEqual(value, 42)
    }

    func testFailsWhenTheOperationIsTooSlow() async {
        do {
            _ = try await withDeadline(.milliseconds(50)) { () -> Int in
                try await Task.sleep(for: .seconds(5))
                return 1
            }
            XCTFail("expected a deadline error")
        } catch {
            XCTAssertTrue(error is DeadlineExceededError)
        }
    }

    func testPropagatesTheOperationError() async {
        do {
            _ = try await withDeadline(.seconds(5)) { () -> Int in throw DatabaseProbeError() }
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error is DatabaseProbeError)
        }
    }
}
