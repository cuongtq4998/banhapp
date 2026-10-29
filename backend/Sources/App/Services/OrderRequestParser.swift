import Foundation
import BanhContracts

/// Turns the decoded JSON of `POST /v1/orders` into an `OrderRequest`, or
/// throws `VALIDATION_FAILED` listing every problem found (api.md 4.3 step 2).
///
/// Works on `JSONValue`, not on a `Decodable` type, because unknown keys must
/// be rejected (api.md section 1) and every field needs its own code. Rules
/// that need shop settings (`max_qty_per_cake`, number of active products)
/// are checked later by the service.
struct OrderRequestParser {
    typealias Name = OrderFieldError.Name

    /// ADR-0009: an input-safety bound; the shop's `max_qty_per_cake` is lower or equal.
    static let hardMaxQuantity = 99
    private static let topLevelKeys: Set<String> = [
        Name.items, Name.deliveryDate, Name.slotID, Name.customer, Name.note, Name.expectedTotal
    ]
    private static let itemKeys: Set<String> = ["product_id", "quantity"]

    private var errors: [OrderFieldError.Entry] = []

    static func parse(_ json: JSONValue) throws -> OrderRequest {
        var parser = OrderRequestParser()
        let request = parser.readRequest(json)
        guard parser.errors.isEmpty, let request else {
            throw APIError(.validationFailed, fields: parser.errors.isEmpty ? nil : parser.errors)
        }
        return request
    }

    private mutating func readRequest(_ json: JSONValue) -> OrderRequest? {
        guard case .object(let root) = json else { return nil }
        rejectUnknown(root, allowed: Self.topLevelKeys, prefix: "")
        let items = readItems(root[Name.items])
        let date = readDeliveryDate(root[Name.deliveryDate])
        let slotID = readUUID(root[Name.slotID], field: Name.slotID, code: "SLOT_INVALID")
        let customer = readCustomer(root[Name.customer])
        let note = readNote(root[Name.note])
        let total = readExpectedTotal(root[Name.expectedTotal])
        guard errors.isEmpty, let items, let date, let slotID, let customer, let total else { return nil }
        return OrderRequest(
            items: items, deliveryDate: date, slotID: slotID,
            customerName: customer.name, customerPhone: customer.phone, customerAddress: customer.address,
            districtID: customer.districtID, note: note, expectedTotalVND: total
        )
    }

    mutating func fail(_ entry: OrderFieldError.Entry) { errors.append(entry) }

    mutating func rejectUnknown(_ object: [String: JSONValue], allowed: Set<String>, prefix: String) {
        for key in object.keys.sorted() where !allowed.contains(key) {
            fail(OrderFieldError.unknown(prefix + key))
        }
    }

    mutating func readUUID(_ value: JSONValue?, field: String, code: String) -> UUID? {
        guard case .string(let text)? = value, let id = UUID(uuidString: text) else {
            fail(OrderFieldError.invalid(field, code: code))
            return nil
        }
        return id
    }

    private mutating func readItems(_ value: JSONValue?) -> [OrderRequest.Line]? {
        guard case .array(let elements)? = value, !elements.isEmpty else {
            fail(OrderFieldError.invalid(Name.items, code: "ITEMS_INVALID"))
            return nil
        }
        var lines: [OrderRequest.Line] = []
        var seen: Set<UUID> = []
        for (index, element) in elements.enumerated() {
            let prefix = "\(Name.items)[\(index)]."
            guard case .object(let object) = element else {
                fail(OrderFieldError.invalid("\(Name.items)[\(index)]", code: "ITEMS_INVALID"))
                continue
            }
            rejectUnknown(object, allowed: Self.itemKeys, prefix: prefix)
            let id = readUUID(object["product_id"], field: prefix + "product_id", code: "PRODUCT_INVALID")
            var quantity: Int?
            if case .int(let number)? = object["quantity"], (1...Self.hardMaxQuantity).contains(number) {
                quantity = number
            } else {
                fail(OrderFieldError.invalid(prefix + "quantity", code: "QUANTITY_INVALID"))
            }
            guard let id, let quantity else { continue }
            if !seen.insert(id).inserted {
                fail(OrderFieldError.invalid(prefix + "product_id", code: "PRODUCT_DUPLICATE"))
            }
            lines.append(.init(productID: id, quantity: quantity))
        }
        return lines
    }

    private mutating func readDeliveryDate(_ value: JSONValue?) -> BusinessDate? {
        guard case .string(let text)? = value, let date = BusinessDate(isoString: text), date.isRealCalendarDay else {
            fail(OrderFieldError.invalid(Name.deliveryDate, code: "DELIVERY_DATE_INVALID"))
            return nil
        }
        return date
    }

    private mutating func readExpectedTotal(_ value: JSONValue?) -> Int? {
        guard case .int(let total)? = value, total >= 0 else {
            fail(OrderFieldError.invalid(Name.expectedTotal, code: "EXPECTED_TOTAL_INVALID"))
            return nil
        }
        return total
    }
}
