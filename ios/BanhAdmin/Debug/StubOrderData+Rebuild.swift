#if DEBUG
import Foundation

extension StubOrderData {
    /// One order after a change: unchanged fields stay, the date and fee lists grow, the totals follow the fee.
    static func rebuilt(
        _ detail: OrderDetail, status: OrderStatus, reason: String? = nil, expected: String? = nil, finalFee: Int? = nil,
        dateChange: DateChange? = nil, feeCorrection: FeeCorrection? = nil
    ) -> OrderDetail {
        let fee = finalFee ?? detail.deliveryFeeFinalVnd
        return OrderDetail(
            orderCode: detail.orderCode, status: status, customerName: detail.customerName, deliveryDate: detail.deliveryDate,
            requestedDeliveryDate: detail.requestedDeliveryDate, expectedDeliveryDate: expected ?? detail.expectedDeliveryDate,
            listDate: detail.listDate, slot: detail.slot, totalCakes: detail.totalCakes,
            totalVnd: fee.map { detail.itemsSubtotalVnd + $0 } ?? detail.totalVnd, districtName: detail.districtName,
            createdAt: detail.createdAt, customerPhone: detail.customerPhone, customerAddress: detail.customerAddress,
            note: detail.note, items: detail.items, itemsSubtotalVnd: detail.itemsSubtotalVnd,
            deliveryFeeVnd: fee ?? detail.deliveryFeeVnd, deliveryFeeEstimateVnd: detail.deliveryFeeEstimateVnd,
            deliveryFeeFinalVnd: fee, amountToCollectVnd: fee.map { detail.itemsSubtotalVnd + $0 },
            deliveryFeeEntry: fee == nil ? nil : FeeEntry(enteredByName: "Nhan Vien A", enteredAt: "2026-11-02T04:00:00Z"),
            cancelReason: reason ?? detail.cancelReason, expectedDateRange: range(for: status),
            allowedActions: allowedActions(for: status), dateChanges: detail.dateChanges + [dateChange].compactMap { $0 },
            feeCorrections: detail.feeCorrections + [feeCorrection].compactMap { $0 },
            lastChange: LastChange(actorName: "Nhan Vien A", at: "2026-11-02T04:00:00Z", kind: "status")
        )
    }
}
#endif
