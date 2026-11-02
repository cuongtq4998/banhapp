import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

/// The shared fixtures of contracts/fixtures/admin decode into the app's models.
struct ContractFixtureTests {
    private func body(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "contracts/fixtures/admin/\(name).json")
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try JSONSerialization.data(withJSONObject: root["body"] ?? root)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try APIClient.decoder.decode(type, from: body(name))
    }

    @Test func sessionRefreshMeAndCodeRequest() throws {
        let session = try decode(SessionResponse.self, "session-created")
        #expect(session.account.role == .staff)
        #expect(try decode(RefreshResponse.self, "refresh-ok").accessExpiresIn == 300)
        #expect(try decode(MeResponse.self, "me").serverDate == "2026-11-02")
        #expect(try decode(CodeRequestResponse.self, "code-request").resendAfterSeconds == 30)
    }

    @Test func ordersListAndDetail() throws {
        let page = try decode(OrderPage.self, "orders-list")
        #expect(page.items.first?.orderCode == "BT-7K3M9Q")
        #expect(page.unfinishedCount == 1)
        let detail = try decode(OrderDetail.self, "order-detail")
        #expect(detail.lastChange.actorName == nil)
        #expect(detail.allowedActions == ["confirm", "cancel"])
        #expect(try decode(OrderDetail.self, "order-status-change").cancelReason == "customer_asked")
    }

    @Test func conflictErrorCarriesTheCurrentOrder() throws {
        let error = APIErrorParser.parse(
            try body("error-order-state-changed"),
            response: HTTPURLResponse(url: URL(string: "http://x")!, statusCode: 409, httpVersion: nil, headerFields: nil)!
        )
        #expect(error.code == "ORDER_STATE_CHANGED")
        guard case .service(_, _, _, let details) = error, let order = details["order"] else { Issue.record("no order"); return }
        let current = try APIClient.decoder.decode(OrderDetail.self, from: JSONEncoder().encode(order))
        #expect(current.status == .confirmed)
    }

    @Test func httpOrdersApiTurnsA409IntoAConflictOutcome() async throws {
        let conflict = String(decoding: try Data(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "contracts/fixtures/admin/error-order-state-changed.json")), as: UTF8.self)
        let transport = ScriptedTransport { request, _ in
            request.url?.path == "/v1/auth/refresh" ? (200, ScriptedTransport.pair) : (409, conflict)
        }
        let client = APIClient(baseURL: URL(string: "http://stub.invalid")!, appVersion: "1.0.0", transport: transport)
        let api = HTTPOrdersAPI(client: client, session: SessionManager(client: client, store: InMemoryTokenStore(refreshToken: "rt")))
        let outcome = try await api.changeStatus(code: "BT-7K3M9Q", expected: .new, to: .confirmed, reason: nil)
        guard case .conflict(let current) = outcome else { Issue.record("expected conflict"); return }
        #expect(current.status == .confirmed)
        let sent = transport.requests.last?.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        #expect(sent.contains("expected_status"))
    }

    @Test func sessionErrorFixturesUseTheCodesTheClientBranchesOn() throws {
        for (name, code) in [("error-session-expired", "SESSION_EXPIRED"), ("error-session-revoked", "SESSION_REVOKED"),
                             ("error-access-token-expired", "ACCESS_TOKEN_EXPIRED"), ("error-code-invalid", "CODE_INVALID"),
                             ("error-code-expired", "CODE_EXPIRED")] {
            let envelope = try JSONDecoder().decode(APIErrorResponseProbe.self, from: body(name))
            #expect(envelope.error.code == code, "\(name)")
        }
    }
}

private struct APIErrorResponseProbe: Decodable {
    struct Body: Decodable { let code: String }
    let error: Body
}
