import Foundation

/// Where the refresh token lives between launches (ADR-0022: Keychain). The access token is never
/// stored. A token waiting for a sign-out the server has not confirmed is kept apart.
nonisolated protocol TokenStore: Sendable {
    var refreshToken: String? { get }
    var pendingSignOutToken: String? { get }
    func saveRefreshToken(_ token: String)
    func savePendingSignOut(_ token: String)
    func clearRefreshToken()
    func clearPendingSignOut()
}

extension TokenStore {
    nonisolated func clearAll() {
        clearRefreshToken()
        clearPendingSignOut()
    }
}

/// For unit tests and the debug stub backend: nothing touches the Keychain.
nonisolated final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var refresh: String?
    private var pending: String?

    init(refreshToken: String? = nil) { refresh = refreshToken }

    var refreshToken: String? { lock.withLock { refresh } }
    var pendingSignOutToken: String? { lock.withLock { pending } }
    func saveRefreshToken(_ token: String) { lock.withLock { refresh = token } }
    func savePendingSignOut(_ token: String) { lock.withLock { pending = token } }
    func clearRefreshToken() { lock.withLock { refresh = nil } }
    func clearPendingSignOut() { lock.withLock { pending = nil } }
}
