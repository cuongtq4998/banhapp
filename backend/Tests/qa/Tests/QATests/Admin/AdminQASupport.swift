import XCTest
import Vapor
import NIOConcurrencyHelpers
@testable import AppUnderTest

/// A clock the tests can move.
final class QAClock: WallClock, @unchecked Sendable {
    private let lock = NIOLock()
    private var instant: Date
    init(_ instant: Date) { self.instant = instant }
    func now() -> Date { lock.withLock { instant } }
    func advance(_ seconds: TimeInterval) { lock.withLock { instant = instant.addingTimeInterval(seconds) } }
}

struct QAPhone: Sendable {
    var access: String
    var refresh: String
    let deviceID: String
}

/// A customer order through the public route `POST /v1/orders` (fake customer).
struct QAShop: Sendable {
    let client: QAClient
    let productID: UUID, slotID: UUID, districtID: UUID

    func order(date: String, cakes: Int = 2, phone: String = "0900000010", key: UUID = UUID(), note: String? = "QA note",
               name: String = "Tran Thi B", address: String = "1 QA Street") async throws -> QAReply {
        let body: [String: Any] = [
            "items": [["product_id": productID.uuidString, "quantity": cakes]], "delivery_date": date, "slot_id": slotID.uuidString,
            "customer": ["name": name, "phone": phone, "address": address, "district_id": districtID.uuidString],
            "note": note as Any, "expected_total_vnd": cakes * 50_000 + 20_000]
        return try await client.send("POST", "v1/orders", json: body, headers: ["Idempotency-Key": key.uuidString.lowercased()], platform: "android")
    }
}
