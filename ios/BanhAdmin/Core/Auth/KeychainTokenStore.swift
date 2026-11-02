import Foundation
import Security

/// Refresh token in the Keychain, readable after the first unlock and never copied to another device
/// or a backup (ADR-0022, architecture/08).
nonisolated final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let service: String
    private static let refreshAccount = "refresh"
    private static let pendingAccount = "pending-sign-out"

    init(service: String = "app.banh.admin.session") { self.service = service }

    var refreshToken: String? { read(Self.refreshAccount) }
    var pendingSignOutToken: String? { read(Self.pendingAccount) }
    func saveRefreshToken(_ token: String) { write(token, Self.refreshAccount) }
    func savePendingSignOut(_ token: String) { write(token, Self.pendingAccount) }
    func clearRefreshToken() { delete(Self.refreshAccount) }
    func clearPendingSignOut() { delete(Self.pendingAccount) }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    private func read(_ account: String) -> String? {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ token: String, _ account: String) {
        delete(account)
        var item = query(account)
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func delete(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}
