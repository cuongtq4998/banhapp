import Foundation
import Observation

/// Coordinator of the signed-in part: owns the list, the navigation path to order details and the
/// account sheet. Features hand it intents; they never import each other.
@Observable
final class OrdersCoordinator {
    let user: SignedInUser
    let list: OrderListViewModel
    let account: AccountViewModel
    let opener: any URLOpener
    var path: [String] = []
    var showsAccount = false
    var selectedTab = Tab.orders

    enum Tab { case orders, settings }

    private let api: any OrdersAPI
    private var details: [String: OrderDetailViewModel] = [:]

    init(user: SignedInUser, environment: AdminEnvironment, onSignOut: @escaping () -> Void) {
        self.user = user
        api = environment.orders
        opener = environment.opener
        list = OrderListViewModel(api: environment.orders)
        account = AccountViewModel(user: user, api: environment.account, onSignOut: onSignOut)
    }

    var isOwner: Bool { user.account.role == .owner }

    func open(_ order: OrderSummary) { path.append(order.orderCode) }

    /// The detail model of a code, created once while the screen is on the path.
    func detail(for code: String) -> OrderDetailViewModel {
        if let existing = details[code] { return existing }
        let model = OrderDetailViewModel(code: code, api: api) { [weak self] in
            // The badge and the list change right after a status change (AC-17).
            Task { await self?.list.reload() }
        }
        details[code] = model
        return model
    }

    func backToList() {
        path.removeAll()
        details.removeAll()
        Task { await list.reload() }
    }

    func pathChanged() {
        if path.isEmpty { details.removeAll() }
    }
}
