import BanhContracts
import BanhCore
import Foundation

nonisolated struct HTTPOrdersAPI: OrdersAPI {
    let client: APIClient
    let session: SessionManager

    func orders(_ query: OrderQuery) async throws -> OrderPage {
        try await session.authorized { token in
            try await client.decode(OrderPage.self, "GET", path: "/v1/admin/orders", query: query.items, headers: bearer(token))
        }
    }

    func order(code: String) async throws -> OrderDetail {
        try await session.authorized { token in
            try await client.decode(OrderDetail.self, "GET", path: "/v1/admin/orders/\(code)", headers: bearer(token))
        }
    }

    func changeStatus(code: String, _ request: StatusRequest) async throws -> StatusChangeOutcome {
        var body: [String: JSONValue] = ["expected_status": .string(request.expected.wireValue), "to_status": .string(request.target.wireValue)]
        if let reason = request.reason { body["cancel_reason"] = .string(reason.rawValue) }
        if let date = request.expectedDeliveryDate { body["expected_delivery_date"] = .string(date) }
        if let fee = request.deliveryFeeVnd { body["delivery_fee_vnd"] = .int(fee) }
        return try await send("POST", "/v1/admin/orders/\(code)/status", body)
    }

    func changeExpectedDate(code: String, previous: String, to date: String) async throws -> StatusChangeOutcome {
        try await send("PUT", "/v1/admin/orders/\(code)/expected-delivery-date", [
            "expected_status": .string(OrderStatus.deliveryDateScheduled.wireValue),
            "previous_expected_delivery_date": .string(previous), "expected_delivery_date": .string(date),
        ])
    }

    func correctFee(code: String, previous: Int, to fee: Int) async throws -> StatusChangeOutcome {
        try await send("PUT", "/v1/admin/orders/\(code)/delivery-fee", [
            "expected_status": .string(OrderStatus.deliveryStarted.wireValue),
            "previous_delivery_fee_vnd": .int(previous), "delivery_fee_vnd": .int(fee),
        ])
    }

    /// A 409 carries the current order, so the screen refreshes without a second read.
    private func send(_ method: String, _ path: String, _ body: [String: JSONValue]) async throws -> StatusChangeOutcome {
        let data = try JSONEncoder().encode(body)
        do {
            return .changed(try await session.authorized { token in
                try await client.decode(OrderDetail.self, method, path: path, body: data, headers: bearer(token))
            })
        } catch let error as APIError {
            guard error.code == "ORDER_STATE_CHANGED", case .service(_, _, _, let details) = error,
                  let current = details["order"],
                  let detail = try? APIClient.decoder.decode(OrderDetail.self, from: JSONEncoder().encode(current))
            else { throw error }
            return .conflict(detail)
        }
    }

    private func bearer(_ token: String) -> [String: String] { ["Authorization": "Bearer \(token)"] }
}
