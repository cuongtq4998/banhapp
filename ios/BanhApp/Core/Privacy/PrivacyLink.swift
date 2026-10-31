import Foundation
import Observation

/// Opens the shop's privacy page (`GET /privacy` on the API base URL, api.md 4.5) for S-7 and S-8
/// (FR-20, AC-30). One handler serves both screens: `presented` drives the in-app browser sheet and
/// `failed` drives the `ERR_OPEN_PRIVACY` toast.
@MainActor
@Observable
final class PrivacyLink {
    private(set) var presented: URL?
    var failed = false

    let url: URL?
    /// Debug builds in UI tests show a plain view instead of loading a page.
    let usesStubBrowser: Bool

    init(apiBaseURL: URL, usesStubBrowser: Bool = false) {
        self.url = Self.privacyURL(apiBaseURL: apiBaseURL)
        self.usesStubBrowser = usesStubBrowser
    }

    /// `<API base URL>/privacy`; nil when the base is not an http(s) address (the browser cannot show it).
    nonisolated static func privacyURL(apiBaseURL: URL) -> URL? {
        guard let scheme = apiBaseURL.scheme?.lowercased(), scheme == "http" || scheme == "https",
              apiBaseURL.host() != nil else { return nil }
        return apiBaseURL.appending(path: "privacy")
    }

    func open() {
        if let url {
            failed = false
            presented = url
        } else {
            failed = true
        }
    }

    func dismiss() { presented = nil }
}
