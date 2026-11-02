import Foundation
import Testing
@testable import BanhAdmin

struct OrderListLabelTests {
    @Test func filterWireValuesMatchTheContract() {
        let wire = OrderQuery.StatusFilter.allCases.map(\.rawValue)
        #expect(wire == ["todo", "Received", "Processing", "DeliveryDateScheduled", "DeliveryStarted", "Finished", "Cancelled", "all"])
    }

    @Test func eachStatusHasItsOwnName() {
        let names = [OrderStatus.received, .processing, .deliveryDateScheduled, .deliveryStarted, .finished, .cancelled]
            .map { String(localized: AStrings.status($0)) }
        #expect(names == ["Đã nhận đơn", "Đang xử lý", "Đã hẹn ngày giao", "Đang giao", "Đã hoàn thành", "Đã hủy"])
        #expect(Set(names).count == 6)
    }

    @Test func rowShowsTheExpectedDateWhenSet() {
        let plain = TestData.summary("BT-7K3M9Q")
        #expect(plain.rowDateText.contains("08:00"))
        let moved = OrderSummary(
            orderCode: plain.orderCode, status: .deliveryDateScheduled, customerName: plain.customerName,
            deliveryDate: "2026-11-02", expectedDeliveryDate: "2026-11-05", listDate: "2026-11-05", slot: plain.slot,
            totalCakes: 2, totalVnd: 1, districtName: "D", createdAt: plain.createdAt
        )
        #expect(moved.rowDateText == "Dự kiến 05/11")
    }

    @Test func dueMarkFollowsTheListDateForOpenStepsOnly() {
        #expect(DueState.of(status: .deliveryStarted, deliveryDate: "2026-11-02", serverDate: "2026-11-02") == .today)
        #expect(DueState.of(status: .deliveryDateScheduled, deliveryDate: "2026-11-05", serverDate: "2026-11-02") == nil)
        #expect(DueState.of(status: .finished, deliveryDate: "2026-11-01", serverDate: "2026-11-02") == nil)
    }
}
