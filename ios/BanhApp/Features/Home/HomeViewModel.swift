import BanhContracts
import Observation

/// S-2: shop name, greeting and contacts.
@MainActor
@Observable
final class HomeViewModel {
    let contact: ContactActions
    private let shop: CatalogScreenModel<CatalogShop>

    init(repository: CatalogRepository, contact: ContactActions) {
        self.contact = contact
        self.shop = CatalogScreenModel(repository: repository) { .ready($0.shop) }
    }

    var state: Load<CatalogShop> { shop.state }

    /// Every action is disabled until the shop information is shown (UI document 5.2, Disabled).
    var actionsEnabled: Bool {
        if case .ready = state { true } else { false }
    }

    func retry() async {
        await shop.retry()
    }

    func openZalo() async {
        guard case .ready(let shop) = state else { return }
        await contact.openZalo(zaloContact: shop.zaloContact)
    }

    func openPhone() async {
        guard case .ready(let shop) = state else { return }
        await contact.openPhone(phoneContact: shop.phoneContact)
    }
}
