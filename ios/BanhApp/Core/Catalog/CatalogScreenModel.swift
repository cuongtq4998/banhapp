import BanhContracts
import Observation

/// A screen that shows one slice of the catalog. The slice is chosen by `select`; loading, cache and
/// failure states come from the repository, and `retry` reloads only that data (UI document 5.10).
@MainActor
@Observable
final class CatalogScreenModel<Value> {
    private let repository: CatalogRepository
    private let select: (CatalogResponse) -> Load<Value>

    init(repository: CatalogRepository, select: @escaping (CatalogResponse) -> Load<Value>) {
        self.repository = repository
        self.select = select
    }

    /// Derived on read from the observable repository, so a view refreshes when the catalog changes.
    var state: Load<Value> { repository.catalog.flatMap(select) }

    func retry() async {
        await repository.refresh()
    }
}
