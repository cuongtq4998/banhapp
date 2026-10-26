import SwiftUI

/// S-4: one cake and the button that starts an order with it.
struct ProductDetailView: View {
    private static let imageAspectRatio: CGFloat = 4.0 / 3.0

    @State var model: ProductDetailScreenModel
    let onOrder: () -> Void

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.vertical, Spacing.lg)
        }
        .bottomActionBar {
            ActionButton(title: Strings.detailButtonOrder, action: onOrder)
                .disabled(!isReady)
                .accessibilityIdentifier(AccessibilityID.detailOrder)
        }
        .appBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .ready(let item): detail(item)
        case .loading:
            VStack(spacing: Spacing.lg) {
                SkeletonBlock(cornerRadius: Radius.image).aspectRatio(Self.imageAspectRatio, contentMode: .fit)
                SkeletonBlock(cornerRadius: Radius.card).frame(height: Size.thumb)
            }
            .loadingAnnouncement(identifier: AccessibilityID.detailSkeleton)
        case .failed(let failure):
            ErrorStateView(message: Strings.catalogLoadFailure(failure, screenMessage: Strings.productsError)) {
                Task { await model.retry() }
            }
        }
    }

    private func detail(_ item: ProductItem) -> some View {
        VStack(spacing: Spacing.lg) {
            ProductImage(url: item.imageURL, accessibilityName: item.name)
                .aspectRatio(Self.imageAspectRatio, contentMode: .fit)
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(verbatim: item.name)
                        .font(Typography.titleLarge)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(AccessibilityID.detailName)
                    Text(verbatim: item.description)
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityIdentifier(AccessibilityID.detailDescription)
                    Text(verbatim: Strings.priceEach(amount: item.priceText))
                        .font(Typography.bodyStrong)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityIdentifier(AccessibilityID.detailPrice)
                }
            }
        }
    }

    private var isReady: Bool {
        if case .ready = model.state { true } else { false }
    }

    private var title: Text {
        if case .ready(let item) = model.state { Text(verbatim: item.name) } else { Text(verbatim: "") }
    }
}
