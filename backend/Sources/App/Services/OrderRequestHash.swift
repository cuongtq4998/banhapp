import Foundation
import Crypto

/// SHA-256 of the normalised request (ADR-0008, `customer_order.request_hash`).
///
/// Built from the validated `OrderRequest`, not from the raw bytes, so the
/// same order written with other spacing, key order, phone format or line
/// order hashes the same, and the same key with a different order does not.
enum OrderRequestHash {
    private struct Canonical: Encodable {
        struct Line: Encodable {
            let product_id: String
            let quantity: Int
        }
        let items: [Line]
        let delivery_date: String
        let slot_id: String
        let name: String
        let phone: String
        let address: String
        let district_id: String
        let note: String?
        let expected_total_vnd: Int
    }

    static func make(_ request: OrderRequest) -> String {
        let lines = request.items
            .map { Canonical.Line(product_id: $0.productID.uuidString.lowercased(), quantity: $0.quantity) }
            .sorted { $0.product_id < $1.product_id }
        let canonical = Canonical(
            items: lines,
            delivery_date: request.deliveryDate.description,
            slot_id: request.slotID.uuidString.lowercased(),
            name: request.customerName,
            phone: request.customerPhone,
            address: request.customerAddress,
            district_id: request.districtID.uuidString.lowercased(),
            note: request.note,
            expected_total_vnd: request.expectedTotalVND
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encoding plain strings and integers cannot fail; an empty input would
        // hash to a different value and be caught by the replay tests.
        let data = (try? encoder.encode(canonical)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
