import BanhDesign
import SwiftUI

/// The signed-in part. The owner gets two tabs (Orders with the red number, Settings); staff get the
/// order list alone, with the number beside the title and the account button (S-A3, S-A13).
struct ShellView: View {
    @Bindable var coordinator: OrdersCoordinator

    var body: some View {
        if coordinator.isOwner {
            TabView(selection: $coordinator.selectedTab) {
                orders
                    .tabItem {
                        Label(String(localized: AStrings.ordersTitle), systemImage: "list.clipboard")
                            .accessibilityIdentifier(AdminID.tabOrders)
                    }
                    .badge(badge)
                    .tag(OrdersCoordinator.Tab.orders)
                SettingsPlaceholderView(model: coordinator.account)
                    .tabItem {
                        Label(String(localized: AStrings.settingsTitle), systemImage: "gearshape")
                            .accessibilityIdentifier(AdminID.tabSettings)
                    }
                    .tag(OrdersCoordinator.Tab.settings)
            }
            .tint(Palette.primary)
        } else {
            orders
        }
    }

    /// Hidden at 0, "99+" above 99 (FR-13).
    private var badge: Text? {
        let count = coordinator.list.unfinishedCount
        return count == 0 ? nil : Text(verbatim: CountBadge.label(for: count))
    }

    private var orders: some View {
        NavigationStack(path: $coordinator.path) {
            OrderListView(
                model: coordinator.list, showsStaffHeader: !coordinator.isOwner,
                onOpen: { coordinator.open($0) }, onAccount: { coordinator.showsAccount = true }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { code in
                OrderDetailView(
                    model: coordinator.detail(for: code), serverDate: coordinator.list.serverDate,
                    opener: coordinator.opener, onBackToList: { coordinator.backToList() }
                )
            }
        }
        .onChange(of: coordinator.path) { _, _ in coordinator.pathChanged() }
        .sheet(isPresented: $coordinator.showsAccount) { AccountSheet(model: coordinator.account) }
    }
}
