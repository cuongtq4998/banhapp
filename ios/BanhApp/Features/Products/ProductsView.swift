import SwiftUI

/// S-3: every active cake. Tapping a card opens its detail (S-4); the bar below starts an order.
struct ProductsView: View {
    /// Skeleton cards while nothing is cached (the shop normally has four cakes, ADR-0017).
    private static let skeletonCount = 4

    @State var model: ProductsScreenModel
    let onOrder: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                BackButton().padding(.top, Spacing.backButtonTop)
                Text(Strings.productsTitle)
                    .textStyle(Typography.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                content.padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.lg)
        }
        .bottomActionBar {
            ActionButton(title: Strings.homeButtonOrder, action: onOrder)
                .accessibilityIdentifier(AccessibilityID.productsOrder)
        }
        .appBackground()
        .customBackNavigation()
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .ready(let items):
            GlassGroup {
                LazyVStack(spacing: Spacing.cardGap) {
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
            VStack(spacing: Spacing.cardGap) {
                ForEach(0..<Self.skeletonCount, id: \.self) { ProductCardSkeleton(index: $0) }
            }
        case .failed(let failure):
            ErrorStateView(message: Strings.catalogLoadFailure(failure, screenMessage: Strings.productsError)) {
                Task { await model.retry() }
            }
        }
    }
}
