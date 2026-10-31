import BanhContracts
import Foundation
import Observation

/// S-9: the order code and the shop's contacts (FR-11, FR-12). Nothing else is shown: no status, no
/// recap, no payment (AC-15, AC-25, AC-27).
@MainActor
@Observable
final class ConfirmationViewModel {
    let code: String
    let contact: ContactActions
    private let repository: CatalogRepository

    init(code: String, repository: CatalogRepository, contact: ContactActions) {
        self.code = code
        self.repository = repository
        self.contact = contact
    }

    /// The text VoiceOver reads for the code (`CONF_CODE_A11Y`).
    var spokenLabel: String { OrderStrings.format(SendStrings.confirmationCodeSpoken, code) }

    private var shop: CatalogShop? {
        if case .ready(let catalog) = repository.catalog { catalog.shop } else { nil }
    }

    /// The contact buttons need the shop's numbers; without a catalog they stay off.
    var contactsEnabled: Bool { shop != nil }

    func openZalo() async {
        guard let shop else { return }
        await contact.openZalo(zaloContact: shop.zaloContact)
    }

    func openPhone() async {
        guard let shop else { return }
        await contact.openPhone(phoneContact: shop.phoneContact)
    }
}
