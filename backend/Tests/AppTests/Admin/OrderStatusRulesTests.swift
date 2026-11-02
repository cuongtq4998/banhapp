import XCTest
@testable import App

/// BR-2 (order-process.md section 2): every from/to pair, the cancel
/// limit and the actions per status. Pure rules, no database.
final class OrderStatusRulesTests: XCTestCase {
    private typealias Pair = [OrderStatus]
    private let allowedPairs: [Pair] = [
        [.received, .processing], [.processing, .deliveryDateScheduled],
        [.deliveryDateScheduled, .deliveryStarted], [.deliveryStarted, .finished],
        [.received, .cancelled], [.processing, .cancelled]
    ]

    func testEveryPairIsAllowedOnlyWhenListed() {
        for from in OrderStatus.allCases {
            for to in OrderStatus.allCases {
                XCTAssertEqual(from.canMove(to: to), allowedPairs.contains([from, to]), "\(from) to \(to)")
            }
        }
    }

    func testThereAreSixCasesAndSixAllowedPairsOutOfThirtySix() {
        XCTAssertEqual(OrderStatus.allCases.count, 6)
        let count = OrderStatus.allCases.flatMap { from in OrderStatus.allCases.map { from.canMove(to: $0) } }.filter { $0 }.count
        XCTAssertEqual(count, 6)
    }

    func testCancelIsAllowedOnlyBeforeTheDeliveryDateIsScheduled() {
        for from in OrderStatus.allCases {
            let expected = from == .received || from == .processing
            XCTAssertEqual(from.canMove(to: .cancelled), expected, "\(from)")
        }
    }

    func testNoStepIsSkippedAndFinalStatesAreLeftForNowhere() {
        XCTAssertFalse(OrderStatus.processing.canMove(to: .deliveryStarted))
        XCTAssertFalse(OrderStatus.deliveryDateScheduled.canMove(to: .finished))
        XCTAssertFalse(OrderStatus.processing.canMove(to: .finished))
        for final in OrderStatus.final {
            for to in OrderStatus.allCases { XCTAssertFalse(final.canMove(to: to), "\(final) to \(to)") }
        }
    }

    func testFinishedIsReachedOnlyFromDeliveryStarted() {
        for from in OrderStatus.allCases {
            XCTAssertEqual(from.canMove(to: .finished), from == .deliveryStarted, "\(from)")
        }
    }

    func testNoStatusMovesToItself() {
        for status in OrderStatus.allCases { XCTAssertFalse(status.canMove(to: status), "\(status)") }
    }

    func testOnlyTheFourWorkingStepsAreOpen() {
        let open = OrderStatus.allCases.filter(\.isOpen)
        XCTAssertEqual(open, [.received, .processing, .deliveryDateScheduled, .deliveryStarted])
        XCTAssertEqual(OrderStatus.open, open)
        XCTAssertFalse(OrderStatus.finished.isOpen)
        XCTAssertFalse(OrderStatus.cancelled.isOpen)
    }

    func testAllowedActionsOfEveryStatusAgainstEveryAction() {
        let table: [OrderStatus: Set<OrderAction>] = [
            .received: [.process, .cancel],
            .processing: [.scheduleDelivery, .cancel],
            .deliveryDateScheduled: [.startDelivery, .changeDate],
            .deliveryStarted: [.finish, .correctFee],
            .finished: [], .cancelled: []
        ]
        for status in OrderStatus.allCases {
            for action in OrderAction.allCases {
                XCTAssertEqual(status.allowedActions.contains(action), table[status]?.contains(action), "\(status) \(action)")
            }
            XCTAssertEqual(status.allowedActions.count, table[status]?.count, "\(status) has no repeats")
        }
    }

    func testCancelActionIsOfferedExactlyWhereCancelIsAllowed() {
        for status in OrderStatus.allCases {
            XCTAssertEqual(status.allowedActions.contains(.cancel), status.canMove(to: .cancelled), "\(status)")
        }
    }

    func testRawValuesAreTheContractWords() {
        XCTAssertEqual(OrderStatus.allCases.map(\.rawValue),
                       ["Received", "Processing", "DeliveryDateScheduled", "DeliveryStarted", "Finished", "Cancelled"])
    }
}
