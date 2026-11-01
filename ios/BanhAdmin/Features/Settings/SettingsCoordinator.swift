import Foundation
import Observation

/// Coordinator of the owner's Settings tab (MVVM-C): the path of pushed screens, the one toast shared
/// by all of them, and the factory of their models. Screens never reach into the environment.
@Observable
final class SettingsCoordinator {
    enum Route: Hashable {
        case cakes, cakeNew, cakeEdit(String), rules, delivery, shop, staff
    }

    let account: AccountViewModel
    let overview: SettingsOverviewModel
    var path: [Route] = []
    var toast: String?
    private let api: any OwnerAPI

    init(account: AccountViewModel, api: any OwnerAPI) {
        self.account = account
        self.api = api
        overview = SettingsOverviewModel(api: api)
    }

    func flash(_ text: String) { toast = text }

    func pop() { if !path.isEmpty { path.removeLast() } }

    func cakes() -> CakesViewModel { CakesViewModel(api: api) }

    func cakeForm(_ mode: CakeFormViewModel.Mode) -> CakeFormViewModel {
        CakeFormViewModel(mode: mode, api: api, flash: { [weak self] in self?.flash($0) }, done: { [weak self] in self?.pop() })
    }

    func rules() -> RulesViewModel {
        RulesViewModel(api: api, flash: { [weak self] in self?.flash($0) }, done: { [weak self] in self?.pop() })
    }

    func delivery() -> DeliveryViewModel { DeliveryViewModel(api: api, flash: { [weak self] in self?.flash($0) }) }

    func shop() -> ShopViewModel {
        ShopViewModel(api: api, flash: { [weak self] in self?.flash($0) }, done: { [weak self] in self?.pop() })
    }

    func staff() -> StaffViewModel { StaffViewModel(api: api, flash: { [weak self] in self?.flash($0) }) }
}
