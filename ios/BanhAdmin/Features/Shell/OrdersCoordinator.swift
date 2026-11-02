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
    /// Order code of the in-app toast "new order" (A_NOTIF_FOREGROUND), 4 s.
    var foregroundCode: String?
    /// The owner's Settings tab; nil for staff.
    let settings: SettingsCoordinator?
    let baseURL: URL

    enum Tab { case orders, settings }

    private let api: any OrdersAPI
    private var details: [String: OrderDetailViewModel] = [:]

    init(user: SignedInUser, environment: AdminEnvironment, onSignOut: @escaping () -> Void) {
        self.user = user
        api = environment.orders
        opener = environment.opener
        list = OrderListViewModel(api: environment.orders)
        account = AccountViewModel(user: user, api: environment.account, onSignOut: onSignOut)
        baseURL = environment.baseURL
        settings = user.account.role == .owner ? SettingsCoordinator(account: account, api: environment.owner) : nil
    }

    var isOwner: Bool { user.account.role == .owner }

    func open(_ order: OrderSummary) { path.append(order.orderCode) }

    /// A notification tap (FR-26): S-A4 for the order, one level above the list, so back returns to S-A3.
    func openOrder(code: String) {
        selectedTab = .orders
        showsAccount = false
        foregroundCode = nil
        details.removeAll()
        path = [code]
    }

    /// A notification while the app is open: toast, and the list reloads so the badge counts it.
    func showForeground(code: String) {
        foregroundCode = code
        Task { await list.reload() }
    }

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
