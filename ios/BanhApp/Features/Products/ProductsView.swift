import SwiftUI

/// S-3: every active cake. Tapping a card opens its detail (S-4).
struct ProductsView: View {
    /// Skeleton cards while nothing is cached (the shop normally has four cakes, ADR-0017).
    private static let skeletonCount = 4

    @State var model: ProductsScreenModel

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.vertical, Spacing.lg)
        }
        .appBackground()
        .navigationTitle(Text(Strings.productsTitle))
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .ready(let items):
            GlassGroup {
                LazyVStack(spacing: Spacing.lg) {
                    ForEach(items) { item in
                        NavigationLink(value: Route.productDetail(item.id)) { ProductCard(item: item) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(AccessibilityID.productCard(item.id.identifierText))
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.productsList)
        case .loading:
            VStack(spacing: Spacing.lg) {
                ForEach(0..<Self.skeletonCount, id: \.self) { ProductCardSkeleton(index: $0) }
            }
        case .failed(let failure):
            ErrorStateView(message: Strings.catalogLoadFailure(failure, screenMessage: Strings.productsError)) {
                Task { await model.retry() }
            }
        }
    }
}
