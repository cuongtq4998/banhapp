import BanhContracts
import Foundation
@testable import BanhApp

/// Builds an order flow on the fixture catalog, with an in-memory draft store and a fixed clock.
@MainActor
enum OrderTestSupport {
    nonisolated static let now = Date(timeIntervalSince1970: 1_793_000_000)

    nonisolated static func id(_ suffix: Int) -> ResourceID {
        ResourceID(UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", suffix))!)
    }

    static func repository(_ catalog: CatalogResponse) async -> CatalogRepository {
        let repository = CatalogRepository(
            api: StubCatalogAPI([.success(.modified(catalog, etag: nil))]), cache: InMemoryCatalogCache()
        )
        await repository.refresh()
        return repository
    }

    static func flow(
        catalog: CatalogResponse? = nil, draft: OrderDraft? = nil, store: InMemoryDraftStore = InMemoryDraftStore()
    ) async throws -> OrderFlow {
        let catalog = try catalog ?? CatalogTestData.okCatalog()
        return OrderFlow(
            draft: draft ?? OrderDraft(savedAt: now), repository: await repository(catalog), store: store, now: { now }
        )
    }

    static func product(_ index: Int, in flow: OrderFlow) -> CatalogProduct {
        guard case .ready(let catalog) = flow.catalog else { fatalError("Catalog not loaded") }
        return catalog.products[index]
    }

    /// A catalog with the given cakes hidden (the shop's `active` flag, BR-13).
    static func catalog(without hidden: Set<Int>) throws -> CatalogResponse {
        let ok = try CatalogTestData.okCatalog()
        return CatalogResponse(
            serverDate: ok.serverDate, shop: ok.shop, settings: ok.settings,
            products: ok.products.enumerated().filter { !hidden.contains($0.offset) }.map(\.element),
            districts: ok.districts, slots: ok.slots
        )
    }
}

/// An availability API with a scripted answer that records the order sizes it was asked about.
final class StubAvailability: AvailabilityAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<AvailabilityResponse, APIError>
    private var asked: [Int] = []

    init(_ result: Result<AvailabilityResponse, APIError>) {
        self.result = result
    }

    var cakesAsked: [Int] { lock.withLock { asked } }
    func set(_ result: Result<AvailabilityResponse, APIError>) { lock.withLock { self.result = result } }

    func fetchAvailability(cakes: Int) async throws -> AvailabilityResponse {
        try lock.withLock {
            asked.append(cakes)
            return result
        }.get()
    }

    static func fixture() throws -> StubAvailability {
        StubAvailability(.success(try Fixtures.decode(AvailabilityResponse.self, from: "availability-ok.json")))
    }
}
