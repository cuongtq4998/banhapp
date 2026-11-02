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
    private let owner: StubOwnerBackend
    /// Push tokens the app registered (`PUT /v1/admin/push-token`), for tests.
    private(set) var pushTokens: [String] = []

    init(mode: String) {
        self.mode = mode
        pendingExpiry = mode == AdminLaunch.modeRefresh
        staffRole = !AdminLaunch.ownerModes.contains(mode)
        owner = StubOwnerBackend(full: mode == AdminLaunch.modeOwnerFull)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if mode == AdminLaunch.modeOwnerSlow, request.httpMethod == "POST", request.url?.path == "/v1/owner/cakes" {
            try await Task.sleep(for: .seconds(30))
        }
        return try respond(request)
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
        if mode == AdminLaunch.modeOwnerOffline, path.hasPrefix("/v1/owner") { throw APIError.networkUnavailable }
        if mode == AdminLaunch.modeServerError, path.hasPrefix("/v1/admin/orders") {
            return StubReply.error(500, "INTERNAL_ERROR", "ERR_SERVER")
        }
        return admin(method, path, json: json, query: request.url?.query ?? "", request: request)
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

    private func admin(_ method: String, _ path: String, json: [String: Any], query: String, request: URLRequest) -> (Int, Data) {
        switch (method, path) {
        case ("GET", "/v1/admin/me"):
            return StubReply.ok(200, [
                "account": ["name": staffRole ? "Nhan Vien A" : "Chu Tiem", "role": staffRole ? "staff" : "owner"],
                "email": staffRole ? AdminLaunch.fakeEmail : StubOwnerData.ownerEmail,
                "device_id": "5b0c2f6a-0000-4a00-8000-000000000001", "server_date": StubOrderData.serverDate,
            ])
        case ("DELETE", "/v1/admin/session"), ("DELETE", "/v1/admin/sessions/others"):
            return (204, Data())
        case ("PUT", "/v1/admin/push-token"):
            guard let token = json["token"] as? String, json["platform"] as? String == "ios",
                  ["sandbox", "production"].contains(json["apns_environment"] as? String)
            else { return StubReply.error(422, "VALIDATION_FAILED", "ERR_SERVER") }
            pushTokens.append(token)
            return (204, Data())
        case ("GET", "/v1/admin/orders"): return list(query: query)
        default: break
        }
        let parts = path.split(separator: "/").map(String.init)
        if parts.count >= 3, parts[1] == "owner" { return ownerRoute(method, parts, json: json, query: query, request: request) }
        guard parts.count >= 4, parts[2] == "orders", mode != AdminLaunch.modeGone,
              let index = orders.firstIndex(where: { $0.orderCode == parts[3] })
        else { return StubReply.error(404, "ORDER_NOT_FOUND", "ERR_ORDER_NOT_FOUND") }
        if method == "GET", parts.count == 4 { return StubReply.codable(200, orders[index]) }
        if method == "POST", parts.count == 5, parts[4] == "status" { return changeStatus(index, json) }
        if method == "PUT", parts.count == 5, parts[4] == "expected-delivery-date" { return apply(index, StubOrderProcess.changeDate(orders[index], json)) }
        if method == "PUT", parts.count == 5, parts[4] == "delivery-fee" { return apply(index, StubOrderProcess.correctFee(orders[index], json)) }
        return StubReply.error(404, "NOT_FOUND", "ERR_NOT_FOUND")
    }

    private func ownerRoute(_ method: String, _ parts: [String], json: [String: Any], query: String, request: URLRequest) -> (Int, Data) {
        if staffRole { return StubReply.error(403, "FORBIDDEN", "ERR_FORBIDDEN") }
        if mode == AdminLaunch.modeOwnerError { return StubReply.error(500, "INTERNAL_ERROR", "ERR_SERVER") }
        return owner.handle(method, parts, json: json, query: query, request: request)
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
            .filter { status == "all" || (status == "todo" ? $0.status.isOpen : $0.status.wireValue == status) }
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
        guard let expected = (json["expected_status"] as? String).flatMap(OrderStatus.init(word:)),
              let target = (json["to_status"] as? String).flatMap(OrderStatus.init(word:))
        else { return StubReply.error(422, "VALIDATION_FAILED", "ERR_VALIDATION") }
        if mode == AdminLaunch.modeConflict, orders[index].status == .received { orders[index] = StubOrderData.changed(orders[index], to: .processing, reason: nil) }
        guard orders[index].status == expected else {
            return StubReply.error(409, "ORDER_STATE_CHANGED", "ERR_ORDER_STATE_CHANGED", details: ["order": StubReply.object(orders[index])])
        }
        return apply(index, StubOrderProcess.changeStatus(orders[index], target: target, json))
    }

    private func apply(_ index: Int, _ outcome: StubOrderProcess.Outcome) -> (Int, Data) {
        if let updated = outcome.order { orders[index] = updated }
        return outcome.reply
    }
}
#endif
