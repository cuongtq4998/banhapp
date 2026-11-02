import XCTest
@testable import App

/// Legacy words are mapped on read; the stored word is never changed.
final class OrderStatusStoredTests: XCTestCase {
    func testLegacyWordsMapToTheNewSteps() {
        XCTAssertEqual(OrderStatus.fromStored("New"), .received)
        XCTAssertEqual(OrderStatus.fromStored("Confirmed"), .processing)
        XCTAssertEqual(OrderStatus.fromStored("Completed"), .finished)
        XCTAssertEqual(OrderStatus.fromStored("Cancelled"), .cancelled)
    }

    func testNewWordsPassThrough() {
        for status in OrderStatus.allCases { XCTAssertEqual(OrderStatus.fromStored(status.rawValue), status) }
    }

    func testUnknownAndWronglyCasedWordsAreNil() {
        for word in ["", "new", "RECEIVED", "Shipped", " Received"] { XCTAssertNil(OrderStatus.fromStored(word), word) }
    }

    func testSqlListQuotesTheGivenValuesInOrder() {
        XCTAssertEqual(OrderStatus.sqlList(OrderStatus.final), "'Finished', 'Cancelled'")
        XCTAssertEqual(OrderStatus.sqlList([]), "")
    }
}
