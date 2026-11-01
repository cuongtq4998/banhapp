#if DEBUG
import BanhCore
import Foundation

/// An in-process backend behind `HTTPTransport`, so the whole client stack (tokens, refresh, error
/// envelope) runs in UI tests without a server. Bodies follow `contracts/fixtures/admin/`.
final class StubAdminTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let mode: String
    private var orders = StubOrderData.orders
    private var refreshCount = 0
    private var currentRefresh = "rt_stub_0"
    private var currentAccess = ""
    private var pendingExpiry: Bool
    private(set) var staffRole = true

    init(mode: String) {
        self.mode = mode
        pendingExpiry = mode == AdminLaunch.modeRefresh
        staffRole = mode != AdminLaunch.modeOwner && mode != AdminLaunch.modeSignInOwner
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try respond(request)
    }

    private func respond(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        try lock.withLock {
            let (status, body) = try route(request, path: request.url?.path ?? "")
            return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    private func route(_ request: URLRequest, path: String) throws -> (Int, Data) {
        let method = request.httpMethod ?? "GET"
        let json = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        switch (method, path) {
        case ("POST", "/v1/auth/code-requests"): return codeRequest(json)
        case ("POST", "/v1/auth/sessions"): return signIn(json)
        case ("POST", "/v1/auth/refresh"): return refresh(json)
        default: break
        }
        if mode == AdminLaunch.modeRevoked { return StubReply.error(401, "SESSION_REVOKED", "ERR_ADMIN_SESSION_ENDED") }
        if request.value(forHTTPHeaderField: "Authorization") != "Bearer \(currentAccess)" || pendingExpiry {
            pendingExpiry = false
            return StubReply.error(401, "ACCESS_TOKEN_EXPIRED", "ERR_ADMIN_SIGN_IN_REQUIRED")
        }
        if mode == AdminLaunch.modeOffline, path.hasPrefix("/v1/admin/orders") { throw APIError.networkUnavailable }
        if mode == AdminLaunch.modeServerError, path.hasPrefix("/v1/admin/orders") {
            return StubReply.error(500, "INTERNAL_ERROR", "ERR_SERVER")
        }
        return admin(method, path, json: json, query: request.url?.query ?? "")
    }

    // MARK: Auth

    private func codeRequest(_ json: [String: Any]) -> (Int, Data) {
        if (json["email"] as? String) == "limit@example.com" {
            return StubReply.error(429, "CODE_REQUEST_LIMIT", "ERR_CODE_REQUEST_LIMIT", details: ["retry_after_seconds": 1800])
        }
        return StubReply.ok(202, ["resend_after_seconds": 30, "expires_in_seconds": 600])
    }

    private func signIn(_ json: [String: Any]) -> (Int, Data) {
        let code = json["code"] as? String
        if code == "000000" { return StubReply.error(422, "CODE_EXPIRED", "ERR_CODE_EXPIRED") }
        guard code == AdminLaunch.fakeCode else { return StubReply.error(422, "CODE_INVALID", "ERR_CODE_INVALID") }
        let owner = (json["email"] as? String)?.hasPrefix("owner") == true
        staffRole = !owner
        issueTokens()
        return StubReply.ok(201, [
            "access_token": currentAccess, "refresh_token": currentRefresh, "access_expires_in": 300,
            "device_id": "5b0c2f6a-0000-4a00-8000-000000000001",
            "account": ["name": owner ? "Chu Tiem" : "Nhan Vien A", "role": owner ? "owner" : "staff"],
            "server_date": StubOrderData.serverDate,
        ])
    }

    private func refresh(_ json: [String: Any]) -> (Int, Data) {
        guard mode != AdminLaunch.modeRevoked, (json["refresh_token"] as? String) == currentRefresh else {
            return StubReply.error(401, "SESSION_REVOKED", "ERR_ADMIN_SESSION_ENDED")
        }
        issueTokens()
        return StubReply.ok(200, ["access_token": currentAccess, "refresh_token": currentRefresh, "access_expires_in": 300])
    }

    private func issueTokens() {
        refreshCount += 1
        currentAccess = "at_stub_\(refreshCount)"
        currentRefresh = "rt_stub_\(refreshCount)"
    }

    /// The refresh token a pre-signed-in launch starts with.
    var initialRefreshToken: String { "rt_stub_0" }

    // MARK: Admin

    private func admin(_ method: String, _ path: String, json: [String: Any], query: String) -> (Int, Data) {
        switch (method, path) {
        case ("GET", "/v1/admin/me"):
            return StubReply.ok(200, [
                "account": ["name": staffRole ? "Nhan Vien A" : "Chu Tiem", "role": staffRole ? "staff" : "owner"],
                "device_id": "5b0c2f6a-0000-4a00-8000-000000000001", "server_date": StubOrderData.serverDate,
            ])
        case ("DELETE", "/v1/admin/session"), ("DELETE", "/v1/admin/sessions/others"):
            return (204, Data())
        case ("GET", "/v1/admin/orders"): return list(query: query)
        default: break
        }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count >= 4, parts[2] == "orders", mode != AdminLaunch.modeGone,
              let index = orders.firstIndex(where: { $0.orderCode == parts[3] })
        else { return StubReply.error(404, "ORDER_NOT_FOUND", "ERR_ORDER_NOT_FOUND") }
        if method == "GET", parts.count == 4 { return StubReply.codable(200, orders[index]) }
        if method == "POST", parts.count == 5, parts[4] == "status" { return changeStatus(index, json) }
        return StubReply.error(404, "NOT_FOUND", "ERR_NOT_FOUND")
    }

    private func list(query: String) -> (Int, Data) {
        let items = URLComponents(string: "x://x?\(query)")?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        let status = value("status") ?? "todo"
        let server = ShopDay(StubOrderData.serverDate)!
        let day: String? = switch value("date_preset") {
        case "today": server.wire
        case "tomorrow": server.adding(days: 1).wire
        default: value("delivery_date")
        }
        let rows = mode == AdminLaunch.modeEmpty ? [] : orders
            .filter { status == "all" || (status == "todo" ? $0.status.isOpen : $0.status.rawValue == status) }
            .filter { day == nil || $0.deliveryDate == day }
            .filter { order in value("q").map { StubOrderData.matches(order, query: $0) } ?? true }
            .sorted { ($0.deliveryDate, $0.slot.start, $0.createdAt) < ($1.deliveryDate, $1.slot.start, $1.createdAt) }
        let unfinished = orders.filter { $0.status.isOpen && $0.deliveryDate <= StubOrderData.serverDate }.count
        return StubReply.codable(200, OrderPage(
            items: rows.map(StubOrderData.summary), nextCursor: nil,
            unfinishedCount: mode == AdminLaunch.modeEmpty ? 0 : unfinished, serverDate: StubOrderData.serverDate
        ))
    }

    private func changeStatus(_ index: Int, _ json: [String: Any]) -> (Int, Data) {
        guard let expected = (json["expected_status"] as? String).flatMap(OrderStatus.init(rawValue:)),
              let target = (json["to_status"] as? String).flatMap(OrderStatus.init(rawValue:))
        else { return StubReply.error(422, "VALIDATION_FAILED", "ERR_VALIDATION") }
        if mode == AdminLaunch.modeConflict, orders[index].status == .new { orders[index] = StubOrderData.changed(orders[index], to: .confirmed, reason: nil) }
        guard orders[index].status == expected else {
            return StubReply.error(409, "ORDER_STATE_CHANGED", "ERR_ORDER_STATE_CHANGED", details: ["order": StubReply.object(orders[index])])
        }
        let reason = (json["cancel_reason"] as? String).flatMap(CancelReason.init(rawValue:))
        let allowed: [OrderStatus: [OrderStatus]] = [.new: [.confirmed, .cancelled], .confirmed: [.completed, .cancelled]]
        guard allowed[expected]?.contains(target) == true else {
            return StubReply.error(422, "STATUS_TRANSITION_INVALID", "ERR_STATUS_TRANSITION_INVALID")
        }
        if target == .cancelled, reason == nil { return StubReply.error(422, "CANCEL_REASON_REQUIRED", "ERR_CANCEL_REASON_REQUIRED") }
        orders[index] = StubOrderData.changed(orders[index], to: target, reason: reason)
        return StubReply.codable(200, orders[index])
    }
}
#endif
