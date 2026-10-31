import BanhContracts
import Foundation
import Observation

/// The data of one order in progress, shared by the four steps (MVVM-C: the coordinator owns it and
/// hands it to each step's view model). Every change is saved to the draft store, so going back, a
/// phone call or the system ending the app never loses data (FR-15, AC-18, ADR-0011).
@MainActor
@Observable
final class OrderFlow {
    private(set) var draft: OrderDraft
    /// Cakes that the shop hid since they were chosen; S-5 tells the customer once (BR-13, AC-34).
    private(set) var removedCakeNames: [String] = []
    /// The prices of the last `PRICE_CHANGED` answer, shown instead of the catalog's until the customer
    /// changes the order itself (ADR-0010).
    private(set) var priceOverride: PriceChangedDetails?
    /// Field errors of a `VALIDATION_FAILED` answer, waiting for S-7 to show them once.
    private(set) var serverFieldErrors: [APIErrorResponse.FieldError] = []

    let repository: CatalogRepository
    @ObservationIgnored private let store: any DraftStore
    @ObservationIgnored private let now: () -> Date

    init(draft: OrderDraft, repository: CatalogRepository, store: any DraftStore, now: @escaping () -> Date = { Date() }) {
        self.draft = draft
        self.repository = repository
        self.store = store
        self.now = now
    }

    // MARK: Catalog

    var catalog: Load<CatalogResponse> { repository.catalog }

    var settings: CatalogSettings? {
        if case .ready(let catalog) = catalog { catalog.settings } else { nil }
    }

    /// Prices of the review and of S-5; nil until the catalog is known.
    var pricing: OrderPricing? {
        if case .ready(let catalog) = catalog { pricing(in: catalog) } else { nil }
    }

    func pricing(in catalog: CatalogResponse) -> OrderPricing {
        let prices = OrderPricing(draft: draft, catalog: catalog)
        return priceOverride.map(prices.applying) ?? prices
    }

    /// Loads the catalog again (prices are refreshed on entry to S-5, ADR-0011) and drops from the
    /// draft any cake the shop no longer offers. An empty catalog keeps the draft untouched: it is an
    /// error state, not a decision of the shop to remove every cake (UI document 5.5).
    func refreshCatalog() async {
        await repository.refresh()
        reconcileWithCatalog()
    }

    func reconcileWithCatalog() {
        guard case .ready(let catalog) = catalog, !catalog.products.isEmpty else { return }
        let offered = Set(catalog.products.map(\.productID))
        let gone = draft.items.filter { !offered.contains($0.productID) }
        guard !gone.isEmpty else { return }
        let hadQuantity = gone.filter { $0.quantity > 0 }
        // Dropping a cake with a quantity changes the body, so `update` also replaces the key.
        update { $0.items.removeAll { !offered.contains($0.productID) } }
        removedCakeNames = hadQuantity.map(\.name)
    }

    func dismissRemovedNotice() {
        if !removedCakeNames.isEmpty { removedCakeNames = [] }
    }

    // MARK: Changes

    func setQuantity(_ quantity: Int, of product: CatalogProduct) {
        dismissRemovedNotice()
        update { $0.setQuantity(quantity, of: product.productID, name: product.name) }
    }

    func setDate(_ date: ShopDate?) { update { $0.date = date } }
    func setSlot(_ slotID: ResourceID?) { update { $0.slotID = slotID } }
    func setName(_ value: String) { update { $0.name = value } }
    func setPhone(_ value: String) { update { $0.phone = value } }
    func setAddress(_ value: String) { update { $0.address = value } }
    func setDistrict(_ districtID: ResourceID?) { update { $0.districtID = districtID } }
    func setNote(_ value: String) { update { $0.note = value } }

    // MARK: Sending (ADR-0008 v1.1, ADR-0010)

    /// Records the total the customer is about to confirm. Unchanged, the key stays (a retry); changed,
    /// `update` replaces it.
    func acknowledgeTotal(_ totalVND: Int) { update { $0.expectedTotalVND = totalVND } }

    /// `PRICE_CHANGED`: the server's prices replace the review's and its total becomes the expected
    /// total. The body changed, so `update` replaces the key.
    func applyPriceChange(_ details: PriceChangedDetails) {
        applyPriceChange(expectedTotalVND: details.totalVND)
        priceOverride = details
    }

    func applyPriceChange(expectedTotalVND: Int) { update { $0.expectedTotalVND = expectedTotalVND } }

    /// `IDEMPOTENCY_KEY_REUSED`: the server saw this key with another body. Replace the key and retry once.
    func replaceIdempotencyKey() { update { $0.idempotencyKey = UUID() } }

    /// `PRODUCT_UNAVAILABLE`: only the named cakes leave the draft; S-5 names them once (BR-13, AC-34).
    func dropProducts(_ ids: [ResourceID]) {
        let gone = draft.items.filter { ids.contains($0.productID) && $0.quantity > 0 }
        guard !gone.isEmpty else { return }
        update { $0.items.removeAll { ids.contains($0.productID) } }
        removedCakeNames = gone.map(\.name)
    }

    /// `VALIDATION_FAILED`: keeps the entries for S-7.
    func rejectFields(_ errors: [APIErrorResponse.FieldError]) { serverFieldErrors = errors }

    func takeServerFieldErrors() -> [APIErrorResponse.FieldError] {
        defer { serverFieldErrors = [] }
        return serverFieldErrors
    }

    /// Forgets the draft once the order is confirmed.
    func discardDraft() {
        store.clear()
        draft = OrderDraft(savedAt: now())
        priceOverride = nil
        serverFieldErrors = []
    }

    private func update(_ change: (inout OrderDraft) -> Void) {
        let before = draft
        change(&draft)
        // A changed body field means a new request; a pure retry keeps the key (ADR-0008 v1.1).
        if draft.requestBody != before.requestBody { draft.idempotencyKey = UUID() }
        if draft.choices != before.choices { priceOverride = nil }
        draft.savedAt = now()
        store.save(draft)
    }
}
