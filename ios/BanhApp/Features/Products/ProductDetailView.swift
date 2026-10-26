import SwiftUI

/// S-4: one cake and the button that starts an order with it.
struct ProductDetailView: View {
    @State var model: ProductDetailScreenModel
    let onOrder: () -> Void

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, Spacing.backButtonTop)
                .padding(.bottom, Spacing.lg)
        }
        .bottomActionBar {
            ActionButton(title: Strings.detailButtonOrder, action: onOrder)
                .disabled(!isReady)
                .accessibilityIdentifier(AccessibilityID.detailOrder)
        }
        .appBackground()
        .customBackNavigation()
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .ready(let item): detail(item)
        case .loading:
            VStack(spacing: Spacing.lg) {
                pictureFrame { SkeletonBlock(cornerRadius: Radius.detailImage) }
                SkeletonBlock(cornerRadius: Radius.detailCard).frame(height: Size.thumb)
            }
            .loadingAnnouncement(identifier: AccessibilityID.detailSkeleton)
        case .failed(let failure):
            VStack(alignment: .leading, spacing: Spacing.lg) {
                BackButton()
                ErrorStateView(message: Strings.catalogLoadFailure(failure, screenMessage: Strings.productsError)) {
                    Task { await model.retry() }
                }
            }
        }
    }

    private func detail(_ item: ProductItem) -> some View {
        VStack(spacing: Spacing.lg) {
            pictureFrame {
                ProductImage(url: item.imageURL, accessibilityName: item.name, cornerRadius: Radius.detailImage)
            }
            GlassCard(cornerRadius: Radius.detailCard, padding: Spacing.detailCardInset) {
                VStack(alignment: .leading, spacing: Spacing.detailCardGap) {
                    Text(verbatim: item.name)
                        .textStyle(Typography.detailTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(AccessibilityID.detailName)
                    Text(verbatim: Strings.priceEach(amount: item.priceText))
                        .textStyle(Typography.detailPrice)
                        .foregroundStyle(Palette.primaryDeep)
                        .accessibilityIdentifier(AccessibilityID.detailPrice)
                    Text(verbatim: item.description)
                        .textStyle(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityIdentifier(AccessibilityID.detailDescription)
                }
            }
        }
    }

    /// The picture frame with the back button laid over its top-left corner, as on the board.
    private func pictureFrame<Picture: View>(@ViewBuilder _ picture: () -> Picture) -> some View {
        Color.clear
            .aspectRatio(Size.detailImageAspect, contentMode: .fit)
            .overlay { picture() }
            .overlay(alignment: .topLeading) {
                BackButton().padding(Spacing.backButtonOffset)
            }
    }

    private var isReady: Bool {
        if case .ready = model.state { true } else { false }
    }
}
