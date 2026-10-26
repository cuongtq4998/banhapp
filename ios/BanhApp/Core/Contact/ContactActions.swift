import Foundation
import Observation

/// Opens Zalo and the dialer for a shop contact and remembers which one failed, for the toast
/// (S-2 and S-9, ADR-0015). No `canOpenURL` pre-check: the system's answer to `open` is the check.
@MainActor
@Observable
final class ContactActions {
    enum Failure: Equatable {
        case zalo, phone

        var message: LocalizedStringResource {
            switch self {
            case .zalo: Strings.errorOpenZalo
            case .phone: Strings.errorOpenPhone
            }
        }
    }

    var failure: Failure?

    private let opener: any URLOpener

    init(opener: any URLOpener) {
        self.opener = opener
    }

    func openZalo(zaloContact: String) async {
        await open(ContactLinks.zaloURL(zaloContact: zaloContact), reportingAs: .zalo)
    }

    func openPhone(phoneContact: String) async {
        await open(ContactLinks.phoneURL(phoneContact: phoneContact), reportingAs: .phone)
    }

    private func open(_ url: URL?, reportingAs failure: Failure) async {
        let opened = if let url { await opener.open(url) } else { false }
        self.failure = opened ? nil : failure
    }
}
