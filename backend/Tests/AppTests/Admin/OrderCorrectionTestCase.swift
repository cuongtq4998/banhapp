import XCTVapor
@testable import App

/// Shared requests and counters of the two correction endpoint tests.
class OrderCorrectionTestCase: AdminOrderTestCase {
    static func put(_ app: Application, _ phone: Phone?, _ orderCode: String, _ path: String, _ json: String) async throws -> Reply {
        let box = LockedBox<Reply?>(nil)
        var headers: HTTPHeaders = ["X-Platform": "ios", "X-App-Version": "1.0.0", "Content-Type": "application/json"]
        if let phone { headers.add(name: .authorization, value: "Bearer \(phone.access)") }
        try await app.test(.PUT, "v1/admin/orders/\(orderCode)/\(path)", headers: headers, body: ByteBuffer(string: json), afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }

    func dateBody(previous: String, new: String) -> String {
        "{\"expected_status\":\"DeliveryDateScheduled\",\"previous_expected_delivery_date\":\"\(previous)\",\"expected_delivery_date\":\"\(new)\"}"
    }

    func feeBody(previous: String, new: String, status: String = "DeliveryStarted") -> String {
        "{\"expected_status\":\"\(status)\",\"previous_delivery_fee_vnd\":\(previous),\"delivery_fee_vnd\":\(new)}"
    }

    func records(_ table: String, _ orderCode: String) async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM \(unsafeRaw: table) r JOIN customer_order o ON o.id = r.order_id WHERE o.order_code = \(bind: orderCode)")
    }

    func fieldCode(_ reply: Reply) -> String? {
        ((reply.json["error"] as? [String: Any])?["fields"] as? [[String: Any]])?.first?["code"] as? String
    }
}
