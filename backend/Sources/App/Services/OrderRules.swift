import Foundation
import BanhContracts

/// The checks of api.md 4.3 that only read the request and the shop's data.
/// The date rules are the ones the availability list uses (`AvailabilityRules`).
enum OrderRules {
    /// Step 2, second half: the quantity limit from shop settings, reported as
    /// a field error like the rest of the validation. The number of lines needs
    /// no check of its own: duplicates are rejected by the parser, so more lines
    /// than active products means a hidden product, which is `PRODUCT_UNAVAILABLE`
    /// (AC-34).
    static func validateAgainstSettings(_ request: OrderRequest, rules: AvailabilityRules) throws {
        var errors: [OrderFieldError.Entry] = []
        for (index, line) in request.items.enumerated() where line.quantity > rules.maxQtyPerCake {
            errors.append(OrderFieldError.invalid("items[\(index)].quantity", code: "QUANTITY_INVALID"))
        }
        if !errors.isEmpty { throw APIError(.validationFailed, fields: errors) }
    }

    /// Step 4: unknown or inactive product, slot, district.
    static func requireUsableReferences(_ request: OrderRequest, data: OrderReferenceData) throws {
        let unavailable = request.items.map(\.productID).filter { data.products[$0]?.isActive != true }
        if !unavailable.isEmpty {
            let ids = unavailable.map { JSONValue.string($0.uuidString.lowercased()) }
            throw APIError(.productUnavailable, details: ["product_ids": .array(ids)])
        }
        guard data.slot?.isActive == true else { throw APIError(.slotUnavailable) }
        guard data.district?.isActive == true else { throw APIError(.districtUnserved) }
    }

    /// Step 5: minimum quantity, lead time, horizon. `today` is the shop-time
    /// date read once by the caller.
    static func requireAllowedOrder(
        _ request: OrderRequest, data: OrderReferenceData, today: BusinessDate, calendar: ShopCalendar
    ) throws {
        if request.totalCakes < data.minQty {
            throw APIError(.minQty, details: ["min_qty": .int(data.minQty)])
        }
        let rules = data.rules
        if request.deliveryDate < rules.firstBookableDate(today: today, calendar: calendar) {
            throw APIError(.dateLead, details: ["lead_days": .int(rules.leadDays)])
        }
        if request.deliveryDate > rules.lastBookableDate(today: today, calendar: calendar) {
            throw APIError(.dateHorizon, details: ["max_days_ahead": .int(rules.maxDaysAhead)])
        }
    }
}
