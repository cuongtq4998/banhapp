import Foundation

/// Link forms of ADR-0015: a web link for Zalo (no custom scheme, so no `canOpenURL` list entry) and
/// `tel:` for the dialer. Nil when the shop value cannot form a link.
nonisolated enum ContactLinks {
    private static let zaloScheme = "https"
    private static let zaloHost = "zalo.me"
    private static let phoneScheme = "tel"

    static func zaloURL(zaloContact: String) -> URL? {
        guard !zaloContact.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = zaloScheme
        components.host = zaloHost
        components.path = "/" + zaloContact
        return components.url
    }

    static func phoneURL(phoneContact: String) -> URL? {
        guard !phoneContact.isEmpty else { return nil }
        return URL(string: "\(phoneScheme):\(phoneContact)")
    }
}
