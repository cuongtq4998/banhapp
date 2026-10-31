import UIKit

/// Edge to the system's "open this link" (Zalo, browser, dialer). Returns false when it cannot open.
@MainActor
protocol URLOpener {
    func open(_ url: URL) async -> Bool
}

struct SystemURLOpener: URLOpener {
    func open(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}
