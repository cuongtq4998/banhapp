import BanhCore
import Foundation

/// The person's session ended (revoked, expired or unknown): local data is already cleared and the
/// sign-in screen is being shown. Callers just stop.
nonisolated struct SessionEnded: Error, Equatable {}

/// Holds the access token (memory only) and the refresh token (store), renews on 401 and clears
/// everything when the session is gone (ADR-0022, api/05 10.3).
actor SessionManager {
    enum SignOutResult: Equatable { case done, offline }

    private let client: APIClient
    private let store: any TokenStore
    private var accessToken: String?
    private var refreshTask: Task<String, Error>?
    private var onEnded: (@Sendable () -> Void)?

    init(client: APIClient, store: any TokenStore) {
        self.client = client
        self.store = store
    }

    func setOnEnded(_ handler: @escaping @Sendable () -> Void) { onEnded = handler }

    var hasSession: Bool { store.refreshToken != nil }

    // MARK: Sign in

    func signIn(email: String, code: String, installationID: String, deviceName: String) async throws -> SessionResponse {
        let body = ["email": email, "code": code, "installation_id": installationID, "device_name": deviceName]
        let response = try await client.decode(
            SessionResponse.self, "POST", path: "/v1/auth/sessions", body: try JSONEncoder().encode(body)
        )
        store.saveRefreshToken(response.refreshToken)
        accessToken = response.accessToken
        return response
    }

    // MARK: Authorised calls

    /// Runs `call` with a bearer token. A 401 triggers one refresh and one retry; a 401 that cannot be
    /// repaired ends the session (clears the tokens, tells the coordinator) and throws `SessionEnded`.
    func authorized<T>(_ call: @Sendable (String) async throws -> T) async throws -> T {
        let token = try await currentAccessToken()
        do {
            return try await call(token)
        } catch let error as APIError where error.httpStatus == 401 {
            if Self.endsSession(error) { throw endSession() }
            let renewed = try await refresh()
            do {
                return try await call(renewed)
            } catch let retryError as APIError where retryError.httpStatus == 401 {
                throw endSession()
            }
        }
    }

    private func currentAccessToken() async throws -> String {
        if let accessToken { return accessToken }
        return try await refresh()
    }

    private static func endsSession(_ error: APIError) -> Bool {
        ["SESSION_REVOKED", "SESSION_EXPIRED"].contains(error.code)
    }

    // MARK: Refresh

    /// One refresh at a time: callers that arrive meanwhile wait for the same answer. A lost response
    /// (network error) keeps the old refresh token, which the server accepts again for 20 s.
    private func refresh() async throws -> String {
        if let refreshTask { return try await refreshTask.value }
        guard let token = store.refreshToken else { throw endSession() }
        let task = Task { try await self.performRefresh(token) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh(_ token: String) async throws -> String {
        do {
            let response = try await Self.refreshCall(client, token)
            store.saveRefreshToken(response.refreshToken)
            accessToken = response.accessToken
            return response.accessToken
        } catch let error as APIError where error.httpStatus == 401 {
            throw endSession()
        }
    }

    private static func refreshCall(_ client: APIClient, _ token: String) async throws -> RefreshResponse {
        try await client.decode(
            RefreshResponse.self, "POST", path: "/v1/auth/refresh", body: try JSONEncoder().encode(["refresh_token": token])
        )
    }

    // MARK: End and sign out

    /// Clears every token and tells the coordinator (any 401 that cannot be repaired).
    @discardableResult
    func endSession() -> SessionEnded {
        accessToken = nil
        store.clearAll()
        onEnded?()
        return SessionEnded()
    }

    /// Sign out, step one: forget the session on this phone at once. The refresh token waits as a
    /// pending sign-out until the server confirms (TQ-D6); nothing personal stays.
    func clearLocalSession() {
        accessToken = nil
        if let token = store.refreshToken { store.savePendingSignOut(token) }
        store.clearRefreshToken()
    }

    /// Sign out, step two (also run at launch): tell the server. Repeats until 204 or 401.
    func completePendingSignOut() async -> SignOutResult {
        guard let token = store.pendingSignOutToken else { return .done }
        do {
            let pair = try await Self.refreshCall(client, token)
            do {
                _ = try await client.send("DELETE", path: "/v1/admin/session", headers: ["Authorization": "Bearer \(pair.accessToken)"])
                store.clearPendingSignOut()
            } catch let error as APIError where error.isConnectivity {
                store.savePendingSignOut(pair.refreshToken)
                return .offline
            } catch {
                store.clearPendingSignOut()
            }
            return .done
        } catch let error as APIError where error.isConnectivity {
            return .offline
        } catch {
            store.clearPendingSignOut()
            return .done
        }
    }
}
