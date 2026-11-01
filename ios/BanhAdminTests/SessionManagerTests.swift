import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

struct SessionManagerTests {
    private let base = URL(string: "http://stub.invalid")!

    private func manager(
        store: InMemoryTokenStore, _ handler: @escaping ScriptedTransport.Handler
    ) -> (SessionManager, ScriptedTransport) {
        let transport = ScriptedTransport(handler)
        return (SessionManager(client: APIClient(baseURL: base, appVersion: "1.0.0", transport: transport), store: store), transport)
    }

    private func callMe(_ session: SessionManager, _ client: APIClient) async throws -> Int {
        try await session.authorized { token in
            try await client.send("GET", path: "/v1/admin/me", headers: ["Authorization": "Bearer \(token)"]).response.statusCode
        }
    }

    @Test func expiredAccessTokenRefreshesOnceAndRetries() async throws {
        let store = InMemoryTokenStore(refreshToken: "rt_old")
        let (session, transport) = manager(store: store) { request, _ in
            if request.url?.path == "/v1/auth/refresh" { return (200, ScriptedTransport.pair) }
            let ok = request.value(forHTTPHeaderField: "Authorization") == "Bearer at_new"
            return ok ? (200, "{}") : ScriptedTransport.error(401, "ACCESS_TOKEN_EXPIRED")
        }
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: transport)
        #expect(try await callMe(session, client) == 200)
        #expect(transport.count(path: "/v1/auth/refresh") == 1)
        #expect(store.refreshToken == "rt_new")
        // The access token stays in memory: the second call needs no refresh.
        #expect(try await callMe(session, client) == 200)
        #expect(transport.count(path: "/v1/auth/refresh") == 1)
    }

    @Test func refreshRotationSendsTheStoredTokenAndStoresTheNewOne() async throws {
        let store = InMemoryTokenStore(refreshToken: "rt_old")
        let (session, transport) = manager(store: store) { _, _ in (200, ScriptedTransport.pair) }
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: transport)
        _ = try await callMe(session, client)
        let body = String(decoding: try #require(transport.requests.first?.httpBody), as: UTF8.self)
        #expect(body.contains("rt_old"))
        #expect(store.refreshToken == "rt_new")
    }

    @Test func lostRefreshResponseKeepsTheOldTokenForTheGraceRetry() async throws {
        let store = InMemoryTokenStore(refreshToken: "rt_old")
        let (session, transport) = manager(store: store) { _, index in
            if index == 0 { throw APIError.networkUnavailable }
            return (200, ScriptedTransport.pair)
        }
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: transport)
        await #expect(throws: APIError.networkUnavailable) { try await callMe(session, client) }
        #expect(store.refreshToken == "rt_old")
        #expect(try await callMe(session, client) == 200)
        #expect(store.refreshToken == "rt_new")
    }

    @Test func revokedSessionClearsTokensAndTellsTheCoordinator() async throws {
        let store = InMemoryTokenStore(refreshToken: "rt_old")
        let (session, transport) = manager(store: store) { _, _ in ScriptedTransport.error(401, "SESSION_REVOKED") }
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: transport)
        let ended = EndedFlag()
        await session.setOnEnded { ended.set() }
        await #expect(throws: SessionEnded.self) { try await callMe(session, client) }
        #expect(store.refreshToken == nil)
        #expect(ended.value)
        #expect(await session.hasSession == false)
    }

    @Test func concurrentCallsShareOneRefresh() async throws {
        let store = InMemoryTokenStore(refreshToken: "rt_old")
        let (session, transport) = manager(store: store) { request, _ in
            if request.url?.path == "/v1/auth/refresh" { return (200, ScriptedTransport.pair) }
            return (200, "{}")
        }
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: transport)
        async let a = callMe(session, client)
        async let b = callMe(session, client)
        _ = try await (a, b)
        #expect(transport.count(path: "/v1/auth/refresh") == 1)
    }

    @Test func signOutForgetsTheSessionAtOnceAndConfirmsLater() async throws {
        let store = InMemoryTokenStore(refreshToken: "rt_old")
        let (session, transport) = manager(store: store) { request, _ in
            request.httpMethod == "DELETE" ? (204, "") : (200, ScriptedTransport.pair)
        }
        await session.clearLocalSession()
        #expect(store.refreshToken == nil)
        #expect(store.pendingSignOutToken == "rt_old")
        #expect(await session.completePendingSignOut() == .done)
        #expect(store.pendingSignOutToken == nil)
        #expect(transport.requests.last?.httpMethod == "DELETE")
    }

    @Test func offlineSignOutKeepsOnlyThePendingToken() async throws {
        let store = InMemoryTokenStore(refreshToken: "rt_old")
        let (session, _) = manager(store: store) { _, _ in throw APIError.networkUnavailable }
        await session.clearLocalSession()
        #expect(await session.completePendingSignOut() == .offline)
        #expect(store.refreshToken == nil)
        #expect(store.pendingSignOutToken == "rt_old")
    }
}

final class EndedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.withLock { flag } }
    func set() { lock.withLock { flag = true } }
}
