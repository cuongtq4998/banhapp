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

    @Test func serverTroubleKeepsThePendingSignOut() async throws {
        for failure in [ScriptedTransport.error(429, "RATE_LIMITED"), ScriptedTransport.error(503, "SERVICE_UNAVAILABLE"), (200, "not json")] {
            // Refresh fails.
            let store = InMemoryTokenStore(refreshToken: "rt_old")
            let (session, _) = manager(store: store) { _, _ in failure }
            await session.clearLocalSession()
            #expect(await session.completePendingSignOut() == .offline)
            #expect(store.pendingSignOutToken == "rt_old")
            // Refresh works, DELETE fails: the rotated token is kept (a 200 with a odd body is still success).
            guard failure.0 != 200 else { continue }
            let second = InMemoryTokenStore(refreshToken: "rt_old")
            let (other, _) = manager(store: second) { request, _ in request.httpMethod == "DELETE" ? failure : (200, ScriptedTransport.pair) }
            await other.clearLocalSession()
            #expect(await other.completePendingSignOut() == .offline)
            #expect(second.pendingSignOutToken == "rt_new")
        }
    }

    @Test func a401ClearsThePendingSignOut() async throws {
        for code in ["SESSION_EXPIRED", "SESSION_REVOKED"] {
            let store = InMemoryTokenStore(refreshToken: "rt_old")
            let (session, _) = manager(store: store) { _, _ in ScriptedTransport.error(401, code) }
            await session.clearLocalSession()
            #expect(await session.completePendingSignOut() == .done)
            #expect(store.pendingSignOutToken == nil)
            let late = InMemoryTokenStore(refreshToken: "rt_old")
            let (deleting, _) = manager(store: late) { request, _ in request.httpMethod == "DELETE" ? ScriptedTransport.error(401, code) : (200, ScriptedTransport.pair) }
            await deleting.clearLocalSession()
            #expect(await deleting.completePendingSignOut() == .done)
            #expect(late.pendingSignOutToken == nil)
        }
    }

    @Test func freshInstallClearsLeftoverKeychainItems() {
        let defaults = UserDefaults(suiteName: "installation-\(UUID().uuidString)")!
        let store = InMemoryTokenStore(refreshToken: "left_over")
        store.savePendingSignOut("left_over")
        let first = InstallationID.current(defaults: defaults, onFirstStart: store.clearAll)
        #expect(store.refreshToken == nil && store.pendingSignOutToken == nil)
        store.saveRefreshToken("rt")
        #expect(InstallationID.current(defaults: defaults, onFirstStart: store.clearAll) == first)
        #expect(store.refreshToken == "rt")
    }
}

final class EndedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.withLock { flag } }
    func set() { lock.withLock { flag = true } }
}
