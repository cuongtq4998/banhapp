import BanhCore
import Foundation
import Observation

/// S-A7 Cakes: all cakes not removed, active first then hidden, each by name (FR-21).
@Observable
final class CakesViewModel {
    private(set) var load: Load<OwnerSettings> = .loading
    private let api: any OwnerAPI

    init(api: any OwnerAPI) { self.api = api }

    func reload() async {
        do { load = .ready(try await api.settings()) } catch {
            if case .ready = load {} else { load = .failed(error.loadFailure) }
        }
    }

    func retry() async {
        load = .loading
        await reload()
    }

    var cakes: [Cake] {
        (load.value?.cakes ?? []).sorted {
            if $0.isActive != $1.isActive { return $0.isActive }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var maximum: Int { load.value?.cakeCountMax ?? 12 }
    var isFull: Bool { cakes.count >= maximum }
}
