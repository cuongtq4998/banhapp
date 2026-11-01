import BanhDesign
import SwiftUI

/// The owner's Settings tab: S-A6 and the screens pushed from its five rows (S-A7 to S-A12).
struct SettingsTabView: View {
    @Bindable var coordinator: SettingsCoordinator
    let baseURL: URL

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            SettingsView(coordinator: coordinator)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: SettingsCoordinator.Route.self) { destination($0) }
        }
        .toast($coordinator.toast, identifier: AdminID.toast)
    }

    @ViewBuilder
    private func destination(_ route: SettingsCoordinator.Route) -> some View {
        switch route {
        case .cakes:
            Holder(make: coordinator.cakes) { model in
                CakesView(
                    model: model, onBack: coordinator.pop, onAdd: { coordinator.path.append(.cakeNew) },
                    onOpen: { coordinator.path.append(.cakeEdit($0.id)) }, baseURL: baseURL
                )
            }
        case .cakeNew:
            Holder(make: { coordinator.cakeForm(.add) }) { CakeFormView(model: $0, baseURL: baseURL, onBack: coordinator.pop) }
        case .cakeEdit(let id):
            Holder(make: { coordinator.cakeForm(.edit(id)) }) { CakeFormView(model: $0, baseURL: baseURL, onBack: coordinator.pop) }
        case .rules:
            Holder(make: coordinator.rules) { RulesView(model: $0, onBack: coordinator.pop) }
        case .delivery:
            Holder(make: coordinator.delivery) { DeliveryView(model: $0, onBack: coordinator.pop) }
        case .shop:
            Holder(make: coordinator.shop) { ShopView(model: $0, onBack: coordinator.pop) }
        case .staff:
            Holder(make: coordinator.staff) { StaffView(model: $0, onBack: coordinator.pop) }
        }
    }
}

/// Creates a screen's model once and keeps it while the screen is on the path.
private struct Holder<Model: AnyObject & Observable, Content: View>: View {
    @State private var model: Model
    let content: (Model) -> Content

    init(make: () -> Model, @ViewBuilder content: @escaping (Model) -> Content) {
        _model = State(initialValue: make())
        self.content = content
    }

    var body: some View { content(model) }
}
