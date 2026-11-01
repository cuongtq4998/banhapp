import UIKit

/// Link forms of ADR-0015: `tel:` for the dialer and a web link for Zalo (no custom scheme).
nonisolated enum ContactLinks {
    static func phoneURL(_ phone: String) -> URL? {
        phone.isEmpty ? nil : URL(string: "tel:\(phone)")
    }

    /// The customer phone is E.164 (`+84...`); Zalo takes the digits only.
    static func zaloURL(_ phone: String) -> URL? {
        let digits = phone.filter(\.isNumber)
        return digits.isEmpty ? nil : URL(string: "https://zalo.me/\(digits)")
    }
}

/// Edge to the system's "open this link". Returns false when it cannot open.
@MainActor
protocol URLOpener {
    func open(_ url: URL) async -> Bool
}

struct SystemURLOpener: URLOpener {
    func open(_ url: URL) async -> Bool { await UIApplication.shared.open(url) }
}

/// Debug stub: pretends every link opens, so a UI test never leaves the app.
struct AcceptingURLOpener: URLOpener {
    func open(_ url: URL) async -> Bool { true }
}
