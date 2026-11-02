import XCTest
@testable import App

/// api/06 10.9: `status` accepts todo, the six names and all.
final class OrderListQueryStatusTests: XCTestCase {
    func testTodoIsTheFourOpenStepsAndAllIsEverything() {
        XCTAssertEqual(OrderListQuery.StatusFilter(word: "todo")?.statuses, OrderStatus.open)
        XCTAssertNil(OrderListQuery.StatusFilter(word: "all")?.statuses)
        XCTAssertNotNil(OrderListQuery.StatusFilter(word: "all"))
    }

    func testEachOfTheSixNamesFiltersOneStatus() {
        for status in OrderStatus.allCases {
            XCTAssertEqual(OrderListQuery.StatusFilter(word: status.rawValue)?.statuses, [status])
        }
    }

    func testOldAndUnknownWordsAreRefused() {
        for word in ["New", "Confirmed", "Completed", "", "TODO", "received"] {
            XCTAssertNil(OrderListQuery.StatusFilter(word: word), word)
        }
    }

    func testTheDefaultFilterIsTodo() { XCTAssertEqual(OrderListQuery().status, .todo) }
}
