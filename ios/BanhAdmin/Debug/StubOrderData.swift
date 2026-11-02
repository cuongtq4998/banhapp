#if DEBUG
import Foundation

/// The fake shop of the UI tests; mirrors `contracts/fixtures/admin/orders-list.json` and `order-detail.json`
/// (fake names, fake phone numbers). Server date 2026-11-02.
nonisolated enum StubOrderData {
    static let serverDate = "2026-11-02"

    static func allowedActions(for status: OrderStatus) -> [OrderAction] {
        switch status {
        case .received: [.cancel, .process]
        case .processing: [.cancel, .scheduleDelivery]
        case .deliveryDateScheduled: [.changeDate, .startDelivery]
        case .deliveryStarted: [.correctFee, .finish]
        case .finished, .cancelled, .unknown: []
        }
    }

    private static func order(
        _ code: String, _ status: OrderStatus, _ name: String, _ date: String, _ start: String, _ end: String,
        cakes: Int, district: String, phone: String, note: String? = nil, reason: String? = nil
    ) -> OrderDetail {
        let unit = 50_000
        let fee = 20_000
        let line = cakes * unit
        let actions = allowedActions(for: status)
        return OrderDetail(
            orderCode: code, status: status, customerName: name, deliveryDate: date,
            requestedDeliveryDate: date, expectedDeliveryDate: nil, listDate: date,
            slot: DeliverySlot(start: start, end: end), totalCakes: cakes, totalVnd: line + fee, districtName: district,
            createdAt: "2026-10-31T03:15:09Z", customerPhone: phone, customerAddress: "1 Test Street", note: note,
            items: [OrderItem(productName: "Banh Mau", quantity: cakes, unitPriceVnd: unit, lineTotalVnd: line)],
            itemsSubtotalVnd: line, deliveryFeeVnd: fee, deliveryFeeEstimateVnd: fee, deliveryFeeFinalVnd: nil,
            amountToCollectVnd: nil, deliveryFeeEntry: nil, cancelReason: reason, expectedDateRange: nil,
            allowedActions: actions, dateChanges: [], feeCorrections: [],
            lastChange: LastChange(actorName: nil, at: "2026-10-31T03:15:09Z", kind: nil)
        )
    }

    /// Six orders: one due today, one two days overdue, two open later, one completed, one cancelled.
    static var orders: [OrderDetail] {
        [
            order("BT-7K3M9Q", .received, "Tran Thi B", "2026-11-02", "08:00", "10:00", cakes: 2, district: "Quan An Phu",
                  phone: "+84900000010", note: "It duong"),
            order("BT-4H8N2P", .processing, "Le Van C", "2026-10-31", "10:00", "12:00", cakes: 3, district: "Quan Binh An",
                  phone: "+84900000011"),
            order("BT-9D6R3T", .received, "Pham Thi D", "2026-11-03", "14:00", "16:00", cakes: 1, district: "Quan An Phu",
                  phone: "+84900000012"),
            order("BT-2C5W7X", .processing, "Hoang Van E", "2026-11-04", "16:00", "18:00", cakes: 4, district: "Quan Binh An",
                  phone: "+84900000013"),
            order("BT-6F3J8M", .finished, "Vo Thi F", "2026-10-30", "08:00", "10:00", cakes: 2, district: "Quan An Phu",
                  phone: "+84900000014"),
            order("BT-8B2K4N", .cancelled, "Dang Van G", "2026-10-29", "14:00", "16:00", cakes: 1, district: "Quan An Phu",
                  phone: "+84900000015", reason: CancelReason.customerAsked.rawValue),
        ]
    }

    /// The order after a status change by the fake staff member.
    static func changed(_ detail: OrderDetail, to status: OrderStatus, reason: CancelReason?) -> OrderDetail {
        let actions = allowedActions(for: status)
        return OrderDetail(
            orderCode: detail.orderCode, status: status, customerName: detail.customerName, deliveryDate: detail.deliveryDate,
            requestedDeliveryDate: detail.requestedDeliveryDate, expectedDeliveryDate: detail.expectedDeliveryDate,
            listDate: detail.listDate, slot: detail.slot, totalCakes: detail.totalCakes, totalVnd: detail.totalVnd, districtName: detail.districtName,
            createdAt: detail.createdAt, customerPhone: detail.customerPhone, customerAddress: detail.customerAddress,
            note: detail.note, items: detail.items, itemsSubtotalVnd: detail.itemsSubtotalVnd,
            deliveryFeeVnd: detail.deliveryFeeVnd, deliveryFeeEstimateVnd: detail.deliveryFeeEstimateVnd,
            deliveryFeeFinalVnd: nil, amountToCollectVnd: nil, deliveryFeeEntry: nil, cancelReason: reason?.rawValue,
            expectedDateRange: nil, allowedActions: actions, dateChanges: [], feeCorrections: [],
            lastChange: LastChange(actorName: "Nhan Vien A", at: "2026-11-02T04:00:00Z", kind: "status")
        )
    }

    static func summary(_ detail: OrderDetail) -> OrderSummary {
        OrderSummary(
            orderCode: detail.orderCode, status: detail.status, customerName: detail.customerName,
            deliveryDate: detail.deliveryDate, expectedDeliveryDate: detail.expectedDeliveryDate,
            listDate: detail.listDate ?? detail.deliveryDate, slot: detail.slot, totalCakes: detail.totalCakes,
            totalVnd: detail.totalVnd, districtName: detail.districtName, createdAt: detail.createdAt
        )
    }

    /// Letters and digits only, lower case, no accents: "BT-7K3M9Q" and "7k3m9q" both match.
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
    }

    static func matches(_ order: OrderDetail, query: String) -> Bool {
        let needle = fold(query).replacingOccurrences(of: "bt-", with: "")
        let digits = query.filter(\.isNumber)
        return fold(order.orderCode).contains(needle) || fold(order.customerName).contains(needle)
            || (digits.count >= 3 && order.customerPhone.contains(digits))
    }
}
#endif
