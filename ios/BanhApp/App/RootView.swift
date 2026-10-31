import BanhContracts
import SwiftUI

/// S-1 first, then the navigation stack from S-2. Owns the navigation path and creates each screen's
/// model, so screens never reach into the environment themselves.
struct RootView: View {
    private enum Phase { case launching, running }

    let environment: AppEnvironment
    private let launchGate: LaunchGate

    @State private var phase: Phase = .launching
    @State private var path: [Route] = []
    @State private var home: HomeViewModel
    @State private var order: OrderCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(environment: AppEnvironment, launchGate: LaunchGate = LaunchGate()) {
        self.environment = environment
        self.launchGate = launchGate
        _order = State(initialValue: OrderCoordinator(environment: environment))
        _home = State(initialValue: HomeViewModel(
            repository: environment.catalogRepository,
            contact: ContactActions(opener: environment.urlOpener)
        ))
    }

    var body: some View {
        ZStack {
            switch phase {
            case .launching: LaunchView().transition(.opacity)
            case .running: navigation.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? Motion.short : Motion.long), value: phase)
        // The design has a light palette only; pinning it keeps system bars readable on the cream background.
        .preferredColorScheme(.light)
        // Starts the data work behind the logo; the gate below only watches its progress.
        .task { await environment.catalogRepository.refresh() }
        .task {
            await launchGate.awaitExit { !environment.catalogRepository.catalog.isLoading }
            if !Task.isCancelled { phase = .running }
        }
    }

    private var navigation: some View {
        NavigationStack(path: $path) {
            HomeView(
                model: home,
                onViewProducts: { path.append(.products) },
                onPlaceOrder: { startOrder() }
            )
            .navigationDestination(for: Route.self, destination: destination)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .products:
            ProductsView(model: .products(
                repository: environment.catalogRepository, assetBaseURL: environment.assetBaseURL
            ), onOrder: { startOrder() })
        case .productDetail(let id):
            ProductDetailView(
                model: .product(
                    id: id, repository: environment.catalogRepository, assetBaseURL: environment.assetBaseURL
                ),
                onOrder: { startOrder(with: id) }
            )
        case .orderStep(let step):
            order.screen(for: step, path: $path)
        case .orderConfirmed(let code):
            order.confirmation(code: code, path: $path)
        }
    }

    /// From S-2 and S-3 the saved draft returns; from a cake (S-4) a new draft begins with that cake.
    private func startOrder(with cake: ResourceID? = nil) {
        path.append(order.start(startingWith: cake))
    }
}
